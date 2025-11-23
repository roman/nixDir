#!/usr/bin/env bash
# Integration test runner for nixDir
# Runs bash-based integration tests against the example project

set -euo pipefail

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Running nixDir integration tests..."
echo ""

exec "$PROJECT_ROOT/tests/integration.sh" "$@"
