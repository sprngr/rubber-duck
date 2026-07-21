#!/usr/bin/env bash
# Automated validation test runner for Rubber Duck behavior regression checks
#
# Usage: bash scripts/run-validation-tests.sh [--filter=V01,V02] [--severity=Critical]
#
# Prerequisites:
# - Rubber Duck agent must be installed and available
# - Set HARNESS env var to target harness (default: opencode)
#
# Exit codes:
# 0 - all tests passed
# 1 - one or more tests failed
# 2 - error running tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_FILE="$REPO_ROOT/docs/validation/test-prompts.json"
RESULTS_DIR="${RESULTS_DIR:-/tmp/rubber-duck-validation}"

# Default harness
HARNESS="${HARNESS:-opencode}"

# Parse arguments
FILTER=""
SEVERITY_FILTER=""
INTERACTIVE="${INTERACTIVE:-false}"

for arg in "$@"; do
  case $arg in
    --filter=*)
      FILTER="${arg#*=}"
      shift
      ;;
    --severity=*)
      SEVERITY_FILTER="${arg#*=}"
      shift
      ;;
    --interactive)
      INTERACTIVE="true"
      shift
      ;;
    --help)
      echo "Usage: bash scripts/run-validation-tests.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --filter=V01,V02       Run only specified test IDs"
      echo "  --severity=Critical    Run only tests with specified severity"
      echo "  --interactive          Prompt to continue after each test"
      echo "  --help                 Show this help"
      echo ""
      echo "Environment variables:"
      echo "  HARNESS                Target harness (default: opencode)"
      echo "  RESULTS_DIR            Output directory (default: /tmp/rubber-duck-validation)"
      exit 0
      ;;
  esac
done

# Check prerequisites
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed"
  exit 2
fi

if [ ! -f "$TEST_FILE" ]; then
  echo "Error: Test file not found: $TEST_FILE"
  exit 2
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Parse test file
TOTAL_TESTS=$(jq '.tests | length' "$TEST_FILE")
echo "Rubber Duck Validation Test Runner"
echo "==================================="
echo "Harness: $HARNESS"
echo "Total tests: $TOTAL_TESTS"
if [ -n "$FILTER" ]; then
  echo "Filter: $FILTER"
fi
if [ -n "$SEVERITY_FILTER" ]; then
  echo "Severity filter: $SEVERITY_FILTER"
fi
echo ""

PASSED=0
FAILED=0
SKIPPED=0

# Iterate through tests
for i in $(seq 0 $((TOTAL_TESTS - 1))); do
  TEST_ID=$(jq -r ".tests[$i].id" "$TEST_FILE")
  TEST_AREA=$(jq -r ".tests[$i].area" "$TEST_FILE")
  TEST_PROMPT=$(jq -r ".tests[$i].prompt" "$TEST_FILE")
  EXPECTED_SIGNALS=$(jq -r ".tests[$i].expected_signals[]" "$TEST_FILE")
  SEVERITY=$(jq -r ".tests[$i].severity" "$TEST_FILE")
  NOTES=$(jq -r ".tests[$i].notes" "$TEST_FILE")
  
  # Apply filters
  if [ -n "$FILTER" ]; then
    if ! echo "$FILTER" | tr ',' '\n' | grep -q "^${TEST_ID}$"; then
      ((SKIPPED++))
      continue
    fi
  fi
  
  if [ -n "$SEVERITY_FILTER" ]; then
    if [ "$SEVERITY" != "$SEVERITY_FILTER" ]; then
      ((SKIPPED++))
      continue
    fi
  fi
  
  echo "[$TEST_ID] $TEST_AREA ($SEVERITY)"
  echo "Prompt: ${TEST_PROMPT:0:80}..."
  echo "Expected signals: $EXPECTED_SIGNALS"
  
  # NOTE: Actual test execution would require harness-specific integration
  # For now, this is a skeleton that documents the structure
  echo "⚠️  Test execution not implemented (requires harness integration)"
  echo "   To run manually: invoke rubber-duck agent with prompt and check for signals"
  echo ""
  
  ((SKIPPED++))
  
  if [ "$INTERACTIVE" = "true" ]; then
    read -p "Press enter to continue..."
  fi
done

echo ""
echo "Results"
echo "======="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"
echo ""

if [ $FAILED -gt 0 ]; then
  echo "❌ Some tests failed"
  exit 1
elif [ $PASSED -eq 0 ]; then
  echo "⚠️  No tests executed (implementation pending)"
  exit 0
else
  echo "✅ All tests passed"
  exit 0
fi
