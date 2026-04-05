#!/bin/bash
# bochi-health-check.sh — Cron-driven process monitor (Tier 1 + Tier 2)
# Runs every 2 minutes via cron: */2 * * * *
# Exit codes: 0=healthy, 1=recovered, 2=failed-to-recover, 3=backoff-limit-reached
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION="bochi"
BOCHI_DATA="/home/ubuntu/bochi-data"
WATCHDOG_LOG="/home/ubuntu/bochi-data/errors/watchdog.jsonl"
TMUX_START="$SCRIPT_DIR/bochi-tmux-start.sh"
PANE_CAPTURE="/tmp/bochi-pane-capture"
PANE_HASH_FILE="/tmp/bochi-pane-hash"
STALE_COUNT_FILE="/tmp/bochi-stale-count"
MAX_RESTARTS_PER_HOUR=5
STALE_THRESHOLD=4  # 4 checks × 2min = 8 minutes of unresponsiveness

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

# --- Backoff check ---
# Count restarts in the last hour from watchdog.jsonl

check_backoff() {
  if [ ! -f "$WATCHDOG_LOG" ]; then
    echo 0
    return
  fi

  local cutoff
  cutoff=$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
           python3 -c "from datetime import datetime,timedelta;print((datetime.utcnow()-timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")

  local count
  count=$(WATCHDOG_LOG_PATH="$WATCHDOG_LOG" CUTOFF="$cutoff" python3 -c "
import json, os
count = 0
cutoff = os.environ['CUTOFF']
for line in open(os.environ['WATCHDOG_LOG_PATH']):
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        if obj.get('event') == 'restart' and obj.get('ts', '') >= cutoff:
            count += 1
    except json.JSONDecodeError:
        continue
print(count)
" 2>/dev/null || echo 0)

  echo "$count"
}

# --- Phase 1: Process Check ---

phase1_process_check() {
  local failures=()

  # Check 1: tmux session
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    failures+=("tmux_session_missing")
  fi

  # Check 2: claude process
  if ! pgrep -f "^claude" > /dev/null 2>&1; then
    failures+=("claude_process_missing")
  fi

  # Check 3: bun (Discord plugin)
  if ! pgrep -f "bun.*server.ts" > /dev/null 2>&1; then
    failures+=("bun_process_missing")
  fi

  if [ ${#failures[@]} -eq 0 ]; then
    return 0  # All processes healthy
  fi

  local reason
  reason=$(IFS=","; echo "${failures[*]}")
  echo "PHASE1 FAIL: $reason"
  log_event "health_check_fail" "phase1:$reason" "false"

  # Check backoff before attempting restart
  local restart_count
  restart_count=$(check_backoff)
  if [ "$restart_count" -ge "$MAX_RESTARTS_PER_HOUR" ]; then
    echo "BACKOFF: $restart_count restarts in last hour (limit: $MAX_RESTARTS_PER_HOUR). Manual intervention needed."
    log_event "backoff_limit" "restarts_in_hour:$restart_count" "false"
    return 3
  fi

  # Attempt restart
  echo "Attempting restart (restart #$((restart_count + 1)) this hour)..."
  if "$TMUX_START" restart "health_check:$reason"; then
    echo "RECOVERED via restart"
    return 1
  else
    echo "FAILED to recover"
    log_event "recovery_failed" "phase1:$reason" "false"
    return 2
  fi
}

# --- Phase 2: Responsiveness Probe ---

phase2_responsiveness_probe() {
  # Capture current pane content
  tmux capture-pane -t "$SESSION" -p > "$PANE_CAPTURE" 2>/dev/null || return 0

  # Check for stuck permission prompts first
  if grep -qE "(Permission:|Do you want to|Allow once|Allow this action)" "$PANE_CAPTURE" 2>/dev/null; then
    echo "PHASE2: Permission prompt detected, sending auto-approve..."
    log_event "permission_prompt_detected" "auto_approve_attempt" "true"
    tmux send-keys -t "$SESSION" "1" 2>/dev/null
    sleep 0.5
    tmux send-keys -t "$SESSION" Enter 2>/dev/null
    # Don't restart yet — check again on next cycle
    return 0
  fi

  # Check if Claude is in healthy idle state (waiting for Discord messages)
  # This prevents false "unresponsive" detection when bochi is simply waiting for input
  if grep -q "Listening for channel messages" "$PANE_CAPTURE" 2>/dev/null; then
    if grep -q "❯" "$PANE_CAPTURE" 2>/dev/null; then
      echo "0" > "$STALE_COUNT_FILE"
      echo "PHASE2: Idle-healthy (listening for messages)"
      return 0
    fi
  fi

  # Calculate hash of pane content
  local current_hash
  current_hash=$(md5sum "$PANE_CAPTURE" 2>/dev/null | cut -d' ' -f1 || md5 -q "$PANE_CAPTURE" 2>/dev/null || echo "unknown")

  # Compare with previous hash
  local previous_hash=""
  if [ -f "$PANE_HASH_FILE" ]; then
    previous_hash=$(cat "$PANE_HASH_FILE")
  fi

  if [ "$current_hash" = "$previous_hash" ]; then
    # Screen unchanged — increment stale counter
    local stale_count=0
    if [ -f "$STALE_COUNT_FILE" ]; then
      stale_count=$(cat "$STALE_COUNT_FILE")
    fi
    stale_count=$((stale_count + 1))
    echo "$stale_count" > "$STALE_COUNT_FILE"

    echo "PHASE2: Pane unchanged ($stale_count/$STALE_THRESHOLD)"

    if [ "$stale_count" -ge "$STALE_THRESHOLD" ]; then
      echo "PHASE2: Unresponsive for $((stale_count * 2)) minutes. Force restart."
      log_event "health_check_fail" "phase2:unresponsive_${stale_count}_checks" "false"

      # Check backoff
      local restart_count
      restart_count=$(check_backoff)
      if [ "$restart_count" -ge "$MAX_RESTARTS_PER_HOUR" ]; then
        echo "BACKOFF: $restart_count restarts in last hour. Manual intervention needed."
        log_event "backoff_limit" "restarts_in_hour:$restart_count" "false"
        # Reset counter to avoid spamming on every check
        echo "0" > "$STALE_COUNT_FILE"
        return 3
      fi

      # Reset stale counter and restart
      echo "0" > "$STALE_COUNT_FILE"
      if "$TMUX_START" restart "unresponsive"; then
        echo "RECOVERED from unresponsive state"
        return 1
      else
        echo "FAILED to recover from unresponsive state"
        log_event "recovery_failed" "phase2:unresponsive" "false"
        return 2
      fi
    fi
  else
    # Screen changed — reset stale counter
    echo "0" > "$STALE_COUNT_FILE"
    echo "$current_hash" > "$PANE_HASH_FILE"
  fi

  return 0
}

# --- Main ---

echo "$(date -Iseconds) Health check starting..."

# Phase 1: Process check
phase1_result=0
phase1_process_check || phase1_result=$?

if [ "$phase1_result" -ne 0 ]; then
  # Phase 1 handled the situation (recovered, failed, or backoff)
  exit "$phase1_result"
fi

# Phase 2: Responsiveness probe (only if Phase 1 passes)
phase2_result=0
phase2_responsiveness_probe || phase2_result=$?

if [ "$phase2_result" -ne 0 ]; then
  exit "$phase2_result"
fi

echo "$(date -Iseconds) All checks passed"
exit 0
