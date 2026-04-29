#!/bin/bash
# bochi cron setup — configure process management crons on Lightsail
# Usage: ssh ubuntu@54.249.49.69 'bash ~/bochi-skill/deploy/setup-cron.sh'
#
# This script is IDEMPOTENT — safe to run multiple times.
# It rebuilds the crontab from scratch to ensure correctness.
#
# NOTE: bochi-daily and bochi-prefetch are managed via RemoteTrigger API,
# NOT via local cron. The --trigger flag does not exist in Claude Code CLI.
set -euo pipefail

CLAUDE_BIN="/usr/bin/claude"

echo "=== bochi Cron Setup ==="

# Verify claude CLI exists
if [ ! -x "$CLAUDE_BIN" ]; then
  echo "ERROR: claude CLI not found at $CLAUDE_BIN"
  exit 1
fi

# Define the ONLY cron entries needed on Lightsail:
# 1. @reboot: auto-start bochi via the full deploy script (with lock, setup, smoke checks)
# 2. health check: monitor and auto-recover every 2 minutes
# 3. S3 safety sync: fallback push/pull every 5 minutes
CRON_REBOOT='@reboot sleep 10 && /home/ubuntu/bochi-skill/deploy/bochi-tmux-start.sh start'
CRON_HEALTH='*/2 * * * * /home/ubuntu/bochi-skill/deploy/bochi-health-check.sh >> /home/ubuntu/bochi-data/errors/watchdog-cron.log 2>&1'
CRON_S3_PULL='*/5 * * * * bash /home/ubuntu/.claude/scripts/hooks/bochi-s3-safety-pull.sh >> /home/ubuntu/bochi-data/errors/safety-sync.log 2>&1'
CRON_S3_PUSH='*/5 * * * * bash /home/ubuntu/.claude/scripts/hooks/bochi-s3-safety-push.sh >> /home/ubuntu/bochi-data/errors/safety-sync.log 2>&1'

# Get existing crontab
EXISTING=$(crontab -l 2>/dev/null || true)
CHANGES=0

# --- Cleanup: remove legacy --trigger entries (managed by RemoteTrigger API now) ---
if echo "$EXISTING" | grep -q "\-\-trigger"; then
  echo "  CLEAN: Removing legacy --trigger cron entries (now managed by RemoteTrigger API)"
  EXISTING=$(echo "$EXISTING" | grep -v "\-\-trigger")
  CHANGES=$((CHANGES + 1))
fi

# --- Cleanup: fix @reboot if it points to the wrong script ---
if echo "$EXISTING" | grep -q "@reboot" && ! echo "$EXISTING" | grep -q "bochi-skill/deploy/bochi-tmux-start.sh"; then
  echo "  FIX: Updating @reboot to use full deploy script"
  EXISTING=$(echo "$EXISTING" | grep -v "@reboot")
  CHANGES=$((CHANGES + 1))
fi

# --- Ensure required entries exist ---

if echo "$EXISTING" | grep -q "bochi-skill/deploy/bochi-tmux-start.sh"; then
  echo "  OK: @reboot (full deploy script)"
else
  EXISTING=$(printf '%s\n%s' "$EXISTING" "$CRON_REBOOT")
  echo "  ADD: @reboot bot startup (full deploy script)"
  CHANGES=$((CHANGES + 1))
fi

if echo "$EXISTING" | grep -q "bochi-health-check"; then
  echo "  OK: health check"
else
  EXISTING=$(printf '%s\n%s' "$EXISTING" "$CRON_HEALTH")
  echo "  ADD: health check (every 2 minutes)"
  CHANGES=$((CHANGES + 1))
fi

if echo "$EXISTING" | grep -q "bochi-s3-safety-pull"; then
  echo "  OK: S3 safety pull"
else
  EXISTING=$(printf '%s\n%s' "$EXISTING" "$CRON_S3_PULL")
  echo "  ADD: S3 safety pull (every 5 minutes)"
  CHANGES=$((CHANGES + 1))
fi

if echo "$EXISTING" | grep -q "bochi-s3-safety-push"; then
  echo "  OK: S3 safety push"
else
  EXISTING=$(printf '%s\n%s' "$EXISTING" "$CRON_S3_PUSH")
  echo "  ADD: S3 safety push (every 5 minutes)"
  CHANGES=$((CHANGES + 1))
fi

# Remove blank lines and install
EXISTING=$(echo "$EXISTING" | sed '/^$/d')

if [ "$CHANGES" -eq 0 ]; then
  echo ""
  echo "All cron entries already correct. No changes made."
else
  echo "$EXISTING" | crontab -
  echo ""
  echo "$CHANGES change(s) applied."
fi

# Ensure error log directory exists
mkdir -p /home/ubuntu/bochi-data/errors

echo ""
echo "Current crontab:"
crontab -l
echo ""
echo "=== Setup Complete ==="
