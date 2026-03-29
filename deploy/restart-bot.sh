#!/bin/bash
# bochi bot restart script — safe deployment with smoke test
# Usage: ssh -i ~/.ssh/lightsail-bochi.pem ubuntu@54.249.49.69 'bash ~/bochi-skill/deploy/restart-bot.sh'
set -euo pipefail

SKILL_DIR="/home/ubuntu/bochi-skill"
SESSION="bochi"

echo "[1/7] Pulling latest skill definitions..."
cd "$SKILL_DIR" && git pull origin main

echo "[2/7] Killing existing bot session..."
tmux kill-session -t "$SESSION" 2>/dev/null || true
sleep 2

echo "[3/7] Setting up SKILL.md, syncing hook scripts, and protecting readonly files..."
# Lightsail uses SKILL-server.md (full version), not SKILL-cli.md
cp -f "$SKILL_DIR/SKILL-server.md" "$SKILL_DIR/SKILL.md" 2>/dev/null || true

# Sync hook scripts from git repo to active hooks directory
# CRITICAL: hooks.json references ~/.claude/scripts/hooks/ — git pull only updates ~/bochi-skill/deploy/
# Without this cp, hook fixes are NEVER deployed (v2.6 Deployment-Sync Blindness incident)
mkdir -p "$HOME/.claude/scripts/hooks"
cp -f "$SKILL_DIR/deploy/protect-readonly.sh" "$HOME/.claude/scripts/hooks/protect-readonly.sh"
chmod +x "$HOME/.claude/scripts/hooks/protect-readonly.sh"

chmod 444 "$SKILL_DIR/SKILL.md" "$SKILL_DIR/deploy/lightsail-claude.md" 2>/dev/null || true
chmod 444 "$HOME/.claude/channels/discord/access.json" 2>/dev/null || true
chmod 444 "$HOME/.claude/hooks/hooks.json" 2>/dev/null || true

echo "[4/7] Starting auto-approve watchdog..."
# Kill any existing watchdog
pkill -f "tmux-auto-approve" 2>/dev/null || true
# Copy watchdog from git repo (same Deployment-Sync pattern as protect-readonly.sh)
cp -f "$SKILL_DIR/deploy/tmux-auto-approve.sh" "$HOME/.claude/scripts/hooks/tmux-auto-approve.sh" 2>/dev/null || true
chmod +x "$HOME/.claude/scripts/hooks/tmux-auto-approve.sh" 2>/dev/null || true
# Start watchdog in background — auto-approves "Do you want to create?" prompts
# Workaround: --dangerously-skip-permissions does NOT skip file creation prompts in v2.1.x
nohup bash "$HOME/.claude/scripts/hooks/tmux-auto-approve.sh" > /dev/null 2>&1 &
WATCHDOG_PID=$!
echo "  Watchdog PID: $WATCHDOG_PID"

echo "[5/7] Starting bot with --dangerously-skip-permissions..."
# Write launcher script to ensure flags are preserved across exec
cat > /tmp/bochi-launcher.sh << 'LAUNCHER'
#!/bin/bash
cd /home/ubuntu/bochi-skill
exec /usr/bin/claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official
LAUNCHER
chmod +x /tmp/bochi-launcher.sh
tmux new-session -d -s "$SESSION" "bash /tmp/bochi-launcher.sh"
sleep 6

echo "[6/7] Smoke test — verifying bot state..."
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

# Check 6: protect-readonly.sh is synced (contains permissionDecision)
# v2.6 fix: without this, the hook silently exits 0 instead of outputting JSON,
# causing Claude Code to show Permission:Write TUI prompts that freeze the bot
if grep -q "permissionDecision" "$HOME/.claude/scripts/hooks/protect-readonly.sh" 2>/dev/null; then
  echo "  PASS: protect-readonly hook has permissionDecision output"
else
  echo "  FAIL: protect-readonly hook is STALE (missing permissionDecision)"
  ERRORS=$((ERRORS + 1))
fi

# Check 7: auto-approve watchdog running
if pgrep -f "tmux-auto-approve" > /dev/null; then
  echo "  PASS: auto-approve watchdog running (PID: $(pgrep -f tmux-auto-approve | head -1))"
else
  echo "  FAIL: auto-approve watchdog NOT running"
  ERRORS=$((ERRORS + 1))
fi

echo "[7/7] Result: $ERRORS errors"
if [ "$ERRORS" -gt 0 ]; then
  echo "DEPLOY FAILED — $ERRORS smoke test(s) failed. Check tmux output:"
  echo "  tmux attach -t $SESSION"
  exit 1
fi

echo "DEPLOY SUCCESS — bot is running with v2.6 specs"
