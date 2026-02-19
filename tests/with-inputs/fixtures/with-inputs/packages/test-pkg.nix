inputs:
{ pkgs, ... }:
# Example package that receives flake inputs
# This demonstrates using inputs to access packages from other flakes

pkgs.writeText "test-with-inputs" ''
  This package was built with inputs support.
  Input count: ${toString (builtins.length (builtins.attrNames inputs))}
''
