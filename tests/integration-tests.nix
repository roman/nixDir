{ ... }:
let
  examplePath = ../example/myproj;
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
      actual = builtins.pathExists "${examplePath}/nix/packages";
    }

    {
      name = "example has devShells directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/devShells";
    }

    {
      name = "example has configurations directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/configurations";
    }
  ];
}
