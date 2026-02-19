{ ... }:
let
  examplePath = ../example/myproj;
  inherit (import ../src/constants.nix) dirNames;
in
{
  tests = [
    {
      name = "example project flake.nix exists";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/flake.nix";
    }

    {
      name = "example has packages directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/${dirNames.packages}";
    }

    {
      name = "example has devShells directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/${dirNames.devShells}";
    }

    {
      name = "example has configurations directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/configurations";
    }
  ];
}
