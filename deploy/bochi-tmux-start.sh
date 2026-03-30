#!/bin/bash
# bochi-tmux-start.sh — Unified start/restart/stop/status entry point
# Called by @reboot cron AND health-check auto-recovery.
# Usage: bochi-tmux-start.sh [start|restart|stop|status]
set -euo pipefail

SESSION="bochi"
SKILL_DIR="/home/ubuntu/bochi-skill"
BOCHI_DATA="/home/ubuntu/bochi-data"
BOCHI_DATA_LINK="$HOME/.claude/bochi-data"
LOCKFILE="/tmp/bochi-restart.lock"
WATCHDOG_LOG="/home/ubuntu/bochi-data/errors/watchdog.jsonl"
LAUNCHER="/tmp/bochi-launcher.sh"
CLAUDE_BIN="/usr/bin/claude"

# Ensure log directory exists
mkdir -p "$(dirname "$WATCHDOG_LOG")"

# --- Logging ---

log_event() {
  local event="$1"
  local reason="${2:-}"
  local success="${3:-true}"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"ts\":\"$ts\",\"event\":\"$event\",\"reason\":\"$reason\",\"success\":$success}" >> "$WATCHDOG_LOG"
}

# --- Data directory setup ---

ensure_data_dir() {
  # Ensure /home/ubuntu/bochi-data/ exists with required subdirs
  mkdir -p "$BOCHI_DATA"/{topics,memos,newspaper,reflections,errors,sources,stats,cache/trending,archive,context-seeds}

  # Ensure symlink ~/.claude/bochi-data → /home/ubuntu/bochi-data/
  if [ -d "$BOCHI_DATA_LINK" ] && [ ! -L "$BOCHI_DATA_LINK" ]; then
    # Real directory exists — migrate it
    if [ -d "$BOCHI_DATA" ]; then
      rsync -a --backup --suffix=".bak" "$BOCHI_DATA_LINK/" "$BOCHI_DATA/"
      rm -rf "$BOCHI_DATA_LINK"
    else
      mv "$BOCHI_DATA_LINK" "$BOCHI_DATA"
    fi
    ln -sfn "$BOCHI_DATA" "$BOCHI_DATA_LINK"
  elif [ ! -e "$BOCHI_DATA_LINK" ]; then
    mkdir -p "$(dirname "$BOCHI_DATA_LINK")"
    ln -sfn "$BOCHI_DATA" "$BOCHI_DATA_LINK"
  elif [ -L "$BOCHI_DATA_LINK" ]; then
    LINK_TARGET=$(readlink "$BOCHI_DATA_LINK")
    if [ "$LINK_TARGET" != "$BOCHI_DATA" ]; then
      ln -sfn "$BOCHI_DATA" "$BOCHI_DATA_LINK"
    fi
  fi
}

# --- Skill setup ---

setup_skill() {
  # Copy SKILL-server.md → SKILL.md
  cp -f "$SKILL_DIR/SKILL-server.md" "$SKILL_DIR/SKILL.md" 2>/dev/null || true

  # Sync hook scripts to ~/.claude/scripts/hooks/
  mkdir -p "$HOME/.claude/scripts/hooks"
  cp -f "$SKILL_DIR/deploy/protect-readonly.sh" "$HOME/.claude/scripts/hooks/protect-readonly.sh"
  cp -f "$SKILL_DIR/deploy/tmux-auto-approve.sh" "$HOME/.claude/scripts/hooks/tmux-auto-approve.sh"
  chmod +x "$HOME/.claude/scripts/hooks/protect-readonly.sh"
  chmod +x "$HOME/.claude/scripts/hooks/tmux-auto-approve.sh"

  # Protect readonly files
  chmod 444 "$SKILL_DIR/SKILL.md" "$SKILL_DIR/deploy/lightsail-claude.md" 2>/dev/null || true
  chmod 444 "$HOME/.claude/channels/discord/access.json" 2>/dev/null || true
  chmod 444 "$HOME/.claude/hooks/hooks.json" 2>/dev/null || true
}

# --- Process checks ---

is_session_alive() {
  tmux has-session -t "$SESSION" 2>/dev/null
}

is_claude_running() {
  pgrep -f "^claude" > /dev/null 2>&1
}

is_bun_running() {
  pgrep -f "bun.*server.ts" > /dev/null 2>&1
}

is_watchdog_running() {
  pgrep -f "tmux-auto-approve" > /dev/null 2>&1
}

# --- Core operations ---

do_start() {
  local reason="${1:-manual}"

  # Check if already running and healthy
  if is_session_alive && is_claude_running; then
    echo "bochi session already running and healthy."
    log_event "start" "already_running" "true"
    return 0
  fi

  echo "Starting bochi..."

  ensure_data_dir
  setup_skill

  # Start auto-approve watchdog in background
  if ! is_watchdog_running; then
    nohup bash "$HOME/.claude/scripts/hooks/tmux-auto-approve.sh" > /dev/null 2>&1 &
    echo "  Watchdog started (PID: $!)"
  fi

  # Create launcher script
  cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
cd /home/ubuntu/bochi-skill
exec /usr/bin/claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official
LAUNCHER_EOF
  chmod +x "$LAUNCHER"

  # Start tmux session
  tmux new-session -d -s "$SESSION" "bash $LAUNCHER"

  # Wait for startup
  sleep 6

  # Smoke checks
  local errors=0
  if ! is_session_alive; then
    echo "  FAIL: tmux session not alive"
    errors=$((errors + 1))
  else
    echo "  PASS: tmux session alive"
  fi

  if ! is_claude_running; then
    echo "  FAIL: claude process not running"
    errors=$((errors + 1))
  else
    echo "  PASS: claude process running"
  fi

  if ! is_bun_running; then
    echo "  WARN: bun not yet running (may need more startup time)"
  else
    echo "  PASS: bun (Discord plugin) running"
  fi

  if [ "$errors" -gt 0 ]; then
    echo "START FAILED — $errors critical check(s) failed"
    log_event "start" "$reason" "false"
    return 1
  fi

  # Reset Phase 2 responsiveness probe state to prevent false positives after restart
  rm -f /tmp/bochi-pane-hash
  echo "0" > /tmp/bochi-stale-count

  echo "START SUCCESS"
  log_event "start" "$reason" "true"
  return 0
}

do_stop() {
  echo "Stopping bochi..."

  # Kill tmux session
  tmux kill-session -t "$SESSION" 2>/dev/null || true

  # Kill auto-approve watchdog
  pkill -f "tmux-auto-approve" 2>/dev/null || true

  sleep 1
  echo "STOP COMPLETE"
  log_event "stop" "manual" "true"
}

do_restart() {
  local reason="${1:-manual}"
  echo "Restarting bochi (reason: $reason)..."

  # Wait for any in-progress S3 sync to finish (max 30s)
  local wait_count=0
  while pgrep -f "aws s3" > /dev/null 2>&1; do
    if [ "$wait_count" -ge 15 ]; then
      echo "  WARN: S3 sync still running after 30s, proceeding anyway"
      break
    fi
    echo "  Waiting for S3 sync to finish..."
    sleep 2
    wait_count=$((wait_count + 1))
  done

  # Kill existing session and watchdog
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  pkill -f "tmux-auto-approve" 2>/dev/null || true
  sleep 2

  # Start fresh
  do_start "$reason"
  local rc=$?
  log_event "restart" "$reason" "$([ $rc -eq 0 ] && echo true || echo false)"
  return $rc
}

do_status() {
  local tmux_ok=false
  local claude_ok=false
  local bun_ok=false
  local watchdog_ok=false
  local uptime_str="unknown"

  is_session_alive && tmux_ok=true
  is_claude_running && claude_ok=true
  is_bun_running && bun_ok=true
  is_watchdog_running && watchdog_ok=true

  # Get tmux session uptime if available
  if [ "$tmux_ok" = true ]; then
    local created
    created=$(tmux display-message -t "$SESSION" -p '#{session_created}' 2>/dev/null || echo "")
    if [ -n "$created" ]; then
      local now
      now=$(date +%s)
      local diff=$((now - created))
      local hours=$((diff / 3600))
      local mins=$(( (diff % 3600) / 60 ))
      uptime_str="${hours}h${mins}m"
    fi
  fi

  # Output JSON status
  echo "{\"tmux\":$tmux_ok,\"claude\":$claude_ok,\"bun\":$bun_ok,\"watchdog\":$watchdog_ok,\"uptime\":\"$uptime_str\"}"

  # Exit code based on health
  if [ "$tmux_ok" = true ] && [ "$claude_ok" = true ] && [ "$bun_ok" = true ] && [ "$watchdog_ok" = true ]; then
    return 0
  else
    return 1
  fi
}

# --- Main ---

ACTION="${1:-start}"

case "$ACTION" in
  start)
    (
      flock -w 120 200 || { echo "ERROR: Could not acquire lock within 120s"; exit 1; }
      do_start "manual"
    ) 200>"$LOCKFILE"
    ;;
  restart)
    REASON="${2:-manual}"
    (
      flock -w 120 200 || { echo "ERROR: Could not acquire lock within 120s"; exit 1; }
      do_restart "$REASON"
    ) 200>"$LOCKFILE"
    ;;
  stop)
    (
      flock -w 120 200 || { echo "ERROR: Could not acquire lock within 120s"; exit 1; }
      do_stop
    ) 200>"$LOCKFILE"
    ;;
  status)
    do_status
    ;;
  *)
    echo "Usage: $0 [start|restart|stop|status]"
    exit 1
    ;;
esac
