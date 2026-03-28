#!/bin/bash
# PreToolUse hook: block writes to protected system files
# WRITABLE: ~/.claude/bochi-data/ only
# READONLY: skills/, channels/, plugins/, hooks/, settings, CLAUDE.md
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

# Extract file_path from Write/Edit tool_input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || true)

# Extract command from Bash tool_input for redirect/write detection
if [ -z "$FILE_PATH" ]; then
  COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || true)
  if [ -n "$COMMAND" ]; then
    FILE_PATH=$(echo "$COMMAND" | grep -oE '(~/|/home/[^/]+/)\.claude/(skills|channels|plugins|hooks)' | head -1 || true)
  fi
fi

# Fail-open: if path extraction fails, allow the write.
# This prevents blocking legitimate operations on unexpected input formats.
[ -z "$FILE_PATH" ] && exit 0

# ALLOW: bochi-data is the writable zone
echo "$FILE_PATH" | grep -q "bochi-data" && exit 0

# BLOCK: protected paths
if echo "$FILE_PATH" | grep -qE '(\.claude/skills|\.claude/channels|\.claude/plugins|\.claude/hooks|settings\.local\.json|settings\.json|SKILL\.md|CLAUDE\.md|lightsail-claude|access\.json|hooks\.json|server\.ts)'; then
  echo "BLOCKED: この領域は保護されているゆ。bochi-data/ のみ書き込み可能ゆ。" >&2
  exit 2
fi

exit 0
