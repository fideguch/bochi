#!/usr/bin/env bash
# bochi Infrastructure Verification — runs on Lightsail via SSH
# Usage: ssh ubuntu@54.249.49.69 'bash -s' < tests/infra-check.sh
# Exit code: 0 = all pass, 1 = failures found

set -uo pipefail

BOCHI_DATA_REAL="$HOME/bochi-data"
BOCHI_DATA_LINK="$HOME/.claude/bochi-data"
BOCHI_DATA="$BOCHI_DATA_REAL"
BOCHI_SKILL="$HOME/bochi-skill"
PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

echo "=== bochi Infrastructure Check ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- 0. Symlink health ---
echo "[0/8] Symlink health"
if [ -L "$BOCHI_DATA_LINK" ] && [ "$(readlink "$BOCHI_DATA_LINK")" = "$BOCHI_DATA_REAL" ]; then
  pass "bochi-data symlink → ~/bochi-data/ (outside .claude/ protection)"
elif [ -L "$BOCHI_DATA_LINK" ]; then
  warn "bochi-data symlink points to $(readlink "$BOCHI_DATA_LINK") (expected $BOCHI_DATA_REAL)"
elif [ -d "$BOCHI_DATA_LINK" ]; then
  fail "bochi-data is a real directory (should be symlink to ~/bochi-data/)"
else
  fail "bochi-data symlink missing"
fi
echo ""

# --- 1. Core directories ---
echo "[1/8] Core directories"
for dir in "$BOCHI_DATA" "$BOCHI_DATA/topics" "$BOCHI_DATA/memos" \
           "$BOCHI_DATA/newspaper" "$BOCHI_DATA/reflections" \
           "$BOCHI_DATA/cache" "$BOCHI_DATA/cache/trending" \
           "$BOCHI_DATA/archive" "$BOCHI_DATA/stats" \
           "$BOCHI_DATA/sources" "$BOCHI_DATA/errors"; do
  if [ -d "$dir" ]; then
    pass "$dir exists"
  else
    fail "$dir missing"
  fi
done
echo ""

# --- 2. Core files ---
echo "[2/8] Core data files"
for file in "$BOCHI_DATA/index.jsonl" "$BOCHI_DATA/user-profile.yaml" \
            "$BOCHI_DATA/seen.jsonl" "$BOCHI_DATA/cache/meta.json"; do
  if [ -f "$file" ]; then
    pass "$file exists"
  else
    fail "$file missing"
  fi
done
echo ""

# --- 3. JSONL integrity ---
echo "[3/8] JSONL integrity"
for jsonl_file in "$BOCHI_DATA/index.jsonl" "$BOCHI_DATA/seen.jsonl"; do
  if [ -f "$jsonl_file" ] && [ -s "$jsonl_file" ]; then
    invalid=$(python3 -c "
import json, sys
bad = 0
for i, line in enumerate(open('$jsonl_file'), 1):
    line = line.strip()
    if not line:
        continue
    try:
        json.loads(line)
    except json.JSONDecodeError:
        bad += 1
        print(f'  Invalid JSON at line {i}', file=sys.stderr)
print(bad)
" 2>&1)
    if echo "$invalid" | tail -1 | grep -q '^0$'; then
      pass "$jsonl_file valid JSON"
    else
      fail "$jsonl_file has invalid JSON lines"
    fi
  elif [ -f "$jsonl_file" ]; then
    pass "$jsonl_file exists (empty)"
  else
    fail "$jsonl_file missing"
  fi
done

if [ -f "$BOCHI_DATA/cache/meta.json" ] && [ -s "$BOCHI_DATA/cache/meta.json" ]; then
  if python3 -c "import json; json.load(open('$BOCHI_DATA/cache/meta.json'))" 2>/dev/null; then
    pass "cache/meta.json valid JSON"
  else
    fail "cache/meta.json invalid JSON"
  fi
fi
echo ""

# --- 4. S3 connectivity ---
echo "[4/8] S3 connectivity"
if command -v aws &>/dev/null; then
  pass "AWS CLI installed"
  if aws s3 ls s3://bochi-sync-fumito/ --region ap-northeast-1 &>/dev/null; then
    pass "S3 bucket accessible"
  else
    fail "S3 bucket not accessible"
  fi
else
  fail "AWS CLI not installed"
fi

for script in "$HOME/.claude/scripts/hooks/bochi-s3-pull.sh" \
              "$HOME/.claude/scripts/hooks/bochi-s3-push.sh"; do
  if [ -x "$script" ]; then
    pass "$script executable"
  elif [ -f "$script" ]; then
    warn "$script exists but not executable"
  else
    fail "$script missing"
  fi
done
echo ""

# --- 5. Skill definition ---
echo "[5/8] Skill definition"
if [ -L "$HOME/.claude/skills/bochi" ] && [ -d "$HOME/.claude/skills/bochi" ]; then
  pass "Skill symlink valid"
else
  fail "Skill symlink broken or missing"
fi

if [ -f "$BOCHI_SKILL/SKILL.md" ]; then
  pass "SKILL.md exists"
else
  fail "SKILL.md missing"
fi

if [ -f "$BOCHI_SKILL/.claude/settings.local.json" ]; then
  pass "settings.local.json exists"
else
  fail "settings.local.json missing (SCP required)"
fi
echo ""

# --- 6. Runtime dependencies ---
echo "[6/8] Runtime dependencies"
if command -v bun &>/dev/null; then
  pass "bun available ($(bun --version 2>/dev/null))"
else
  fail "bun not in PATH"
fi

if command -v claude &>/dev/null; then
  pass "claude available"
else
  fail "claude not in PATH"
fi

if command -v node &>/dev/null; then
  pass "node available ($(node --version 2>/dev/null))"
else
  warn "node not in PATH"
fi
echo ""

# --- 7. Discord config ---
echo "[7/8] Discord configuration"
if [ -f "$HOME/.claude/channels/discord/.env" ]; then
  pass "Discord .env exists"
else
  fail "Discord .env missing"
fi

if [ -f "$HOME/.claude/channels/discord/access.json" ]; then
  pass "Discord access.json exists"
else
  fail "Discord access.json missing"
fi
echo ""

# --- Summary ---
echo "================================="
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
