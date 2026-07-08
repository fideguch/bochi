#!/usr/bin/env python3
"""bridge-guard.py — hard-deny logic for the Mac Claude bridge PreToolUse hook.

Invoked by bridge-guard.sh with the hook JSON in $BRIDGE_GUARD_INPUT.
Exit 2 = deny (blocks the tool call). Under v2.7 bypass mode
(--permission-mode bypassPermissions) there is no 'ask' layer, so exit 0 means
the call AUTO-RUNS: this guard is the LAST line of defense together with the
settings permissions.deny rules (both are enforced even in bypass mode).
"""
import json
import os
import re
import sys

try:
    data = json.loads(os.environ.get("BRIDGE_GUARD_INPUT", ""))
except Exception:
    sys.exit(2)  # fail-close on malformed input

tool = data.get("tool_name", "")
tool_input = data.get("tool_input", {}) or {}


def norm(p: str) -> str:
    """Collapse ~, ../ and // so path tricks cannot dodge the patterns.
    APFS is case-insensitive by default, hence re.IGNORECASE below."""
    try:
        return os.path.normpath(os.path.expanduser(p))
    except Exception:
        return p


# Paths whose read or write must never happen, even with user approval.
SENSITIVE = re.compile(
    r"(\.ssh(/|\b)|\.aws(/|\b)|\.config/gcloud|\.config/gh(/|\b)|claude-to-codex|"
    r"\.docker(/|\b)|\.kube(/|\b)|\.gnupg|\.netrc|Keychains|"
    r"channels/discord|\.env\b|\.env\.|credentials|google-ads\.yaml|"
    r"\bid_rsa\b|\bid_ed25519\b|\.pem\b|"
    r"\.claude/projects/[^ ]*\.jsonl)",
    re.IGNORECASE,
)

# The bridge's own enforcement surface: self-modification is forbidden.
# 'deploy/mac' and 'mac-claude.md' are matched WITHOUT a repo prefix so that
# relative writes after `cd` (e.g. `cd ~/bochi && echo x > deploy/mac/...`)
# are still caught. '\.claude\.json' is the GLOBAL ~/.claude.json (trust/config)
# — the bridge must not modify its own trust store; it does NOT match the
# separately-covered '.claude/settings.json' (dir path, not a .json suffix).
ENFORCEMENT = re.compile(
    r"(bochi-runtime/CLAUDE\.md|bochi-runtime/\.claude|bochi-runtime/bin|"
    r"\.claude/settings(\.local)?\.json|\.claude\.json\b|Library/LaunchAgents|"
    r"\.claude/scripts/hooks|\.z(shrc|shenv|profile)\b|"
    r"/bochi/deploy/|deploy/mac(/|\b)|mac-claude\.md|"
    r"/tmp/claude-bridge-)",
    re.IGNORECASE,
)

# v2.7: bypass mode has no 'ask' layer, so these Bash-only controls compensate.
# EGRESS raises the bar on the most COMMON network-egress binaries. It is NOT
# exhaustive — interpreter-mediated egress (python/node sockets) and bash
# /dev/tcp remain reachable; the primary confidentiality boundary is still the
# SENSITIVE read-deny (unreadable secrets cannot be exfiltrated).
EGRESS = re.compile(r"\b(curl|wget|nc|ncat|netcat)\b", re.IGNORECASE)

# Shell redirect (> / >>) or tee INTO a *.jsonl file. bochi-data JSONL stores
# (index/seen/errors) must be edited via the Write/Edit tool (Read->append->
# Write); a shell append truncated seen.jsonl in the v2.5 corruption incident.
# Reads/pipes FROM a .jsonl (cat/wc/sort of a .jsonl) are unaffected.
JSONL_SHELL_WRITE = re.compile(
    r"(>>?\s*|\btee\s+(-a\s+)?)[^|;&\s]*\.jsonl\b", re.IGNORECASE
)

# Any bare tmux invocation is forbidden (tmux accepts unambiguous prefix
# abbreviations like `tmux a` / `tmux send`, so verb-listing is bypassable).
# tmux listing for the bridge is provided by the fixed bin/pc-status wrapper.
TMUX_ANY = re.compile(r"\btmux\b", re.IGNORECASE)

# Write-capable shell constructs INCLUDING interpreter-mediated writes
# (python -c open(...,'w'), perl -pi, ruby/node one-liners, osascript, awk).
# Enforcement paths may be EXECUTED via Bash (the allowlisted bin/ wrappers)
# but never written to — and never touched via an interpreter at all.
WRITEISH = re.compile(
    r"(>>?|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bchown\b|\bln\b|"
    r"\bsed\b[^\n]*-i|\binstall\b|\btruncate\b|\bdd\b|\bxattr\b|"
    r"\bpython[0-9.]*\b|\bperl\b|\bruby\b|\bnode\b|\bosascript\b|\bawk\b|"
    r"open\s*\()",
    re.IGNORECASE,
)


def deny(reason: str):
    print(f"bridge-guard: blocked ({reason})", file=sys.stderr)
    sys.exit(2)


if tool in ("Write", "Edit", "NotebookEdit"):
    path = str(tool_input.get("file_path") or tool_input.get("notebook_path") or "")
    if not path:
        deny("write tool without file_path")
    npath = norm(path)
    if SENSITIVE.search(path) or SENSITIVE.search(npath):
        deny(f"sensitive path: {path}")
    if ENFORCEMENT.search(path) or ENFORCEMENT.search(npath):
        deny(f"enforcement file: {path}")
    sys.exit(0)

if tool == "Read":
    path = str(tool_input.get("file_path") or "")
    npath = norm(path)
    if SENSITIVE.search(path) or SENSITIVE.search(npath):
        deny(f"sensitive path: {path}")
    sys.exit(0)

if tool == "Bash":
    cmd = str(tool_input.get("command") or "")
    if SENSITIVE.search(cmd):
        deny("command references a sensitive path")
    if EGRESS.search(cmd):
        deny("network egress binary is forbidden "
             "(bypass mode has no ask layer; use WebFetch/WebSearch)")
    if JSONL_SHELL_WRITE.search(cmd):
        deny("shell writes to .jsonl are forbidden "
             "(v2.5 corruption incident) — use the Write/Edit tool")
    if ENFORCEMENT.search(cmd) and WRITEISH.search(cmd):
        deny("command could modify an enforcement file")
    if TMUX_ANY.search(cmd):
        deny("direct tmux is forbidden (use bin/pc-status for listings)")
    sys.exit(0)

if tool in ("Grep", "Glob"):
    target = " ".join(
        str(tool_input.get(k) or "") for k in ("path", "pattern", "glob")
    )
    ntarget = " ".join(
        norm(str(tool_input.get(k) or "")) for k in ("path", "pattern", "glob")
    )
    if SENSITIVE.search(target) or SENSITIVE.search(ntarget):
        deny("search targets a sensitive path")
    sys.exit(0)

# Unknown matched tool: exit 0 (auto-runs under bypass mode; the deny rules in
# settings still apply). This guard only hard-denies the surfaces above.
sys.exit(0)
