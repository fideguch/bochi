#!/bin/bash
# bochi bot restart script — safe deployment with smoke test
# Usage: ssh -i ~/.ssh/lightsail-bochi.pem ubuntu@54.249.49.69 'bash ~/bochi-skill/deploy/restart-bot.sh'
set -euo pipefail

SKILL_DIR="/home/ubuntu/bochi-skill"
SESSION="bochi"
BOCHI_DATA="/home/ubuntu/bochi-data"
BOCHI_DATA_LINK="$HOME/.claude/bochi-data"

echo "[1/6] Pulling latest skill definitions..."
cd "$SKILL_DIR" && git pull origin main

echo "[2/6] Delegating restart to bochi-tmux-start.sh..."
# Core start/stop/data-migration logic is now in bochi-tmux-start.sh.
# This avoids duplication and ensures @reboot cron uses the same logic.
"$SKILL_DIR/deploy/bochi-tmux-start.sh" restart "deploy"
echo "  bochi-tmux-start.sh restart completed"

echo "[3/6] Basic health via bochi-tmux-start.sh status..."
STATUS_OUTPUT=$("$SKILL_DIR/deploy/bochi-tmux-start.sh" status) || true
echo "  Status: $STATUS_OUTPUT"

echo "[4/6] Extended smoke test — deploy-specific checks..."
ERRORS=0

# Check 1: Discord gateway connected (needs more startup time than basic checks)
if tmux capture-pane -t "$SESSION" -p | grep -q "Listening for channel"; then
  echo "  PASS: Discord gateway connected"
else
  echo "  FAIL: Discord gateway NOT connected"
  ERRORS=$((ERRORS + 1))
fi

# Check 2: bypass permissions active
if tmux capture-pane -t "$SESSION" -p | grep -q "bypass permissions on"; then
  echo "  PASS: bypass permissions ON"
else
  echo "  FAIL: bypass permissions NOT active"
  ERRORS=$((ERRORS + 1))
fi

# Check 3: protect-readonly hook registered
if grep -q "protect-readonly" "$HOME/.claude/hooks/hooks.json" 2>/dev/null; then
  echo "  PASS: protect-readonly hook registered"
else
  echo "  FAIL: protect-readonly hook NOT in hooks.json"
  ERRORS=$((ERRORS + 1))
fi

# Check 4: protect-readonly.sh is synced and has correct output format
if grep -q "permissionDecision" "$HOME/.claude/scripts/hooks/protect-readonly.sh" 2>/dev/null; then
  echo "  PASS: protect-readonly hook has permissionDecision output"
else
  echo "  FAIL: protect-readonly hook is STALE (missing permissionDecision)"
  ERRORS=$((ERRORS + 1))
fi

# Check 5: bochi-data contains required files
if [ -f "$BOCHI_DATA/index.jsonl" ] || [ -f "$BOCHI_DATA/user-profile.yaml" ]; then
  echo "  PASS: bochi-data contains data files"
else
  echo "  FAIL: bochi-data is EMPTY (index.jsonl and user-profile.yaml missing)"
  ERRORS=$((ERRORS + 1))
fi

# Check 6: S3 sync hooks reference bochi-data path (symlink-compatible)
if grep -q "bochi-data" "$HOME/.claude/scripts/hooks/bochi-s3-push.sh" 2>/dev/null; then
  echo "  PASS: S3 push hook references bochi-data"
else
  echo "  WARN: S3 push hook not found (non-blocking)"
fi

echo "[5/6] Result: $ERRORS extended check errors"
if [ "$ERRORS" -gt 0 ]; then
  echo "DEPLOY FAILED — $ERRORS smoke test(s) failed. Check tmux output:"
  echo "  tmux attach -t $SESSION"
  exit 1
fi

echo "[6/6] DEPLOY SUCCESS — bot is running with auto-recovery enabled (data: ~/bochi-data/)"
