#!/usr/bin/env bash
# bochi Discord Post-Interaction Verification
# Validates bot behavior by inspecting recent Discord messages and server-side state.
# Run AFTER a human sends test messages to the bot.
#
# Usage: DISCORD_BOT_TOKEN=... DISCORD_USER_ID=... ./tests/discord-e2e.sh
# Requires: bot running on Lightsail, curl, jq, python3
#
# Environment variables:
#   DISCORD_BOT_TOKEN  — Bot token (from .env)
#   DISCORD_USER_ID    — Owner's Discord user ID (for DM channel lookup)
#   BOCHI_SSH_KEY      — Path to SSH key (default: ~/.ssh/lightsail-bochi.pem)
#   BOCHI_HOST         — Lightsail IP (default: 54.249.49.69)
#   LOOKBACK_MINUTES   — How far back to check for recent activity (default: 30)

set -euo pipefail

: "${DISCORD_BOT_TOKEN:?Set DISCORD_BOT_TOKEN}"
: "${DISCORD_USER_ID:?Set DISCORD_USER_ID}"
BOCHI_SSH_KEY="${BOCHI_SSH_KEY:-$HOME/.ssh/lightsail-bochi.pem}"
BOCHI_HOST="${BOCHI_HOST:-54.249.49.69}"
LOOKBACK="${LOOKBACK_MINUTES:-30}"
API="https://discord.com/api/v10"
PASS=0
FAIL=0
WARN=0

pass() { ((PASS++)); echo "  PASS: $1"; }
fail() { ((FAIL++)); echo "  FAIL: $1"; }
warn() { ((WARN++)); echo "  WARN: $1"; }

# Helper: Discord API call
discord_api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -s -X "$method" "$API$endpoint" \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    "$@"
}

# Helper: Get or create DM channel
get_dm_channel() {
  discord_api POST "/users/@me/channels" \
    -d "{\"recipient_id\": \"$DISCORD_USER_ID\"}" | jq -r '.id'
}

# Helper: Check if a Discord timestamp is within lookback window
is_recent() {
  local iso_ts="$1"
  python3 -c "
import sys
from datetime import datetime, timezone, timedelta
ts = datetime.fromisoformat('$iso_ts'.replace('+00:00','').rstrip('Z'))
ts = ts.replace(tzinfo=timezone.utc)
cutoff = datetime.now(timezone.utc) - timedelta(minutes=$LOOKBACK)
sys.exit(0 if ts >= cutoff else 1)
" 2>/dev/null
}

# Helper: Check for banned emoji in text
check_banned_emoji() {
  local text="$1"
  python3 -c "
import sys
banned = ['\U0001f44b', '\U0001f642', '\U0001f60a', '\u2764\ufe0f', '\U0001f44d', '\U0001f604']
labels = {'\\U0001f44b':'wave','\\U0001f642':'slightly_smiling','\\U0001f60a':'blush','\\u2764\\ufe0f':'heart','\\U0001f44d':'thumbsup','\\U0001f604':'smile'}
text = sys.stdin.read()
found = [e for e in banned if e in text]
if found:
    print(','.join(found))
else:
    print('none')
" <<< "$text" 2>/dev/null
}

# Helper: Check yu suffix ratio in text
check_yu_suffix() {
  local text="$1"
  python3 -c "
import sys, re
text = sys.stdin.read()
sentences = re.split(r'[。！？\n]', text)
sentences = [s.strip() for s in sentences if s.strip() and len(s.strip()) > 3]
total = len(sentences)
if total == 0:
    print('0/0')
else:
    yu_count = sum(1 for s in sentences if re.search(r'ゆ[！？〜]?\s*$', s))
    print(f'{yu_count}/{total}')
" <<< "$text" 2>/dev/null
}

# Helper: SSH command on Lightsail
ssh_cmd() {
  ssh -i "$BOCHI_SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "ubuntu@$BOCHI_HOST" "$@" 2>/dev/null
}

echo "=== bochi Discord Post-Interaction Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Lookback window: ${LOOKBACK} minutes"
echo ""

# --- Setup: Get DM channel ---
echo "[Setup] Getting DM channel..."
DM_CHANNEL=$(get_dm_channel)
if [ "$DM_CHANNEL" = "null" ] || [ -z "$DM_CHANNEL" ]; then
  echo "FATAL: Cannot get DM channel. Aborting."
  exit 1
fi
echo "DM Channel: $DM_CHANNEL"
echo ""

# ============================================================
# PHASE 1: Record baseline state
# ============================================================
echo "[Phase 1] Recording server-side baseline..."

SEEN_COUNT_BEFORE=""
NEWSPAPER_COUNT_BEFORE=""
REFLECTION_COUNT_BEFORE=""

if ssh_cmd "test -f ~/bochi-data/seen.jsonl" 2>/dev/null; then
  SEEN_COUNT_BEFORE=$(ssh_cmd "wc -l < ~/bochi-data/seen.jsonl" 2>/dev/null | tr -d '[:space:]')
  echo "  seen.jsonl lines: ${SEEN_COUNT_BEFORE:-unknown}"
else
  echo "  seen.jsonl: not found"
fi

NEWSPAPER_COUNT_BEFORE=$(ssh_cmd "ls ~/bochi-data/newspaper/ 2>/dev/null | wc -l" 2>/dev/null | tr -d '[:space:]')
echo "  newspaper/ files: ${NEWSPAPER_COUNT_BEFORE:-0}"

REFLECTION_COUNT_BEFORE=$(ssh_cmd "ls ~/bochi-data/reflections/ 2>/dev/null | wc -l" 2>/dev/null | tr -d '[:space:]')
echo "  reflections/ files: ${REFLECTION_COUNT_BEFORE:-0}"

echo ""

# ============================================================
# PHASE 2: Fetch recent Discord messages
# ============================================================
echo "[Phase 2] Fetching recent DM messages..."

MESSAGES=$(discord_api GET "/channels/$DM_CHANNEL/messages?limit=50")
MSG_COUNT=$(echo "$MESSAGES" | jq 'length' 2>/dev/null)

if [ -z "$MSG_COUNT" ] || [ "$MSG_COUNT" -eq 0 ]; then
  echo "FATAL: No messages found in DM channel."
  exit 1
fi
echo "  Fetched $MSG_COUNT messages"

# Separate bot and user messages
BOT_MESSAGES=$(echo "$MESSAGES" | jq '[.[] | select(.author.bot == true)]')
USER_MESSAGES=$(echo "$MESSAGES" | jq '[.[] | select(.author.bot != true)]')
BOT_MSG_COUNT=$(echo "$BOT_MESSAGES" | jq 'length')
USER_MSG_COUNT=$(echo "$USER_MESSAGES" | jq 'length')

echo "  Bot messages: $BOT_MSG_COUNT"
echo "  User messages: $USER_MSG_COUNT"
echo ""

# ============================================================
# TEST 1: Recent bot activity
# ============================================================
echo "[TEST 1] Recent bot activity (within ${LOOKBACK}m)"

RECENT_BOT_COUNT=0
if [ "$BOT_MSG_COUNT" -gt 0 ]; then
  while IFS= read -r ts; do
    if is_recent "$ts"; then
      ((RECENT_BOT_COUNT++))
    fi
  done < <(echo "$BOT_MESSAGES" | jq -r '.[].timestamp')
fi

if [ "$RECENT_BOT_COUNT" -gt 0 ]; then
  pass "T1: $RECENT_BOT_COUNT bot responses within last ${LOOKBACK}m"
else
  warn "T1: No bot responses within last ${LOOKBACK}m (send messages first, then re-run)"
fi
echo ""

# ============================================================
# TEST 2: Character voice — yu suffix
# ============================================================
echo "[TEST 2] Character voice: yu suffix consistency (CH-01)"

if [ "$BOT_MSG_COUNT" -gt 0 ]; then
  TOTAL_YU_HIT=0
  TOTAL_YU_ALL=0
  SAMPLE_COUNT=0

  while IFS= read -r content; do
    [ -z "$content" ] && continue
    result=$(check_yu_suffix "$content")
    hit=$(echo "$result" | cut -d/ -f1)
    total=$(echo "$result" | cut -d/ -f2)
    TOTAL_YU_HIT=$((TOTAL_YU_HIT + hit))
    TOTAL_YU_ALL=$((TOTAL_YU_ALL + total))
    ((SAMPLE_COUNT++))
  done < <(echo "$BOT_MESSAGES" | jq -r '.[].content // empty')

  if [ "$TOTAL_YU_ALL" -gt 0 ]; then
    echo "  yu sentences: $TOTAL_YU_HIT / $TOTAL_YU_ALL across $SAMPLE_COUNT messages"
    # At least 50% of sentences should end with yu
    RATIO=$((TOTAL_YU_HIT * 100 / TOTAL_YU_ALL))
    if [ "$RATIO" -ge 50 ]; then
      pass "CH-01: yu suffix ratio ${RATIO}% (>= 50%)"
    else
      fail "CH-01: yu suffix ratio ${RATIO}% (< 50%)"
    fi
  else
    warn "CH-01: No sentences to evaluate for yu suffix"
  fi
else
  warn "CH-01: No bot messages to evaluate"
fi
echo ""

# ============================================================
# TEST 3: Banned emoji check
# ============================================================
echo "[TEST 3] Banned emoji check (CH-02)"

BANNED_FOUND=0
if [ "$BOT_MSG_COUNT" -gt 0 ]; then
  while IFS= read -r content; do
    [ -z "$content" ] && continue
    result=$(check_banned_emoji "$content")
    if [ "$result" != "none" ]; then
      ((BANNED_FOUND++))
      echo "  Found banned emoji in message: $result"
    fi
  done < <(echo "$BOT_MESSAGES" | jq -r '.[].content // empty')

  if [ "$BANNED_FOUND" -eq 0 ]; then
    pass "CH-02: No banned emoji in $BOT_MSG_COUNT bot messages"
  else
    fail "CH-02: Banned emoji found in $BANNED_FOUND messages"
  fi
else
  warn "CH-02: No bot messages to evaluate"
fi
echo ""

# ============================================================
# TEST 4: Message length limit (UX-01)
# ============================================================
echo "[TEST 4] Message length limit < 2000 chars (UX-01)"

OVER_LIMIT=0
MAX_LEN=0
if [ "$BOT_MSG_COUNT" -gt 0 ]; then
  while IFS= read -r content; do
    [ -z "$content" ] && continue
    len=${#content}
    if [ "$len" -gt "$MAX_LEN" ]; then MAX_LEN=$len; fi
    if [ "$len" -gt 2000 ]; then ((OVER_LIMIT++)); fi
  done < <(echo "$BOT_MESSAGES" | jq -r '.[].content // empty')

  if [ "$OVER_LIMIT" -eq 0 ]; then
    pass "UX-01: All $BOT_MSG_COUNT messages under 2000 chars (max: $MAX_LEN)"
  else
    fail "UX-01: $OVER_LIMIT messages exceed 2000 char limit"
  fi
else
  warn "UX-01: No bot messages to evaluate"
fi
echo ""

# ============================================================
# TEST 5: Session continuity — no exposed restarts
# ============================================================
echo "[TEST 5] Session continuity (EH-02)"

EXPOSED_COUNT=0
if [ "$BOT_MSG_COUNT" -gt 0 ]; then
  while IFS= read -r content; do
    [ -z "$content" ] && continue
    if echo "$content" | grep -qE '新しいセッション|記憶がありません|前回の.*ありません|初めまして'; then
      ((EXPOSED_COUNT++))
    fi
  done < <(echo "$BOT_MESSAGES" | jq -r '.[].content // empty')

  if [ "$EXPOSED_COUNT" -eq 0 ]; then
    pass "EH-02: No exposed session restarts in $BOT_MSG_COUNT messages"
  else
    fail "EH-02: $EXPOSED_COUNT messages expose session restart"
  fi
else
  warn "EH-02: No bot messages to evaluate"
fi
echo ""

# ============================================================
# TEST 6: Server-side data changes
# ============================================================
echo "[TEST 6] Server-side data verification"

# 6a: seen.jsonl
if [ -n "$SEEN_COUNT_BEFORE" ]; then
  SEEN_COUNT_NOW=$(ssh_cmd "wc -l < ~/bochi-data/seen.jsonl" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$SEEN_COUNT_NOW" ] && [ "$SEEN_COUNT_NOW" -gt 0 ]; then
    pass "DATA-01: seen.jsonl has $SEEN_COUNT_NOW entries"
    if [ "$SEEN_COUNT_NOW" -gt "$SEEN_COUNT_BEFORE" ]; then
      DELTA=$((SEEN_COUNT_NOW - SEEN_COUNT_BEFORE))
      echo "  (+$DELTA entries since baseline)"
    fi
  else
    warn "DATA-01: seen.jsonl is empty or unreadable"
  fi
else
  if ssh_cmd "test -f ~/bochi-data/seen.jsonl" 2>/dev/null; then
    SEEN_COUNT_NOW=$(ssh_cmd "wc -l < ~/bochi-data/seen.jsonl" 2>/dev/null | tr -d '[:space:]')
    pass "DATA-01: seen.jsonl exists ($SEEN_COUNT_NOW entries)"
  else
    warn "DATA-01: seen.jsonl not found (bot may not have processed newspaper yet)"
  fi
fi

# 6b: newspaper/ directory
NEWSPAPER_COUNT_NOW=$(ssh_cmd "ls ~/bochi-data/newspaper/ 2>/dev/null | wc -l" 2>/dev/null | tr -d '[:space:]')
NEWSPAPER_COUNT_NOW="${NEWSPAPER_COUNT_NOW:-0}"
if [ "$NEWSPAPER_COUNT_NOW" -gt 0 ]; then
  pass "DATA-02: newspaper/ has $NEWSPAPER_COUNT_NOW files"
else
  warn "DATA-02: newspaper/ is empty (no newspaper generated yet)"
fi

# 6c: reflections/ directory
REFLECTION_COUNT_NOW=$(ssh_cmd "ls ~/bochi-data/reflections/ 2>/dev/null | wc -l" 2>/dev/null | tr -d '[:space:]')
REFLECTION_COUNT_NOW="${REFLECTION_COUNT_NOW:-0}"
if [ "$REFLECTION_COUNT_NOW" -gt 0 ]; then
  pass "DATA-03: reflections/ has $REFLECTION_COUNT_NOW files"
else
  warn "DATA-03: reflections/ is empty"
fi
echo ""

# ============================================================
# TEST 7: S3 sync verification
# ============================================================
echo "[TEST 7] S3 sync verification"

S3_FILE_COUNT=$(ssh_cmd "aws s3 ls s3://bochi-sync-fumito/bochi-data/ --region ap-northeast-1 --recursive 2>/dev/null | wc -l" 2>/dev/null | tr -d '[:space:]')
S3_FILE_COUNT="${S3_FILE_COUNT:-0}"

if [ "$S3_FILE_COUNT" -gt 0 ]; then
  pass "S3-01: $S3_FILE_COUNT files synced in bochi-data/"

  # Check seen.jsonl specifically
  if ssh_cmd "aws s3 ls s3://bochi-sync-fumito/bochi-data/seen.jsonl --region ap-northeast-1" 2>/dev/null | grep -q "seen.jsonl"; then
    pass "S3-02: seen.jsonl present in S3"
  else
    warn "S3-02: seen.jsonl not found in S3"
  fi
else
  warn "S3-01: No files in S3 bochi-data/ (sync may not have run)"
fi
echo ""

# ============================================================
# TEST 8: Newspaper format validation (if any exist)
# ============================================================
echo "[TEST 8] Newspaper format in bot messages"

NEWSPAPER_DETECTED=0
if [ "$BOT_MSG_COUNT" -gt 0 ]; then
  while IFS= read -r content; do
    [ -z "$content" ] && continue
    if echo "$content" | grep -qE '(PM|AI|Tech|##|📰|朝刊|速報)'; then
      ((NEWSPAPER_DETECTED++))
    fi
  done < <(echo "$BOT_MESSAGES" | jq -r '.[].content // empty')

  if [ "$NEWSPAPER_DETECTED" -gt 0 ]; then
    pass "NP-01: $NEWSPAPER_DETECTED messages contain newspaper-format content"
  else
    warn "NP-01: No newspaper-format messages found (may not have been triggered)"
  fi
else
  warn "NP-01: No bot messages to check"
fi
echo ""

# --- Summary ---
echo "================================="
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "================================="
echo ""
echo "Note: This is a post-interaction verification script."
echo "For best results, have a human send test messages to the bot"
echo "(e.g., '朝刊', casual chat, '前に話したこと覚えてる？')"
echo "then run this script within ${LOOKBACK} minutes."

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
