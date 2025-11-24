#!/usr/bin/env bash
# Test runner script for nixDir
# Runs all test suites using nixtest

set -euo pipefail

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Running nixDir test suite..."
echo ""

nix run .#nixtests:run "$@"
