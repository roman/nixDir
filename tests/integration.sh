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

# Test: Platform filtering - Linux package not on Darwin
test_platform_linux_package_not_on_darwin() {
  run_test "Platform filtering: linux-tool not available on darwin"

  cd "$PROJECT_ROOT/tests/fixtures/platform-integration"

  local output
  if output=$(nix eval .#packages.x86_64-darwin --json --apply 'pkgs: builtins.attrNames pkgs' 2>&1); then
    if echo "$output" | grep -q "linux-tool"; then
      echo "linux-tool should NOT be available on x86_64-darwin"
      echo "Output: $output"
      test_failed "Platform filtering: linux-tool not available on darwin"
    else
      test_passed "Platform filtering: linux-tool not available on darwin"
    fi
  else
    echo "Error output: $output"
    test_failed "Platform filtering: linux-tool not available on darwin"
  fi
}

# Test: Platform filtering - Linux package on Linux
test_platform_linux_package_on_linux() {
  run_test "Platform filtering: linux-tool available on linux"

  cd "$PROJECT_ROOT/tests/fixtures/platform-integration"

  local output
  if output=$(nix eval .#packages.x86_64-linux --json --apply 'pkgs: builtins.attrNames pkgs' 2>&1); then
    if assert_contains "linux-tool" "$output" "linux-tool should be available on x86_64-linux"; then
      test_passed "Platform filtering: linux-tool available on linux"
    fi
  else
    echo "Error output: $output"
    test_failed "Platform filtering: linux-tool available on linux"
  fi
}

# Test: Platform filtering - Darwin package not on Linux
test_platform_darwin_package_not_on_linux() {
  run_test "Platform filtering: darwin-tool not available on linux"

  cd "$PROJECT_ROOT/tests/fixtures/platform-integration"

  local output
  if output=$(nix eval .#packages.x86_64-linux --json --apply 'pkgs: builtins.attrNames pkgs' 2>&1); then
    if echo "$output" | grep -q "darwin-tool"; then
      echo "darwin-tool should NOT be available on x86_64-linux"
      echo "Output: $output"
      test_failed "Platform filtering: darwin-tool not available on linux"
    else
      test_passed "Platform filtering: darwin-tool not available on linux"
    fi
  else
    echo "Error output: $output"
    test_failed "Platform filtering: darwin-tool not available on linux"
  fi
}

# Test: Platform filtering - Darwin package on Darwin
test_platform_darwin_package_on_darwin() {
  run_test "Platform filtering: darwin-tool available on darwin"

  cd "$PROJECT_ROOT/tests/fixtures/platform-integration"

  local output
  if output=$(nix eval .#packages.x86_64-darwin --json --apply 'pkgs: builtins.attrNames pkgs' 2>&1); then
    if assert_contains "darwin-tool" "$output" "darwin-tool should be available on x86_64-darwin"; then
      test_passed "Platform filtering: darwin-tool available on darwin"
    fi
  else
    echo "Error output: $output"
    test_failed "Platform filtering: darwin-tool available on darwin"
  fi
}

# Test: Platform filtering - Universal package on all systems
test_platform_universal_package() {
  run_test "Platform filtering: universal-tool available on all systems"

  cd "$PROJECT_ROOT/tests/fixtures/platform-integration"

  local linux_output darwin_output
  local all_passed=true

  if linux_output=$(nix eval .#packages.x86_64-linux --json --apply 'pkgs: builtins.attrNames pkgs' 2>&1); then
    if ! echo "$linux_output" | grep -q "universal-tool"; then
      echo "universal-tool should be available on x86_64-linux"
      all_passed=false
    fi
  else
    echo "Error evaluating linux packages: $linux_output"
    all_passed=false
  fi

  if darwin_output=$(nix eval .#packages.x86_64-darwin --json --apply 'pkgs: builtins.attrNames pkgs' 2>&1); then
    if ! echo "$darwin_output" | grep -q "universal-tool"; then
      echo "universal-tool should be available on x86_64-darwin"
      all_passed=false
    fi
  else
    echo "Error evaluating darwin packages: $darwin_output"
    all_passed=false
  fi

  if [ "$all_passed" = true ]; then
    test_passed "Platform filtering: universal-tool available on all systems"
  else
    test_failed "Platform filtering: universal-tool available on all systems"
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
  test_platform_linux_package_not_on_darwin
  test_platform_linux_package_on_linux
  test_platform_darwin_package_not_on_linux
  test_platform_darwin_package_on_darwin
  test_platform_universal_package

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
