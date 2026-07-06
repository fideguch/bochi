#!/bin/bash
# bridge-health.sh — launchd StartInterval(120s) monitor for the Mac bridge.
# Ported from deploy/bochi-health-check.sh (Lightsail) with policy changes:
#   - permission prompts are HEALTHY waiting (never auto-approved);
#     if pending >10 min, notify the owner via Discord REST instead
#   - rate-limit / tool-parse-failure pane signatures -> notify, not restart
#   - daily freshness restart only in the 04:30-04:59 JST window when idle
# Exit codes: 0=healthy, 1=recovered, 2=failed-to-recover, 3=backoff-limit
set -uo pipefail

SOCKET="claude-bridge"
SESSION="bridge"
RUNTIME="/Users/fumito_ideguchi/bochi-runtime"
DATA_REAL="/Users/fumito_ideguchi/bochi-data"
WATCHDOG_LOG="$DATA_REAL/errors/bridge-watchdog.jsonl"
BRIDGE_START="$RUNTIME/bin/bridge-start.sh"
NOTIFY="$RUNTIME/bin/notify-owner.sh"
TMUX="/opt/homebrew/bin/tmux"
SMOKE_STRING="Listening for messages from"
PANE_HASH_FILE="/tmp/claude-bridge-pane-hash"
STALE_COUNT_FILE="/tmp/claude-bridge-stale-count"
PERM_SINCE_FILE="/tmp/claude-bridge-perm-since"
DAILY_MARKER="/tmp/claude-bridge-daily-restart"
MAX_RESTARTS_PER_HOUR=5
STALE_THRESHOLD=4   # 4 x 2min = 8 minutes of frozen pane

export PATH="/Users/fumito_ideguchi/.local/bin:/Users/fumito_ideguchi/.bun/bin:/Users/fumito_ideguchi/.nodebrew/current/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

log_event() {
  local event="$1" reason="${2:-}" success="${3:-true}"
  mkdir -p "$(dirname "$WATCHDOG_LOG")"
  printf '{"ts":"%s","event":"%s","reason":"%s","success":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$reason" "$success" >> "$WATCHDOG_LOG"
}

restarts_last_hour() {
  [ -f "$WATCHDOG_LOG" ] || { echo 0; return; }
  local cutoff
  cutoff=$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  [ -n "$cutoff" ] || { echo 0; return; }
  awk -v cutoff="$cutoff" -F'"' '
    /"event":"restart"/ { for (i=1;i<NF;i++) if ($i=="ts") { if ($(i+2) >= cutoff) n++ } }
    END { print n+0 }' "$WATCHDOG_LOG" 2>/dev/null || echo 0
}

try_restart() {
  local reason="$1" count
  count=$(restarts_last_hour)
  if [ "$count" -ge "$MAX_RESTARTS_PER_HOUR" ]; then
    echo "BACKOFF: $count restarts in last hour"
    log_event "backoff_limit" "restarts_in_hour:$count" "false"
    "$NOTIFY" bridge-backoff "ブリッジの自動復旧が1時間の上限($count回)に達しました。手動確認が必要です: bash ~/bochi-runtime/bin/bridge-start.sh status" || true
    return 3
  fi
  if "$BRIDGE_START" restart "health:$reason"; then
    echo "RECOVERED via restart"
    return 1
  fi
  log_event "recovery_failed" "$reason" "false"
  "$NOTIFY" bridge-down "ブリッジの自動復旧に失敗しました($reason)。Macで確認してください。" || true
  return 2
}

pane_text() {
  "$TMUX" -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null || true
}

# --- Phase 1: process liveness ---

if ! "$TMUX" -L "$SOCKET" has-session -t "$SESSION" 2>/dev/null; then
  echo "PHASE1 FAIL: tmux session missing"
  log_event "health_check_fail" "phase1:tmux_session_missing" "false"
  try_restart "tmux_session_missing"; exit $?
fi

CLAUDE_N=$(pgrep -f -- "--channels plugin:discord" 2>/dev/null | wc -l | tr -d ' ')
if [ "$CLAUDE_N" -lt 1 ]; then
  echo "PHASE1 FAIL: bridge claude process missing"
  log_event "health_check_fail" "phase1:claude_process_missing" "false"
  try_restart "claude_process_missing"; exit $?
fi

PANE=$(pane_text)

# --- Phase 2a: permission prompt = healthy waiting + escalation ---

# Match only the prompt UI itself, not conversation text that merely contains
# the word "permission" (false positive verified 2026-07-06).
if echo "$PANE" | grep -qE "(Do you want to proceed|requires approval|Allow once|Allow always|Esc to cancel)"; then
  NOW=$(date +%s)
  if [ -f "$PERM_SINCE_FILE" ]; then
    SINCE=$(cat "$PERM_SINCE_FILE" 2>/dev/null || echo "$NOW")
  else
    SINCE="$NOW"; echo "$NOW" > "$PERM_SINCE_FILE"
  fi
  WAITED=$((NOW - SINCE))
  echo "PHASE2: permission prompt pending (${WAITED}s) — healthy waiting, never auto-approved"
  echo "0" > "$STALE_COUNT_FILE"
  if [ "$WAITED" -gt 600 ]; then
    "$NOTIFY" bridge-perm "権限承認待ちで10分以上止まっています。Discordの承認ボタン(🔐)に返答するか、後続のメッセージも止まるので不要なら Deny してください。" || true
  fi
  exit 0
else
  rm -f "$PERM_SINCE_FILE"
fi

# --- Phase 2b: rate-limit / parse-failure signatures -> notify only ---

# NOTE: patterns must NOT match the Fable-5 promo banner ("weekly usage limit",
# "hit your limit") that appears at every session start — verified 2026-07-06.
if echo "$PANE" | grep -qiE "(reached your.{0,30}limit|limit reached|resets at [0-9]|out of extra usage|rate.?limited)"; then
  echo "PHASE2: rate/usage limit visible — notify, no restart"
  "$NOTIFY" bridge-limit "Claudeの利用上限に達している可能性があります。上限リセットまでDiscord応答が止まります。" || true
  echo "0" > "$STALE_COUNT_FILE"
  exit 0
fi
if echo "$PANE" | grep -qiE "(could not be parsed|malformed and could not)"; then
  echo "PHASE2: tool-call parse failure visible — notify, no restart"
  "$NOTIFY" bridge-parse "ツール呼び出しのparse失敗でターンが停止した可能性があります。次のメッセージで復帰しない場合は手動で再起動してください。" || true
  echo "0" > "$STALE_COUNT_FILE"
  exit 0
fi

# --- Phase 2c: healthy idle (listening line OR idle TUI prompt) ---
# claude >=2.1.201 does not always render the "Listening ..." line, so the
# composer prompt (❯) is the idle signal. Safe because Phase 1 already
# verified the claude process exists (a dead claude never reaches here),
# and pending permission prompts were handled in Phase 2a.

if echo "$PANE" | grep -qE "$SMOKE_STRING|❯"; then
  IDLE_LISTENING=true
else
  IDLE_LISTENING=false
fi

# --- Daily freshness restart: 04:30-04:59 JST, idle, uptime > 20h ---

NOW_JST=$(TZ=Asia/Tokyo date "+%H %M %Y-%m-%d")
HOUR=${NOW_JST%% *}; REST=${NOW_JST#* }; MIN=${REST%% *}; TODAY=${REST#* }
if [ "$HOUR" = "04" ] && [ "$MIN" -ge 30 ] && [ "$IDLE_LISTENING" = true ]; then
  LAST_DAILY=$(cat "$DAILY_MARKER" 2>/dev/null || echo "")
  CREATED=$("$TMUX" -L "$SOCKET" display-message -t "$SESSION" -p '#{session_created}' 2>/dev/null || echo 0)
  UPTIME_H=$(( ($(date +%s) - CREATED) / 3600 ))
  STALE_NOW=$(cat "$STALE_COUNT_FILE" 2>/dev/null || echo 0)
  if [ "$LAST_DAILY" != "$TODAY" ] && [ "$UPTIME_H" -ge 20 ] && [ "$STALE_NOW" -ge 2 ]; then
    echo "$TODAY" > "$DAILY_MARKER"
    echo "PHASE3: daily freshness restart"
    "$BRIDGE_START" restart "daily-rotation" || true
    exit 0
  fi
fi

# --- Phase 2d: unresponsiveness probe (pane hash) ---

CURRENT_HASH=$(echo "$PANE" | /sbin/md5 -q /dev/stdin 2>/dev/null || echo "$PANE" | md5 2>/dev/null || echo unknown)
PREVIOUS_HASH=$(cat "$PANE_HASH_FILE" 2>/dev/null || echo "")

if [ "$CURRENT_HASH" = "$PREVIOUS_HASH" ]; then
  if [ "$IDLE_LISTENING" = true ]; then
    # Frozen pane + listening line = just idle. Count it, but idle alone never restarts.
    STALE=$(( $(cat "$STALE_COUNT_FILE" 2>/dev/null || echo 0) + 1 ))
    echo "$STALE" > "$STALE_COUNT_FILE"
    echo "healthy-idle (listening, stale=$STALE)"
    exit 0
  fi
  STALE=$(( $(cat "$STALE_COUNT_FILE" 2>/dev/null || echo 0) + 1 ))
  echo "$STALE" > "$STALE_COUNT_FILE"
  echo "PHASE2: pane unchanged without listening line ($STALE/$STALE_THRESHOLD)"
  if [ "$STALE" -ge "$STALE_THRESHOLD" ]; then
    echo "0" > "$STALE_COUNT_FILE"
    log_event "health_check_fail" "phase2:unresponsive_${STALE}_checks" "false"
    try_restart "unresponsive"; exit $?
  fi
else
  echo "0" > "$STALE_COUNT_FILE"
  echo "$CURRENT_HASH" > "$PANE_HASH_FILE"
fi

echo "healthy"
exit 0
