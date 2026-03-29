#!/bin/bash
# bochi cron setup — configure RemoteTrigger schedules on Lightsail
# Usage: ssh -i ~/.ssh/lightsail-bochi.pem ubuntu@54.249.49.69 'bash ~/bochi-skill/deploy/setup-cron.sh'
#
# This script is IDEMPOTENT — safe to run multiple times.
# It adds bochi cron entries only if they don't already exist.
set -euo pipefail

CLAUDE_BIN="/usr/bin/claude"
SKILL_DIR="/home/ubuntu/bochi-skill"

echo "=== bochi Cron Setup ==="

# Verify claude CLI exists
if [ ! -x "$CLAUDE_BIN" ]; then
  echo "ERROR: claude CLI not found at $CLAUDE_BIN"
  exit 1
fi

# Build the cron entries
# JST = UTC+9, so 08:00 JST = 23:00 UTC (previous day), 06:00 JST = 21:00 UTC (previous day)
# --dangerously-skip-permissions is required for cron execution because:
# cron runs non-interactively — there is no terminal for Claude Code's TUI approval prompts.
# Without this flag, any Write/Edit tool call would hang waiting for user input.
CRON_DAILY='0 23 * * * cd /home/ubuntu/bochi-skill && /usr/bin/claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official --trigger bochi-daily 2>>/home/ubuntu/bochi-data/errors/cron.log'
CRON_PREFETCH='0 21 * * * cd /home/ubuntu/bochi-skill && /usr/bin/claude --dangerously-skip-permissions --trigger bochi-prefetch 2>>/home/ubuntu/bochi-data/errors/cron.log'
CRON_REBOOT='@reboot sleep 10 && /home/ubuntu/bochi-tmux-start.sh start'

# Get existing crontab (suppress "no crontab" error)
EXISTING=$(crontab -l 2>/dev/null || true)

ADDED=0

# Add bochi-daily if not present
if echo "$EXISTING" | grep -q "bochi-daily"; then
  echo "  SKIP: bochi-daily already configured"
else
  EXISTING=$(printf '%s\n%s' "$EXISTING" "$CRON_DAILY")
  echo "  ADD: bochi-daily (08:00 JST / 23:00 UTC)"
  ADDED=$((ADDED + 1))
fi

# Add bochi-prefetch if not present
if echo "$EXISTING" | grep -q "bochi-prefetch"; then
  echo "  SKIP: bochi-prefetch already configured"
else
  EXISTING=$(printf '%s\n%s' "$EXISTING" "$CRON_PREFETCH")
  echo "  ADD: bochi-prefetch (06:00 JST / 21:00 UTC)"
  ADDED=$((ADDED + 1))
fi

# Ensure @reboot is present
if echo "$EXISTING" | grep -q "bochi-tmux-start"; then
  echo "  SKIP: @reboot already configured"
else
  EXISTING=$(printf '%s\n%s' "$EXISTING" "$CRON_REBOOT")
  echo "  ADD: @reboot bot startup"
  ADDED=$((ADDED + 1))
fi

if [ "$ADDED" -eq 0 ]; then
  echo ""
  echo "All cron entries already configured. No changes made."
else
  # Install updated crontab
  echo "$EXISTING" | crontab -
  echo ""
  echo "$ADDED cron entries added."
fi

# Ensure error log directory exists
mkdir -p /home/ubuntu/bochi-data/errors

echo ""
echo "Current crontab:"
crontab -l
echo ""
echo "=== Setup Complete ==="
