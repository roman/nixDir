{ nixpkgs, ... } @ nixDirInputs: {
  inputs
, systems
, root
, dirName ? "nix"
, nixDir ? "${root}/${dirName}"
, pathExists ? builtins.pathExists
, ...
} @ buildFlakeCfg:

let
  inherit (nixpkgs) lib;

  importer = import ./importer.nix nixDirInputs buildFlakeCfg;
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;

  inherit (importer) importOverlays;
  inherit (utils) applyFlakeOutput;

  applyOverlays =
    applyFlakeOutput
      (pathExists "${nixDir}/overlays.nix")
      {
        overlays = importOverlays;
      };
in
{
  inherit applyOverlays;
}
