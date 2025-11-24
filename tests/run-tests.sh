#!/usr/bin/env bash
# Master test runner for nixDir
# Runs both unit tests (nixtest) and integration tests (bash)

set -euo pipefail

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_ROOT"

EXIT_CODE=0

echo "========================================"
echo "Running nixDir Test Suite"
echo "========================================"
echo ""

# Run unit tests
echo "Step 1/2: Running unit tests..."
echo ""
if ! "$PROJECT_ROOT/tests/run-unit-tests.sh" "$@"; then
  EXIT_CODE=1
  echo ""
  echo "⚠ Unit tests failed"
fi

echo ""
echo "========================================"
echo ""

# Run integration tests
echo "Step 2/2: Running integration tests..."
echo ""
if ! "$PROJECT_ROOT/tests/run-integration-tests.sh" "$@"; then
  EXIT_CODE=1
  echo ""
  echo "⚠ Integration tests failed"
fi

echo ""
echo "========================================"
echo "Test Suite Complete"
echo "========================================"

if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ Some tests failed"
  exit 1
else
  echo "✅ All tests passed"
  exit 0
fi
