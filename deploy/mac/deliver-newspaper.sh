#!/bin/bash
# deliver-newspaper.sh — send today's newspaper to Discord from the Mac.
# Thin wrapper around deploy/send-newspaper-to-discord.py (which now skips
# rather than resending a stale file). Scheduled ~08:00 JST.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
REPO="/Users/fumito_ideguchi/bochi"
LOG="/Users/fumito_ideguchi/bochi-data/errors/newspaper-cron.log"
mkdir -p "$(dirname "$LOG")"
/usr/bin/python3 "$REPO/deploy/send-newspaper-to-discord.py" "$@" >> "$LOG" 2>&1
