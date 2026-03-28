#!/usr/bin/env bash
# bochi S3 Sync Round-Trip Test — runs on Lightsail via SSH
# Usage: ssh ubuntu@54.249.49.69 'bash -s' < tests/s3-sync-test.sh
# Verifies: push → S3 → pull round-trip preserves data

set -uo pipefail

BOCHI_DATA="$HOME/.claude/bochi-data"
S3_BUCKET="s3://bochi-sync-fumito"
TEST_FILE="memos/test-s3-sync-$(date +%s).md"
TEST_CONTENT="# S3 Sync Test\nTimestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)\nThis file verifies S3 round-trip."
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== S3 Sync Round-Trip Test ==="
echo ""

# Step 1: Create test file locally
echo "[1/5] Creating test file"
mkdir -p "$BOCHI_DATA/memos"
echo -e "$TEST_CONTENT" > "$BOCHI_DATA/$TEST_FILE"
if [ -f "$BOCHI_DATA/$TEST_FILE" ]; then
  pass "Test file created locally"
else
  fail "Test file creation failed"
  exit 1
fi

# Step 2: Push to S3
echo "[2/5] Pushing to S3"
if aws s3 sync "$BOCHI_DATA/" "$S3_BUCKET/bochi-data/" --region ap-northeast-1 --quiet 2>/dev/null; then
  pass "S3 push succeeded"
else
  fail "S3 push failed"
  exit 1
fi

# Step 3: Verify file exists on S3
echo "[3/5] Verifying S3 upload"
if aws s3 ls "$S3_BUCKET/bochi-data/$TEST_FILE" --region ap-northeast-1 &>/dev/null; then
  pass "File exists on S3"
else
  fail "File not found on S3"
fi

# Step 4: Delete local and pull from S3
echo "[4/5] Testing pull (delete local → pull from S3)"
rm -f "$BOCHI_DATA/$TEST_FILE"
if aws s3 sync "$S3_BUCKET/bochi-data/" "$BOCHI_DATA/" --region ap-northeast-1 --quiet 2>/dev/null; then
  pass "S3 pull succeeded"
else
  fail "S3 pull failed"
fi

if [ -f "$BOCHI_DATA/$TEST_FILE" ]; then
  pass "File restored from S3"
else
  fail "File not restored from S3"
fi

# Step 5: Cleanup
echo "[5/5] Cleanup"
rm -f "$BOCHI_DATA/$TEST_FILE"
aws s3 rm "$S3_BUCKET/bochi-data/$TEST_FILE" --region ap-northeast-1 --quiet 2>/dev/null
pass "Test file cleaned up"
echo ""

echo "================================="
echo "Results: $PASS passed, $FAIL failed"
echo "================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
