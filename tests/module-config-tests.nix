{ pkgs, lib, inputs }:
let
  # Read the default.nix flake module to test its structure
  flakeModule = import ../default.nix;
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
      actual =
        let
          # Call with self argument
          result = flakeModule null;
        in
        builtins.isAttrs result;
    }

    {
      name = "flake module has options";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result ? options;
    }

    {
      name = "flake module has config";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result ? config;
    }

    {
      name = "nixDir.enable option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? enable;
    }

    {
      name = "nixDir.root option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? root;
    }

    {
      name = "nixDir.dirName option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? dirName;
    }

    {
      name = "nixDir.generateAllPackage option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? generateAllPackage;
    }

    {
      name = "nixDir.installFlakeOverlay option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? installFlakeOverlay;
    }

    {
      name = "nixDir.generateFlakeOverlay option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? generateFlakeOverlay;
    }

    {
      name = "nixDir.nixpkgsConfig option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? nixpkgsConfig;
    }

    {
      name = "nixDir.installOverlays option exists";
      type = "unit";
      expected = true;
      actual =
        let
          result = flakeModule null;
        in
        result.options ? nixDir && result.options.nixDir ? installOverlays;
    }
  ];
}
