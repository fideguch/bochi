#!/bin/bash
# Watchdog: auto-approve TUI permission prompts in headless bochi session
# FALLBACK safety net for Claude Code v2.1.x permission prompt issues.
# Primary fix: bochi-data moved outside .claude/ (restart-bot.sh Step 3).
# This watchdog catches any remaining edge cases.
# Runs in background, checks every 3 seconds.
SESSION="bochi"
LOG="$HOME/bochi-data/errors/auto-approve.log"
mkdir -p "$(dirname "$LOG")"

while true; do
  OUTPUT=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null)

  # Pattern 1: File creation prompt ("Do you want to create X?")
  # Pattern 2: File edit prompt ("Do you want to make this edit?")
  # Pattern 3: Settings edit prompt ("edit its own settings")
  # Pattern 4: Generic permission prompt ("Permission:" in TUI)
  if echo "$OUTPUT" | grep -qE "(Do you want to create|Do you want to make this edit|edit its own settings|❯ 1\. Yes|Allow once|Permission:|permission to write|Allow this action)"; then
    MATCHED=$(echo "$OUTPUT" | grep -oE "(Do you want to create|Do you want to make this edit|edit its own settings|Allow once|Permission:|permission to write|Allow this action)" | head -1)
    echo "$(date -Iseconds) AUTO-APPROVE: $MATCHED" >> "$LOG"
    tmux send-keys -t "$SESSION" "1" 2>/dev/null
    sleep 0.5
    tmux send-keys -t "$SESSION" Enter 2>/dev/null
    sleep 5
  fi

  sleep 3
done
