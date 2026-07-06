#!/bin/bash
# notify-owner.sh <cooldown-key> <message>
# Sends a Discord DM to the owner via REST (no Claude session required).
# Same pattern as deploy/send-newspaper-to-discord.py: token from the plugin
# .env, recipient from access.json allowFrom[0]. Cooldown: 1h per key.
set -euo pipefail

KEY="${1:?usage: notify-owner.sh <cooldown-key> <message>}"
MSG="${2:?usage: notify-owner.sh <cooldown-key> <message>}"
ENV_FILE="$HOME/.claude/channels/discord/.env"
ACCESS_FILE="$HOME/.claude/channels/discord/access.json"
COOLDOWN_FILE="/tmp/claude-bridge-notify-$KEY"
COOLDOWN_SECONDS=3600

[ -f "$ENV_FILE" ] || exit 0
[ -f "$ACCESS_FILE" ] || exit 0

if [ -f "$COOLDOWN_FILE" ]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$COOLDOWN_FILE" 2>/dev/null || echo 0) ))
  [ "$AGE" -lt "$COOLDOWN_SECONDS" ] && exit 0
fi

TOKEN=$(grep -m1 '^DISCORD_BOT_TOKEN=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
[ -n "$TOKEN" ] || exit 0

USER_ID=$(/usr/bin/python3 -c "
import json,sys
try:
    a = json.load(open('$ACCESS_FILE'))
    lst = a.get('allowFrom') or []
    print(lst[0] if lst else '')
except Exception:
    print('')
")
[ -n "$USER_ID" ] || exit 0

API="https://discord.com/api/v10"
CHANNEL_ID=$(curl -s -X POST "$API/users/@me/channels" \
  -H "Authorization: Bot $TOKEN" -H "Content-Type: application/json" \
  -d "{\"recipient_id\": \"$USER_ID\"}" | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
[ -n "$CHANNEL_ID" ] || exit 0

PAYLOAD=$(/usr/bin/python3 -c "
import json,sys
print(json.dumps({'content': '🔧 ' + sys.argv[1][:1800]}))
" "$MSG")

curl -s -X POST "$API/channels/$CHANNEL_ID/messages" \
  -H "Authorization: Bot $TOKEN" -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1 || exit 0

touch "$COOLDOWN_FILE"
