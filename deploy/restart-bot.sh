#!/bin/bash
# bochi bot restart script — safe deployment with smoke test
# Usage: ssh -i ~/.ssh/lightsail-bochi.pem ubuntu@54.249.49.69 'bash ~/bochi-skill/deploy/restart-bot.sh'
set -euo pipefail

SKILL_DIR="/home/ubuntu/bochi-skill"
SESSION="bochi"

echo "[1/5] Pulling latest skill definitions..."
cd "$SKILL_DIR" && git pull origin main

echo "[2/5] Killing existing bot session..."
tmux kill-session -t "$SESSION" 2>/dev/null || true
sleep 2

echo "[3/5] Starting bot with --dangerously-skip-permissions..."
tmux new-session -d -s "$SESSION" \
  "cd $SKILL_DIR; exec claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official"
sleep 6

echo "[4/5] Smoke test — verifying bot state..."
ERRORS=0

# Check 1: Discord gateway connected
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
  echo "  FAIL: bypass permissions NOT active — bot will prompt for permissions"
  ERRORS=$((ERRORS + 1))
fi

# Check 3: claude process running
if pgrep -f "^claude" > /dev/null; then
  echo "  PASS: claude process running"
else
  echo "  FAIL: claude process NOT found"
  ERRORS=$((ERRORS + 1))
fi

# Check 4: bun (Discord plugin) running
if pgrep -f "bun.*server.ts" > /dev/null; then
  echo "  PASS: Discord plugin (bun) running"
else
  echo "  FAIL: Discord plugin NOT running"
  ERRORS=$((ERRORS + 1))
fi

echo "[5/5] Result: $ERRORS errors"
if [ "$ERRORS" -gt 0 ]; then
  echo "DEPLOY FAILED — $ERRORS smoke test(s) failed. Check tmux output:"
  echo "  tmux attach -t $SESSION"
  exit 1
fi

echo "DEPLOY SUCCESS — bot is running with v2.5 specs"
