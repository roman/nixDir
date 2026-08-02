{
  pkgs,
  lib,
  inputs,
}:
let
  # Evaluate the flake module far enough to get a real `overlays.flake` out of
  # it. Reconstructing the overlay expression here would test a copy, and a copy
  # cannot regress when default.nix does.
  evalOverlay =
    packages:
    let
      evaluated = lib.evalModules {
        modules = [
          {
            options = {
              flake = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified;
                default = { };
              };
              perSystem = lib.mkOption {
                type = lib.types.unspecified;
                default = { };
              };
            };
          }
          (import ../../default.nix null)
          {
            nixDir = {
              enable = true;
              root = ./.;
              generateFlakeOverlay = true;
            };
          }
        ];
        specialArgs = {
          inherit lib;
          inputs = inputs // {
            self = {
              inherit packages;
            };
          };
        };
      };
    in
    evaluated.config.flake.overlays.flake;

  nativeSystem = pkgs.stdenv.hostPlatform.system;

  overlayWithNative = evalOverlay {
    ${nativeSystem} = {
      flake-package = "sentinel";
    };
  };
  overlayWithoutNative = evalOverlay { some-other-system = { }; };

  # nixpkgs applies an overlay to every cross package set it spawns, so the
  # overlay is asked for packages under a host platform the flake never builds
  # for. Firefox reaches one this way through `pkgsCross.wasi32`.
  crossPkgs = pkgs.pkgsCross.wasi32;
in
{
  tests = [
    {
      name = "overlay contributes flake packages on the native system";
      type = "unit";
      expected = "sentinel";
      actual = (overlayWithNative pkgs pkgs).flake-package;
    }

    {
      name = "overlay is empty for a cross host the flake has no packages for";
      type = "unit";
      expected = { };
      actual = overlayWithNative crossPkgs crossPkgs;
    }

    {
      name = "cross package set stays evaluable through the overlay";
      type = "unit";
      expected = true;
      actual = builtins.isString (crossPkgs.extend overlayWithNative).stdenv.hostPlatform.system;
    }

    {
      name = "overlay is empty when the flake has no packages for the native system";
      type = "unit";
      expected = { };
      actual = overlayWithoutNative pkgs pkgs;
    }
  ];
}
