#!/bin/bash
# deliver-newspaper.sh — send today's newspaper to Discord from the Mac.
# Thin wrapper around deploy/send-newspaper-to-discord.py (which skips rather
# than resending a stale file).
#
# Called twice by design:
#   1. inline by generate-newspaper.sh, the moment an issue is published
#   2. by com.fideguch.bochi-newspaper-deliver (~08:00 JST) as a backstop
# so a once-per-day marker is what keeps the issue from being sent twice.
# Pass --force to resend deliberately.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
REPO="/Users/fumito_ideguchi/bochi"
DATA="/Users/fumito_ideguchi/bochi-data"
LOG="$DATA/errors/newspaper-cron.log"
NEWS_DIR="$DATA/newspaper"
DATE=$(TZ=Asia/Tokyo date +%Y-%m-%d)
MARKER="$NEWS_DIR/.$DATE.delivered"
mkdir -p "$(dirname "$LOG")" "$NEWS_DIR"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$LOG"; }

FORCE=false
ARGS=()
for a in "$@"; do
  if [ "$a" = "--force" ]; then FORCE=true; else ARGS+=("$a"); fi
done

if [ -f "$MARKER" ] && [ "$FORCE" != true ]; then
  log "SKIP: $DATE already delivered (marker present; --force to resend)"
  exit 0
fi

# Capture stdout so the marker is written only on a real send. The python exits
# 0 on its skip paths too (no fresh issue / malformed), so the exit code alone
# would mark an issue delivered that was never sent, and the backstop would then
# never retry. "--- run ok ---" is printed only after the last message goes out.
OUT=$(/usr/bin/python3 "$REPO/deploy/send-newspaper-to-discord.py" ${ARGS+"${ARGS[@]}"} 2>&1)
RC=$?
printf '%s\n' "$OUT" >> "$LOG"

if printf '%s' "$OUT" | grep -qF -e "--- run ok ---"; then
  : > "$MARKER"
  log "delivered $DATE (marker written)"
  # Keep the marker dir from growing without bound; nothing reads old markers.
  find "$NEWS_DIR" -maxdepth 1 -name ".*.delivered" -mtime +30 -delete 2>/dev/null || true
  exit 0
fi

log "not marked delivered (python rc=$RC) — backstop will retry"
exit "$RC"
