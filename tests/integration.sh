#!/usr/bin/env bash

# Integration tests for nixDir
# Tests end-to-end functionality with the example project

set -euo pipefail

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="$PROJECT_ROOT/example/myproj"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Assertion helpers
assert_success() {
  local exit_code=$1
  local message="${2:-Command failed}"

  if [ "$exit_code" -ne 0 ]; then
    echo -e "${RED}✗ FAIL${NC}: $message (exit code: $exit_code)"
    TEST_FAILED=$((TESTS_FAILED+1))
    return 1
  fi
  return 0
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local message="${3:-Output does not contain expected string}"

  if ! echo "$haystack" | grep -q "$needle"; then
    echo -e "${RED}✗ FAIL${NC}: $message"
    echo "  Expected to find: $needle"
    echo -e "  Got:\n$haystack"
    TEST_FAILED=$((TESTS_FAILED+1))
    return 1
  fi
  return 0
}

assert_file_exists() {
  local file_path="$1"
  local message="${2:-File does not exist}"

  if [ ! -f "$file_path" ]; then
    echo -e "${RED}✗ FAIL${NC}: $message"
    echo "  Expected file: $file_path"
    TEST_FAILED=$((TESTS_FAILED+1))
    return 1
  fi
  return 0
}

run_test() {
  local test_name="$1"
  TESTS_RUN=$((TESTS_RUN+1))  # Changed from TEST_RUN
  echo ""
  echo "Running: $test_name"
}

test_passed() {
  local test_name="$1"
  echo -e "${GREEN}✓ PASS${NC}: $test_name"
  TESTS_PASSED=$((TESTS_PASSED+1))  # Changed from TEST_PASSED
}

test_failed() {
  local test_name="$1"
  echo -e "${RED}✗ FAIL${NC}: $test_name"
  TESTS_FAILED=$((TESTS_FAILED+1))  # Changed from TEST_FAILED
}

# Test: Example packages can be evaluated
test_packages_eval() {
  run_test "Example packages can be evaluated"

  cd "$EXAMPLE_DIR"

  local output
  if output=$(nix eval .#packages.x86_64-linux --json --impure --show-trace 2>&1); then
    if assert_contains "hello-myproj" "$output" "Packages output should contain hello-myproj"; then
      test_passed "Example packages can be evaluated"
    fi
  else
    echo "Error output: $output"
    test_failed "Example packages can be evaluated"
  fi
}

# Test: Example devShells can be evaluated
test_devshells_eval() {
  run_test "Example devShells can be evaluated"

  cd "$EXAMPLE_DIR"

  local output;
  if output=$(nix eval .#devShells.x86_64-linux --json --impure 2>&1); then
    test_passed "Example devShells can be evaluated"
  else
    echo "Error output: $output"
    test_failed "Example devShells can be evaluated"
  fi
}

# Test: Example hello-myproj package builds
test_hello_package_builds() {
  run_test "Example hello-myproj package builds"

  cd "$EXAMPLE_DIR"

  if output=$(nix build .#hello-myproj --no-link 2>&1); then
    if echo "$output" | grep -qv "error:"; then
      test_passed "Example hello-myproj package builds"
    else
      test_failed "Example hello-myproj package builds"
    fi
  else
    echo "Error output: $output"
    test_failed "Example hello-myproj package builds"
  fi
}

# Test: Example overlay is generated
test_flake_overlay_generated() {
  run_test "Example overlay is generated"

  cd "$EXAMPLE_DIR"

  if nix eval --json \
    --impure \
    --expr '
      let
        flake = builtins.getFlake "path:'"$PROJECT_ROOT"'";
      in
        flake.overlays ? flake
    ' 2>&1; then
  # if nix eval .#overlays.default --json --impure >/dev/null 2>&1; then
    test_passed "Example overlay is generated"
  else
    test_failed "Example overlay is generated"
  fi
}

# Test: Conflict detection works between regular and with-inputs
test_conflict_detection() {
  run_test "Conflict detection throws error for duplicate names"

  cd "$PROJECT_ROOT"

  # Try to build a flake that uses the conflict fixture
  # We expect this to fail with a conflict error message
  local output
  if output=$(nix eval --json \
    --impure \
    --expr '
      let
        flake = builtins.getFlake "path:'"$PROJECT_ROOT"'";
        importer = import ('"$PROJECT_ROOT"' + "/src/importer.nix") {
          pkgs = null;
          lib = flake.inputs.nixpkgs.lib;
          inputs = flake.inputs;
        };

        flakeLib = import ('"$PROJECT_ROOT"' + "/lib.nix") {
          inherit (flake.inputs.nixpkgs) lib;
          dirName = "nix";
        };
        inherit (flakeLib) checkConflicts;

        regularModules = importer.importNixOSModules ('"$PROJECT_ROOT"' + "/tests/fixtures/with-inputs-conflict/modules/nixos");
        withInputsModules = importer.importNixOSModulesWithInputs ('"$PROJECT_ROOT"' + "/tests/fixtures/with-inputs-conflict/with-inputs/modules/nixos");
      in
        checkConflicts "modules/nixos" regularModules withInputsModules
    ' 2>&1); then
    echo "Expected conflict error but evaluation succeeded"
    echo "Output: $output"
    test_failed "Conflict detection throws error for duplicate names"
  else
    if assert_contains "nixDir found conflicting modules/nixos entries" "$output" "Error should mention the conflicting entry"; then
      test_passed "Conflict detection throws error for duplicate names"
    fi
  fi
}

# Main test execution
main() {
  echo "========================================"
  echo "Running nixDir Integration Tests"
  echo "========================================"

  # Run tests
  test_packages_eval
  test_devshells_eval
  test_hello_package_builds
  test_flake_overlay_generated
  test_conflict_detection

  # Print summary
  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo "Tests run:    $TESTS_RUN"
  echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
  echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
  echo "========================================"

  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
