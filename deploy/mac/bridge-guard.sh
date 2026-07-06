#!/bin/bash
# bridge-guard.sh — PreToolUse hard-deny guard for the Mac Claude bridge.
#
# Layer model (see references/mac-bridge-setup.md):
#   allow  -> permissions.allow in bridge-settings.json (no prompt)
#   ask    -> anything else falls through this guard (exit 0) to the
#             permission system, which relays to Discord approval buttons
#   deny   -> exit 2: secrets, enforcement files, tmux interference.
#             Not approvable even by button (anti rubber-stamp).
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
