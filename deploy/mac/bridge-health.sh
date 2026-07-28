#!/bin/bash
# bridge-health.sh — launchd StartInterval(120s) monitor for the Mac bridge.
# Ported from deploy/bochi-health-check.sh (Lightsail) with policy changes:
#   - v2.7: the bridge runs --permission-mode bypassPermissions, so a VISIBLE
#     permission prompt is an ANOMALY (launch flag not applied / CLI regression),
#     not normal waiting. Detection is kept as a fail-safe: treat as healthy
#     waiting (never auto-approve), and if pending >10 min notify the owner.
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
CHANNEL_STALE_FILE="/tmp/claude-bridge-channel-stale"
CHANNEL_STALE_THRESHOLD=2  # 2 x 2min = 4 minutes without a channel process
PERM_SINCE_FILE="/tmp/claude-bridge-perm-since"
DAILY_MARKER="/tmp/claude-bridge-daily-restart"
MAX_RESTARTS_PER_HOUR=5
STALE_THRESHOLD=4   # 4 x 2min = 8 minutes of frozen pane
TICK_FILE="/tmp/claude-bridge-last-tick"
CATCHUP_PENDING_FILE="/tmp/claude-bridge-catchup-pending"
CATCHUP_LAST_FILE="/tmp/claude-bridge-catchup-last"
WAKE_GAP_THRESHOLD=300  # >2.5x the 120s interval = the host was asleep, not slow
CATCHUP_COOLDOWN=600    # at most one catch-up per 10 min across dark-wake churn

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
    # bridge-start.sh injects the same fetch_messages prompt on boot, so a
    # restart already IS a catch-up — drop any queued one to avoid a double ask.
    rm -f "$CATCHUP_PENDING_FILE"
    date +%s > "$CATCHUP_LAST_FILE"
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

# Owner DM channel id via Discord REST; empty string on any failure.
# Duplicated from bridge-start.sh: the two scripts are installed independently
# by setup-bridge.sh and neither sources the other.
resolve_dm_channel() {
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

# Ask the running bridge to re-read Discord history and answer anything it
# missed. Same prompt bridge-start.sh injects at boot, but WITHOUT a restart:
# the session is healthy, it was merely frozen. Returns 0 if injected.
inject_catchup() {
  local gap="$1" now last chat_id hint=""
  now=$(date +%s)
  last=$(cat "$CATCHUP_LAST_FILE" 2>/dev/null || echo 0)
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  if [ $((now - last)) -lt "$CATCHUP_COOLDOWN" ]; then
    rm -f "$CATCHUP_PENDING_FILE"
    echo "PHASE0: catch-up suppressed (last was $((now - last))s ago)"
    return 1
  fi
  chat_id=$(resolve_dm_channel 2>/dev/null || echo "")
  # Brace the expansion: bash 3.2 misparses $var adjacent to multibyte chars.
  [ -n "$chat_id" ] && hint="(chat_id: ${chat_id})"
  # Clear the composer first. Unlike bridge-start.sh, which types into a
  # session it just created, this runs against a long-lived one where a
  # half-typed line could still be sitting there — send-keys appends, so the
  # prompt would be submitted concatenated with it. C-u is a no-op when the
  # composer is empty, and inbound channel messages never pass through the
  # composer (they arrive as queue-operation records), so nothing is lost.
  "$TMUX" -L "$SOCKET" send-keys -t "$SESSION" C-u 2>/dev/null
  # text and Enter must be separate send-keys calls with a pause — a single
  # call is treated as a bracketed paste and never submits.
  "$TMUX" -L "$SOCKET" send-keys -t "$SESSION" \
    "セッション回復: CLAUDE.md の Session Start プロトコルに従って fetch_messages で直近履歴を確認し${hint}、未応答のユーザーメッセージがあれば対応して。無ければ何も送信しないで待機。" 2>/dev/null
  sleep 1
  "$TMUX" -L "$SOCKET" send-keys -t "$SESSION" Enter 2>/dev/null
  echo "$now" > "$CATCHUP_LAST_FILE"
  rm -f "$CATCHUP_PENDING_FILE"
  echo "PHASE0: catch-up injected (gap=${gap}s, chat_id=${chat_id:-unknown})"
  log_event "wake_catchup" "gap:${gap}s" "true"
  return 0
}

# --- Phase 0: wake-gap detection ---
# 2026-07-28 incident: the bridge runs on a laptop that sleeps (clamshell +
# maintenance sleep; measured 44.7% launchd duty cycle over 22 days). While the
# host is asleep the plugin process is frozen, so Discord messages that arrive
# in that window are never seen — Discord does not replay gateway events after
# the fact, and the gateway itself is provably fine once awake. Every liveness
# probe below therefore passes and the pane check reports "healthy-idle", which
# is exactly what happened for 57 hours (stale=815).
# Detect the gap from our own tick and queue a fetch_messages catch-up. The flag
# is a file, not a variable, because the modal/limit branches below exit early —
# the gap must survive until a run that finds an idle prompt to type into.
NOW_TS=$(date +%s)
PREV_TICK=$(cat "$TICK_FILE" 2>/dev/null || echo 0)
case "$PREV_TICK" in ''|*[!0-9]*) PREV_TICK=0 ;; esac
echo "$NOW_TS" > "$TICK_FILE"
if [ "$PREV_TICK" -gt 0 ] && [ $((NOW_TS - PREV_TICK)) -ge "$WAKE_GAP_THRESHOLD" ]; then
  echo "PHASE0: wake gap $((NOW_TS - PREV_TICK))s — queueing catch-up"
  echo "$((NOW_TS - PREV_TICK))" > "$CATCHUP_PENDING_FILE"
  log_event "wake_gap" "gap:$((NOW_TS - PREV_TICK))s" "true"
fi

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

# --- Phase 1.5: discord channel MCP server liveness ---
# 2026-07-15 incident: the discord plugin MCP server missed its startup-connect
# timeout at the 04:30 daily restart, so claude ran all day with --channels in
# argv but NO channel attached — Phase 1 and the idle-prompt check both said
# "healthy-idle" while the owner got zero replies. Claude never retries a
# failed MCP connect, so a bridge restart is the only recovery. The plugin
# server runs as a bun child of the bridge claude process; two consecutive
# misses (~4 min, grace for slow startup/reconnect) trigger a restart, guarded
# by the existing 5/hour backoff.
BRIDGE_PID=$(pgrep -f -- "--channels plugin:discord" 2>/dev/null | head -1)
CHANNEL_PROC_N=0
if [ -n "$BRIDGE_PID" ]; then
  CHANNEL_PROC_N=$(pgrep -P "$BRIDGE_PID" -f "claude-plugins-official/discord" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$CHANNEL_PROC_N" -lt 1 ]; then
  CH_STALE=$(( $(cat "$CHANNEL_STALE_FILE" 2>/dev/null || echo 0) + 1 ))
  echo "$CH_STALE" > "$CHANNEL_STALE_FILE"
  echo "PHASE1.5: discord channel process missing ($CH_STALE/$CHANNEL_STALE_THRESHOLD)"
  if [ "$CH_STALE" -ge "$CHANNEL_STALE_THRESHOLD" ]; then
    echo "0" > "$CHANNEL_STALE_FILE"
    log_event "health_check_fail" "phase1.5:channel_process_missing" "false"
    try_restart "channel_process_missing"; exit $?
  fi
else
  echo "0" > "$CHANNEL_STALE_FILE"
fi

PANE=$(pane_text)

# --- Phase 2-pre: account usage-limit modal ---
# When the shared subscription hits its session/weekly limit, claude shows a
# blocking modal ("Stop and wait for limit to reset" / "Add funds ..." /
# "Switch to Team plan"). It contains "Esc to cancel", so it must be handled
# BEFORE the permission-prompt check or it masquerades as a stuck permission.
# Choose option 1 (wait + auto-resume when the limit resets) and notify once.
# Require BOTH the modal option text AND the modal footer, and only look at the
# bottom of the pane, so conversation text can't trigger the send-keys.
PANE_TAIL=$(echo "$PANE" | tail -20)
if echo "$PANE_TAIL" | grep -qE "(wait for limit to reset|Add funds to continue|Switch to Team plan)" \
   && echo "$PANE_TAIL" | grep -qE "(Esc to cancel|Enter to confirm)"; then
  echo "PHASE2: usage-limit modal — selecting 'wait for reset', notifying once"
  "$TMUX" -L "$SOCKET" send-keys -t "$SESSION" 1 2>/dev/null
  sleep 1
  "$TMUX" -L "$SOCKET" send-keys -t "$SESSION" Enter 2>/dev/null
  "$NOTIFY" bridge-limit "Claude の利用上限に達したため、リセットまで Discord への応答を一時停止します（同じサブスクを共有しているので、他での重い作業を控えると復帰が早まります）。リセット後は自動で再開します。" || true
  echo "0" > "$STALE_COUNT_FILE"
  rm -f "$PERM_SINCE_FILE"
  exit 0
fi

# --- Phase 2a: permission prompt = ANOMALY under v2.7 bypass (fail-safe) ---

# Under --permission-mode bypassPermissions a prompt should never appear; if one
# does, the launch flag was not applied or the CLI regressed. Detection kept as
# a fail-safe with the same "healthy waiting" semantics (exit 0, never
# auto-approve). Match only the prompt UI itself, not conversation text that
# merely contains the word "permission" (false positive verified 2026-07-06).
if echo "$PANE" | grep -qE "(Do you want to proceed|requires approval|Allow once|Allow always|Esc to cancel)"; then
  NOW=$(date +%s)
  if [ -f "$PERM_SINCE_FILE" ]; then
    SINCE=$(cat "$PERM_SINCE_FILE" 2>/dev/null || echo "$NOW")
  else
    SINCE="$NOW"; echo "$NOW" > "$PERM_SINCE_FILE"
  fi
  WAITED=$((NOW - SINCE))
  echo "PHASE2: permission prompt visible (${WAITED}s) — ANOMALY under bypass, fail-safe healthy waiting, never auto-approved"
  echo "0" > "$STALE_COUNT_FILE"
  if [ "$WAITED" -gt 600 ]; then
    "$NOTIFY" bridge-perm "権限プロンプトが表示されています。bypass 設定では本来出ないはずです（フラグ未反映の可能性）。\`bash ~/bochi/deploy/mac/setup-bridge.sh --apply\` で更新後、\`bridge-start.sh restart\` してください。" || true
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

# --- Phase 0b: deliver a queued catch-up ---
# Deliberately placed after the modal/permission/limit branches: every one of
# those exits early, so reaching here proves nothing is waiting for a keystroke
# and send-keys cannot be swallowed by a dialog. An idle prompt is still
# required — typing mid-turn would interleave with the model's own output.
if [ -f "$CATCHUP_PENDING_FILE" ] && [ "$IDLE_LISTENING" = true ]; then
  if inject_catchup "$(cat "$CATCHUP_PENDING_FILE" 2>/dev/null || echo 0)"; then
    echo "0" > "$STALE_COUNT_FILE"
    exit 0
  fi
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
