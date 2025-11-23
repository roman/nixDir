{ pkgs, lib, inputs }:
let
  # Flake module with self argument applied
  flakeModule = import ../default.nix;

  # Mock module arguments to call the flake module
  mockModuleArgs = {
    inherit lib inputs;
    system = pkgs.system;
    config = {
      nixDir = {
        enable = false;
        root = ./.;
        dirName = "nix";
      };
    };
  };

  # Evaluated module result
  moduleResult = flakeModule null mockModuleArgs;
in
{
  tests = [
    {
      name = "flake module is a function";
      type = "unit";
      expected = true;
      actual = builtins.isFunction flakeModule;
    }

    {
      name = "flake module returns attrset";
      type = "unit";
      expected = true;
      actual = builtins.isAttrs moduleResult;
    }

    {
      name = "flake module has options";
      type = "unit";
      expected = true;
      actual = moduleResult ? options;
    }

    {
      name = "flake module has config";
      type = "unit";
      expected = true;
      actual = moduleResult ? config;
    }

    {
      name = "nixDir.enable option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? enable;
    }

    {
      name = "nixDir.root option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? root;
    }

    {
      name = "nixDir.dirName option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? dirName;
    }

    {
      name = "nixDir.generateAllPackage option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? generateAllPackage;
    }

    {
      name = "nixDir.installFlakeOverlay option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? installFlakeOverlay;
    }

    {
      name = "nixDir.generateFlakeOverlay option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? generateFlakeOverlay;
    }

    {
      name = "nixDir.nixpkgsConfig option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? nixpkgsConfig;
    }

    {
      name = "nixDir.installOverlays option exists";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? installOverlays;
    }
  ];
}
