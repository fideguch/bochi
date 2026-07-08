#!/bin/bash
# bridge-start.sh — Mac Claude bridge start/restart/stop/status.
# Ported from deploy/bochi-tmux-start.sh (Lightsail) with macOS adaptations:
#   - dedicated tmux socket (-L claude-bridge), never the user's default server
#   - mkdir-based atomic lock (macOS has no flock(1))
#   - startup string for claude >= 2.1.195: "Listening for messages from"
#   - launcher runs --permission-mode bypassPermissions (v2.7): permission
#     prompts never stall the conversation. Hard-deny still holds via settings
#     permissions.deny + the bridge-guard PreToolUse hook (both verified
#     enforced under bypass — docs + live spike 2026-07-08).
#   - bootstrap prompt injection to recover missed messages after (re)start
set -euo pipefail

SOCKET="claude-bridge"
SESSION="bridge"
REPO="/Users/fumito_ideguchi/bochi"
RUNTIME="/Users/fumito_ideguchi/bochi-runtime"
DATA_REAL="/Users/fumito_ideguchi/bochi-data"
DATA_LINK="/Users/fumito_ideguchi/.claude/bochi-data"
SKILL_DST="/Users/fumito_ideguchi/.claude/skills/bochi"
WATCHDOG_LOG="$DATA_REAL/errors/bridge-watchdog.jsonl"
LOCKDIR="/tmp/claude-bridge-start.lock.d"
LAUNCHER="$RUNTIME/bin/launcher.sh"
TMUX="/opt/homebrew/bin/tmux"
CLAUDE_BIN="/Users/fumito_ideguchi/.local/bin/claude"
SMOKE_STRING="Listening for messages from"

export PATH="/Users/fumito_ideguchi/.local/bin:/Users/fumito_ideguchi/.bun/bin:/Users/fumito_ideguchi/.nodebrew/current/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

log_event() {
  local event="$1" reason="${2:-}" success="${3:-true}"
  mkdir -p "$(dirname "$WATCHDOG_LOG")"
  printf '{"ts":"%s","event":"%s","reason":"%s","success":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$reason" "$success" >> "$WATCHDOG_LOG"
}

# --- mkdir atomic lock (flock does not exist on macOS) ---

acquire_lock() {
  # Stale lock: holder PID dead or lock older than 120s
  if [ -d "$LOCKDIR" ]; then
    local holder age now mtime
    holder=$(cat "$LOCKDIR/pid" 2>/dev/null || echo "")
    now=$(date +%s)
    mtime=$(stat -f %m "$LOCKDIR" 2>/dev/null || echo "$now")
    age=$((now - mtime))
    if { [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; } || [ "$age" -gt 120 ]; then
      rm -rf "$LOCKDIR"
      log_event "stale_lock_cleaned" "holder=${holder:-unknown} age=${age}s" "true"
    fi
  fi
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "ERROR: another bridge-start.sh is running (lock: $LOCKDIR)"
    return 1
  fi
  echo $$ > "$LOCKDIR/pid"
  trap 'rm -rf "$LOCKDIR"' EXIT
}

# --- Idempotent runtime installation ---

ensure_data_dir() {
  # Real data lives OUTSIDE ~/.claude by design: keeps bochi-data clear of
  # Claude-config territory and consistent across bridge/newspaper/user
  # sessions. (The sensitive-file block that made ~/.claude writes fail applied
  # to the pre-v2.7 non-bypass bridge; v2.7 runs --permission-mode
  # bypassPermissions, so the layout is a deliberate convention, not a workaround.)
  if [ -d "$DATA_LINK" ] && [ ! -L "$DATA_LINK" ]; then
    if [ -e "$DATA_REAL" ]; then
      # Both exist: merge link-dir content into real dir, then swap
      rsync -a --backup --suffix=".pre-bridge.bak" "$DATA_LINK/" "$DATA_REAL/"
      rm -rf "$DATA_LINK"
    else
      mv "$DATA_LINK" "$DATA_REAL"
    fi
    ln -sfn "$DATA_REAL" "$DATA_LINK"
    log_event "data_migrated" "moved to $DATA_REAL, symlink installed" "true"
  elif [ ! -e "$DATA_LINK" ]; then
    mkdir -p "$DATA_REAL"
    ln -sfn "$DATA_REAL" "$DATA_LINK"
  elif [ -L "$DATA_LINK" ] && [ "$(readlink "$DATA_LINK")" != "$DATA_REAL" ]; then
    ln -sfn "$DATA_REAL" "$DATA_LINK"
  fi
  mkdir -p "$DATA_REAL"/{topics,memos,newspaper,reflections,errors,sources,stats,cache,archive,context-seeds,conversations,vocab}
}

install_file() {
  # Install src to dst atomically (mv), then set mode. Works even when the
  # destination is the currently-running script or chmod 444/555.
  local src="$1" dst="$2" mode="$3" tmp
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    chmod "$mode" "$dst" 2>/dev/null || true
    return 0
  fi
  tmp="$(dirname "$dst")/.$(basename "$dst").new.$$"
  cp "$src" "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$dst"
}

ensure_runtime() {
  mkdir -p "$RUNTIME"/{workspace,logs,bin} "$RUNTIME/.claude"

  install_file "$REPO/deploy/mac-claude.md" "$RUNTIME/CLAUDE.md" 444
  install_file "$REPO/deploy/mac/templates/bridge-settings.json" "$RUNTIME/.claude/settings.json" 444
  install_file "$REPO/deploy/mac/bridge-guard.sh" "$RUNTIME/bin/bridge-guard.sh" 555
  install_file "$REPO/deploy/mac/bridge-guard.py" "$RUNTIME/bin/bridge-guard.py" 555
  install_file "$REPO/deploy/mac/bridge-start.sh" "$RUNTIME/bin/bridge-start.sh" 555
  install_file "$REPO/deploy/mac/bridge-health.sh" "$RUNTIME/bin/bridge-health.sh" 555
  install_file "$REPO/deploy/mac/notify-owner.sh" "$RUNTIME/bin/notify-owner.sh" 555
  install_file "$REPO/deploy/mac/generate-newspaper.sh" "$RUNTIME/bin/generate-newspaper.sh" 555
  install_file "$REPO/deploy/mac/deliver-newspaper.sh" "$RUNTIME/bin/deliver-newspaper.sh" 555
  install_file "$REPO/deploy/mac/bin/pc-status" "$RUNTIME/bin/pc-status" 555
  install_file "$REPO/deploy/mac/bin/repo-status" "$RUNTIME/bin/repo-status" 555

  # Launcher: regenerated every start (0555 like the rest)
  local tmp="$RUNTIME/bin/.launcher.sh.new.$$"
  cat > "$tmp" <<LAUNCHER_EOF
#!/bin/bash
export PATH="$PATH"
export CLAUDE_BRIDGE=1
cd "$RUNTIME"
exec "$CLAUDE_BIN" --model sonnet --permission-mode bypassPermissions --channels plugin:discord@claude-plugins-official
LAUNCHER_EOF
  chmod 555 "$tmp"
  mv -f "$tmp" "$LAUNCHER"
}

sync_skill() {
  # ~/.claude/skills/bochi is a plain copy of this repo — keep it in sync so
  # the bridge reads current mode specs (review finding: divergence risk).
  [ -d "$SKILL_DST" ] || return 0
  rsync -a --exclude '.git' --exclude '.evals' --exclude '.gatekeeper' \
    --exclude '.github' --exclude 'worker' "$REPO/" "$SKILL_DST/"
}

resolve_dm_channel() {
  # Owner DM channel id via Discord REST; empty string on any failure.
  local env_file="$HOME/.claude/channels/discord/.env"
  local access_file="$HOME/.claude/channels/discord/access.json"
  [ -f "$env_file" ] && [ -f "$access_file" ] || return 1
  local token user_id
  token=$(grep -m1 '^DISCORD_BOT_TOKEN=' "$env_file" | cut -d= -f2- | tr -d '"' | tr -d "'")
  user_id=$(/usr/bin/python3 -c "
import json
try:
    a = json.load(open('$access_file'))
    print((a.get('allowFrom') or [''])[0])
except Exception:
    print('')
")
  [ -n "$token" ] && [ -n "$user_id" ] || return 1
  curl -s --max-time 10 -X POST "https://discord.com/api/v10/users/@me/channels" \
    -H "Authorization: Bot $token" -H "Content-Type: application/json" \
    -d "{\"recipient_id\": \"$user_id\"}" | /usr/bin/python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('id', ''))
except Exception:
    print('')
"
}

# --- Process checks ---

is_session_alive() {
  "$TMUX" -L "$SOCKET" has-session -t "$SESSION" 2>/dev/null
}

bridge_claude_count() {
  # Self-match safe: pgrep -f never matches its own process listing
  pgrep -f -- "--channels plugin:discord" 2>/dev/null | wc -l | tr -d ' '
}

pane_text() {
  "$TMUX" -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null || true
}

# --- Operations ---

do_start() {
  local reason="${1:-manual}"

  if is_session_alive && [ "$(bridge_claude_count)" -ge 1 ]; then
    echo "bridge already running."
    log_event "start" "already_running" "true"
    return 0
  fi

  echo "Starting Claude bridge..."
  ensure_data_dir
  ensure_runtime
  sync_skill

  "$TMUX" -L "$SOCKET" new-session -d -s "$SESSION" "bash $LAUNCHER"

  # Smoke: wait up to 45s for the listening line or the idle TUI prompt
  # (claude >=2.1.201 does not always render the "Listening ..." line)
  local waited=0 ok=false
  while [ "$waited" -lt 45 ]; do
    if pane_text | grep -qE "$SMOKE_STRING|❯"; then ok=true; break; fi
    sleep 3; waited=$((waited + 3))
  done

  if ! is_session_alive; then
    echo "START FAILED: tmux session died"
    log_event "start" "$reason:session_died" "false"
    return 1
  fi

  if [ "$ok" = true ]; then
    echo "  PASS: listening line or idle TUI prompt visible"
  else
    # Fail-safe (review finding): CLI updates may change the string again.
    # Process alive but string missing -> WARN, do not fail/restart-loop.
    if [ "$(bridge_claude_count)" -ge 1 ]; then
      echo "  WARN: startup string not found but claude process alive (CLI wording may have changed)"
      log_event "smoke_string_missing" "$reason" "true"
    else
      echo "START FAILED: claude process not running"
      log_event "start" "$reason:claude_missing" "false"
      return 1
    fi
  fi

  # Bootstrap: recover messages missed while the bridge was down.
  # A fresh session does not know the DM chat_id yet, so resolve it here via
  # REST (same pattern as notify-owner.sh) and inject it with the prompt.
  # NOTE: text and Enter must be separate send-keys calls with a pause —
  # a single call is treated as a bracketed paste and never submits.
  sleep 3
  local chat_id=""
  chat_id=$(resolve_dm_channel || echo "")
  local hint=""
  # Brace the expansion: bash 3.2 misparses $var adjacent to multibyte chars.
  [ -n "$chat_id" ] && hint="(chat_id: ${chat_id})"
  "$TMUX" -L "$SOCKET" send-keys -t "$SESSION" \
    "セッション回復: CLAUDE.md の Session Start プロトコルに従って fetch_messages で直近履歴を確認し${hint}、未応答のユーザーメッセージがあれば対応して。無ければ何も送信しないで待機。"
  sleep 1
  "$TMUX" -L "$SOCKET" send-keys -t "$SESSION" Enter
  echo "  Bootstrap prompt injected (chat_id=${chat_id:-unknown})"

  echo "START SUCCESS"
  log_event "start" "$reason" "true"
  return 0
}

do_stop() {
  echo "Stopping Claude bridge..."
  "$TMUX" -L "$SOCKET" kill-session -t "$SESSION" 2>/dev/null || true
  "$TMUX" -L "$SOCKET" kill-server 2>/dev/null || true
  sleep 1
  echo "STOP COMPLETE"
  log_event "stop" "${1:-manual}" "true"
}

do_restart() {
  local reason="${1:-manual}"
  echo "Restarting Claude bridge (reason: $reason)..."
  # Let any in-flight S3 sync finish (max 20s)
  local n=0
  while pgrep -f "aws s3" > /dev/null 2>&1 && [ "$n" -lt 10 ]; do sleep 2; n=$((n+1)); done
  do_stop "$reason"
  sleep 2
  local rc=0
  do_start "$reason" || rc=$?
  # Counted by bridge-health.sh restarts_last_hour() for the 5/h backoff.
  log_event "restart" "$reason" "$([ "$rc" -eq 0 ] && echo true || echo false)"
  return "$rc"
}

do_status() {
  local tmux_ok=false claude_n=0 listening=false uptime_str="unknown"
  is_session_alive && tmux_ok=true
  claude_n=$(bridge_claude_count)
  pane_text | grep -qE "$SMOKE_STRING|❯" && listening=true
  if [ "$tmux_ok" = true ]; then
    local created now
    created=$("$TMUX" -L "$SOCKET" display-message -t "$SESSION" -p '#{session_created}' 2>/dev/null || echo "")
    if [ -n "$created" ]; then
      now=$(date +%s)
      uptime_str="$(( (now - created) / 3600 ))h$(( ((now - created) % 3600) / 60 ))m"
    fi
  fi
  echo "{\"tmux\":$tmux_ok,\"claude_channels_procs\":$claude_n,\"listening\":$listening,\"uptime\":\"$uptime_str\"}"
  [ "$tmux_ok" = true ] && [ "$claude_n" -ge 1 ] && return 0 || return 1
}

ACTION="${1:-start}"
case "$ACTION" in
  start)   acquire_lock; do_start "${2:-manual}" ;;
  restart) acquire_lock; do_restart "${2:-manual}" ;;
  stop)    acquire_lock; do_stop "${2:-manual}" ;;
  status)  do_status ;;
  *) echo "Usage: $0 [start|restart|stop|status] [reason]"; exit 1 ;;
esac
