#!/bin/bash
# Watchdog: auto-approve file creation prompts in headless bochi session
# Workaround for Claude Code v2.1.x where --dangerously-skip-permissions
# does NOT skip "Do you want to create <file>?" TUI prompts.
# Runs in background, checks every 3 seconds.
SESSION="bochi"
LOG="$HOME/.claude/bochi-data/errors/auto-approve.log"
mkdir -p "$(dirname "$LOG")"

while true; do
  OUTPUT=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null)
  if echo "$OUTPUT" | grep -q "Do you want to create"; then
    echo "$(date -Iseconds) AUTO-APPROVE: detected file creation prompt" >> "$LOG"
    tmux send-keys -t "$SESSION" "1" 2>/dev/null
    sleep 0.5
    tmux send-keys -t "$SESSION" Enter 2>/dev/null
    sleep 5  # wait for file write to complete before checking again
  fi
  sleep 3
done
