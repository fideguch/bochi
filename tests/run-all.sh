#!/usr/bin/env bash
# bochi Test Runner — executes all test suites
# Usage: ./tests/run-all.sh [--infra-only | --discord-only | --all]
#
# Test layers:
#   1. Static: Markdown lint + reference check (CI, no SSH needed)
#   2. Infrastructure: Directory/file/S3 checks (SSH to Lightsail)
#   3. Data integrity: JSONL/YAML validation (SSH to Lightsail)
#   4. S3 sync: Round-trip verification (SSH to Lightsail)
#   5. Discord E2E: Live bot interaction (requires running bot + secrets)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSH_KEY="${BOCHI_SSH_KEY:-$HOME/.ssh/lightsail-bochi.pem}"
HOST="${BOCHI_HOST:-54.249.49.69}"
MODE="${1:---all}"

TOTAL_PASS=0
TOTAL_FAIL=0
SUITE_RESULTS=()

run_remote_suite() {
  local name="$1" script="$2"
  echo ""
  echo "##############################"
  echo "# Suite: $name"
  echo "##############################"

  if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
       "ubuntu@$HOST" 'bash -s' < "$SCRIPT_DIR/$script"; then
    SUITE_RESULTS+=("PASS: $name")
  else
    SUITE_RESULTS+=("FAIL: $name")
    ((TOTAL_FAIL++))
  fi
  ((TOTAL_PASS++))
}

echo "=== bochi Test Runner ==="
echo "Mode: $MODE"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Static tests (always run) ---
echo ""
echo "##############################"
echo "# Suite: Static (Markdown + References)"
echo "##############################"

# Markdown lint
if command -v markdownlint-cli2 &>/dev/null; then
  if markdownlint-cli2 "$PROJECT_DIR/**/*.md" 2>/dev/null; then
    echo "  PASS: Markdown lint"
    SUITE_RESULTS+=("PASS: Markdown lint")
  else
    echo "  FAIL: Markdown lint"
    SUITE_RESULTS+=("FAIL: Markdown lint")
    ((TOTAL_FAIL++))
  fi
else
  echo "  SKIP: markdownlint-cli2 not installed"
  SUITE_RESULTS+=("SKIP: Markdown lint (tool missing)")
fi
((TOTAL_PASS++))

# Reference file existence
ref_missing=0
while IFS= read -r f; do
  if [ ! -f "$PROJECT_DIR/$f" ]; then
    echo "  MISSING: $f"
    ((ref_missing++))
  fi
done < <(grep -oP '`references/[^`]+`' "$PROJECT_DIR/SKILL.md" 2>/dev/null | tr -d '`')

if [ "$ref_missing" -eq 0 ]; then
  echo "  PASS: All referenced files exist"
  SUITE_RESULTS+=("PASS: Reference files")
else
  echo "  FAIL: $ref_missing reference files missing"
  SUITE_RESULTS+=("FAIL: Reference files ($ref_missing missing)")
  ((TOTAL_FAIL++))
fi
((TOTAL_PASS++))

# Scenario test count
test_count=$(grep -cE '\| [A-Z]{1,3}[0-9]?-[0-9]{2} \|' "$PROJECT_DIR/references/scenario-tests.md" 2>/dev/null || echo "0")
if [ "$test_count" -ge 49 ]; then
  echo "  PASS: $test_count scenario tests (>= 49)"
  SUITE_RESULTS+=("PASS: Scenario count ($test_count)")
else
  echo "  FAIL: Only $test_count scenario tests (need 49+)"
  SUITE_RESULTS+=("FAIL: Scenario count ($test_count < 49)")
  ((TOTAL_FAIL++))
fi
((TOTAL_PASS++))

# LICENSE check
if [ -f "$PROJECT_DIR/LICENSE" ]; then
  echo "  PASS: LICENSE file exists"
  SUITE_RESULTS+=("PASS: LICENSE")
else
  echo "  FAIL: LICENSE file missing"
  SUITE_RESULTS+=("FAIL: LICENSE missing")
  ((TOTAL_FAIL++))
fi
((TOTAL_PASS++))

# --- Infrastructure tests ---
if [ "$MODE" = "--all" ] || [ "$MODE" = "--infra-only" ]; then
  run_remote_suite "Infrastructure" "infra-check.sh"
  run_remote_suite "Data Integrity" "data-integrity.sh"
  run_remote_suite "S3 Sync" "s3-sync-test.sh"
fi

# --- Discord E2E tests ---
if [ "$MODE" = "--all" ] || [ "$MODE" = "--discord-only" ]; then
  if [ -n "${DISCORD_BOT_TOKEN:-}" ] && [ -n "${DISCORD_USER_ID:-}" ]; then
    echo ""
    echo "##############################"
    echo "# Suite: Discord E2E"
    echo "##############################"
    if bash "$SCRIPT_DIR/discord-e2e.sh"; then
      SUITE_RESULTS+=("PASS: Discord E2E")
    else
      SUITE_RESULTS+=("FAIL: Discord E2E")
      ((TOTAL_FAIL++))
    fi
    ((TOTAL_PASS++))
  else
    echo ""
    echo "  SKIP: Discord E2E (set DISCORD_BOT_TOKEN and DISCORD_USER_ID)"
    SUITE_RESULTS+=("SKIP: Discord E2E (no credentials)")
  fi
fi

# --- Final Summary ---
echo ""
echo "====================================="
echo "  TEST SUITE SUMMARY"
echo "====================================="
for result in "${SUITE_RESULTS[@]}"; do
  echo "  $result"
done
echo "====================================="
echo "  Total: ${#SUITE_RESULTS[@]} suites, $TOTAL_FAIL failures"
echo "====================================="

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
