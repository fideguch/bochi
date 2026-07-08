#!/bin/bash
# bridge-guard.sh — PreToolUse hard-deny guard for the Mac Claude bridge.
#
# Layer model, v2.7 (see references/mac-bridge-setup.md):
#   auto-allow -> the bridge runs with --permission-mode bypassPermissions;
#                 anything this guard passes through (exit 0) auto-runs.
#   hard-deny  -> exit 2: secrets, enforcement files, tmux interference,
#                 egress binaries, .jsonl shell writes. This guard (plus
#                 permissions.deny) is the LAST line of defense — both are
#                 enforced even under bypassPermissions.
#
# Logic lives in bridge-guard.py (same directory as this script).
# FAIL-CLOSE: any internal error (bad JSON, missing python/py file) exits 2.
set -euo pipefail
trap 'exit 2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD_PY="$SCRIPT_DIR/bridge-guard.py"
[ -f "$GUARD_PY" ] || exit 2

PYTHON_BIN="/usr/bin/python3"
if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="$(command -v python3)" || exit 2
fi

# Read the hook's stdin here and hand it to python via the environment.
BRIDGE_GUARD_INPUT="$(cat)"
export BRIDGE_GUARD_INPUT

exec "$PYTHON_BIN" "$GUARD_PY"
