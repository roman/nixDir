#!/usr/bin/env bash

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    cd example/v2/myproj
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
}

get_lib() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); in builtins.attrNames flk.lib' --json 2> /dev/null | jq -cr 'sort'
}

@test "lib functions are defined" {
    run get_lib
    assert_output '["getPkgs","preCommitRunScript","sayHello"]'
}

get_package_archs() {
    nix flake show --json 2> /dev/null | jq -c '.packages | keys | sort'
}

@test "packages are defined for each architecture" {
    run get_package_archs
    assert_output '["aarch64-darwin","x86_64-darwin","x86_64-linux"]'
}

get_package_name() {
    nix flake show --json 2> /dev/null | jq -c '.packages."x86_64-linux" | keys | sort'
}

@test "packages from multiple sources are defined" {
    run get_package_name
    # all is generated via the generateAllPackage option
    # flkPkg is defined in the packages entry
    # hello is defined in the ./nix/packages directory
    assert_output '["all","flkPkg","hello"]'
}

get_devshells() {
    nix flake show --json 2> /dev/null | jq -c '.devShells."x86_64-linux" | keys | sort'
}

@test "regular shell and devenv shell are defined" {
    run get_devshells
    assert_output '["default","devenv","other","other-devenv"]'
}

get_devenv_devshell() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); in flk.devShells.x86_64-linux.devenv.config.devenv.flakesIntegration'
}

@test "devenv shell is a devenv.nix shell" {
    run get_devenv_devshell
    assert_output 'true'
}

get_overlays() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); in builtins.attrNames flk.overlays' --json | jq -cr 'sort'
}

@test "overlays are defined" {
    run get_overlays
    assert_output '["default"]'
}

check_overlayed_was_applied() {
    # cd example/myproj
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); pkgs = flk.lib.getPkgs builtins.currentSystem; in builtins.hasAttr "my-hello" pkgs' --json
}

@test "specified overlay gets applied to project's nixpkgs" {
    run check_overlayed_was_applied
    assert_output 'true'
}

check_devenv_module_was_applied() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); config = flk.devShells.x86_64-linux.devenv.config.services; in builtins.hasAttr "my-hello" config' --json

}

@test "specified devenv module gets applied to devenv shells" {
    run check_devenv_module_was_applied
    assert_output 'true'
}

check_pre_commit_hook_on_vanilla_devshell() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); in flk.devShells.x86_64-linux.default.nixDirPreCommitInjected' --json
}

@test "pre-commit-hook gets injected on vanilla devShells" {
    run check_pre_commit_hook_on_vanilla_devshell
    assert_output 'true'
}

check_pre_commit_hook_on_devenv_devshell() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); in flk.devShells.x86_64-linux.devenv.nixDirPreCommitInjected' --json
}

@test "pre-commit-hook gets injected on devenev devShells" {
    run check_pre_commit_hook_on_devenv_devshell
    assert_output 'true'
}

check_no_pre_commit_hook_on_vanilla_devshell() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); in flk.devShells.x86_64-linux.other.nixDirPreCommitInjected' --json
}

@test "pre-commit-hook doesn't get injected on unspecified vanilla devShell" {
    run check_no_pre_commit_hook_on_vanilla_devshell
    assert_output 'false'
}

check_no_pre_commit_hook_on_devenv_devshell() {
    nix eval --impure --expr 'let flk = builtins.getFlake (builtins.toString ./.); in flk.devShells.x86_64-linux.devenv-other.nixDirPreCommitInjected' --json
}

@test "pre-commit-hook doesn't get injected on unspecified devenv" {
    run check_no_pre_commit_hook_on_vanilla_devshell
    assert_output 'false'
}
