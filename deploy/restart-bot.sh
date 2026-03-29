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

echo "[3/5] Setting up SKILL.md (server version) and protecting readonly files..."
# Lightsail uses SKILL-server.md (full version), not SKILL-cli.md
cp -f "$SKILL_DIR/SKILL-server.md" "$SKILL_DIR/SKILL.md" 2>/dev/null || true
chmod 444 "$SKILL_DIR/SKILL.md" "$SKILL_DIR/deploy/lightsail-claude.md" 2>/dev/null || true
chmod 444 "$HOME/.claude/channels/discord/access.json" 2>/dev/null || true
chmod 444 "$HOME/.claude/hooks/hooks.json" 2>/dev/null || true

echo "[4/6] Starting bot with --dangerously-skip-permissions..."
# Write launcher script to ensure flags are preserved across exec
cat > /tmp/bochi-launcher.sh << 'LAUNCHER'
#!/bin/bash
cd /home/ubuntu/bochi-skill
exec /usr/bin/claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official
LAUNCHER
chmod +x /tmp/bochi-launcher.sh
tmux new-session -d -s "$SESSION" "bash /tmp/bochi-launcher.sh"
sleep 6

echo "[5/6] Smoke test — verifying bot state..."
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

# Check 5: protect-readonly hook registered
if grep -q "protect-readonly" "$HOME/.claude/hooks/hooks.json" 2>/dev/null; then
  echo "  PASS: protect-readonly hook registered"
else
  echo "  FAIL: protect-readonly hook NOT in hooks.json"
  ERRORS=$((ERRORS + 1))
fi

echo "[6/6] Result: $ERRORS errors"
if [ "$ERRORS" -gt 0 ]; then
  echo "DEPLOY FAILED — $ERRORS smoke test(s) failed. Check tmux output:"
  echo "  tmux attach -t $SESSION"
  exit 1
fi

echo "DEPLOY SUCCESS — bot is running with v2.5 specs"
