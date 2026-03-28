#!/usr/bin/env bash
# bochi Data Layer Integrity Tests — runs on Lightsail via SSH
# Usage: ssh ubuntu@54.249.49.69 'bash -s' < tests/data-integrity.sh
# Validates: index.jsonl schema, user-profile.yaml, seen.jsonl, cross-references

set -uo pipefail

BOCHI_DATA="$HOME/.claude/bochi-data"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== bochi Data Integrity Tests ==="
echo ""

# --- 1. index.jsonl schema validation ---
echo "[1/5] index.jsonl schema"
if [ -f "$BOCHI_DATA/index.jsonl" ] && [ -s "$BOCHI_DATA/index.jsonl" ]; then
  result=$(python3 -c "
import json, sys
required_keys = {'id', 'type', 'title', 'date', 'category', 'freshness', 'path'}
valid_types = {'topic', 'memo', 'newspaper'}
valid_freshness = {'active', 'warm', 'archive'}
errors = []
count = 0
for i, line in enumerate(open('$BOCHI_DATA/index.jsonl'), 1):
    line = line.strip()
    if not line:
        continue
    count += 1
    try:
        entry = json.loads(line)
    except json.JSONDecodeError:
        errors.append(f'Line {i}: invalid JSON')
        continue
    missing = required_keys - set(entry.keys())
    if missing:
        errors.append(f'Line {i}: missing keys {missing}')
    if entry.get('type') not in valid_types:
        errors.append(f'Line {i}: invalid type \"{entry.get(\"type\")}\"')
    if entry.get('freshness') not in valid_freshness:
        errors.append(f'Line {i}: invalid freshness \"{entry.get(\"freshness\")}\"')
for e in errors:
    print(f'  ERROR: {e}', file=sys.stderr)
print(f'{count},{len(errors)}')
" 2>&1)
  count=$(echo "$result" | tail -1 | cut -d, -f1)
  err_count=$(echo "$result" | tail -1 | cut -d, -f2)
  if [ "$err_count" = "0" ]; then
    pass "index.jsonl: $count entries, all valid schema"
  else
    fail "index.jsonl: $err_count schema errors in $count entries"
    echo "$result" | head -10
  fi
else
  pass "index.jsonl empty or missing (first run)"
fi
echo ""

# --- 2. Cross-reference: index paths exist ---
echo "[2/5] Index cross-references"
if [ -f "$BOCHI_DATA/index.jsonl" ] && [ -s "$BOCHI_DATA/index.jsonl" ]; then
  orphans=$(python3 -c "
import json, os
bd = '$BOCHI_DATA'
orphans = 0
for line in open(f'{bd}/index.jsonl'):
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
        path = entry.get('path', '')
        full_path = os.path.join(bd, path)
        if not os.path.exists(full_path):
            orphans += 1
            print(f'  Orphan: {path}')
    except:
        pass
print(orphans)
" 2>&1)
  orphan_count=$(echo "$orphans" | tail -1)
  if [ "$orphan_count" = "0" ]; then
    pass "All index paths resolve to existing files"
  else
    fail "$orphan_count orphaned index entries"
    echo "$orphans" | head -5
  fi
else
  pass "index.jsonl empty (no cross-refs to check)"
fi
echo ""

# --- 3. user-profile.yaml validity ---
echo "[3/5] user-profile.yaml"
if [ -f "$BOCHI_DATA/user-profile.yaml" ]; then
  if python3 -c "
import yaml, sys
with open('$BOCHI_DATA/user-profile.yaml') as f:
    data = yaml.safe_load(f)
if not isinstance(data, dict):
    sys.exit(1)
if 'interests' not in data:
    print('WARN: no interests key')
" 2>/dev/null; then
    pass "user-profile.yaml valid YAML with structure"
  else
    fail "user-profile.yaml invalid or malformed"
  fi
else
  fail "user-profile.yaml missing"
fi
echo ""

# --- 4. seen.jsonl dedup check ---
echo "[4/5] seen.jsonl deduplication"
if [ -f "$BOCHI_DATA/seen.jsonl" ] && [ -s "$BOCHI_DATA/seen.jsonl" ]; then
  dup_check=$(python3 -c "
import json
urls = []
for line in open('$BOCHI_DATA/seen.jsonl'):
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
        url = entry.get('url', '')
        if url:
            urls.append(url)
    except:
        pass
dupes = len(urls) - len(set(urls))
print(f'{len(urls)},{dupes}')
" 2>/dev/null)
  total=$(echo "$dup_check" | cut -d, -f1)
  dupes=$(echo "$dup_check" | cut -d, -f2)
  if [ "$dupes" = "0" ]; then
    pass "seen.jsonl: $total URLs, 0 duplicates"
  else
    fail "seen.jsonl: $dupes duplicate URLs in $total entries"
  fi
else
  pass "seen.jsonl empty (no dedup to check)"
fi
echo ""

# --- 5. Freshness layer consistency ---
echo "[5/5] Freshness consistency"
if [ -f "$BOCHI_DATA/index.jsonl" ] && [ -s "$BOCHI_DATA/index.jsonl" ]; then
  python3 -c "
import json
from datetime import datetime, timedelta
now = datetime.now()
issues = 0
for line in open('$BOCHI_DATA/index.jsonl'):
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
        date_str = entry.get('date', '')
        freshness = entry.get('freshness', '')
        entry_date = datetime.strptime(date_str, '%Y-%m-%d')
        age_days = (now - entry_date).days
        if freshness == 'active' and age_days > 180:
            issues += 1
            print(f'  WARN: {entry[\"id\"]} is active but {age_days}d old')
        elif freshness == 'archive' and age_days < 90:
            issues += 1
            print(f'  WARN: {entry[\"id\"]} archived but only {age_days}d old')
    except:
        pass
print(f'ISSUES:{issues}')
" 2>/dev/null
  pass "Freshness layer checked"
else
  pass "No entries to check freshness"
fi
echo ""

echo "================================="
echo "Results: $PASS passed, $FAIL failed"
echo "================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
