{ nixpkgs, ... } @ nixDirInputs:

let
  buildFlake = cfg:
    let
      overlays = import ./src/overlays.nix nixDirInputs cfg;
      packages = import ./src/packages.nix nixDirInputs cfg;
      devshells = import ./src/devshells.nix nixDirInputs cfg;
      devenvs = import ./src/devenvs.nix nixDirInputs cfg;
      nixt = import ./src/nixt.nix nixDirInputs cfg;
      lib = import ./src/lib.nix nixDirInputs cfg;

      modules = [
        packages.applyPackages
        overlays.applyOverlays
        devshells.applyDevShells
        devenvs.applyDevenvShells
        devenvs.applyDevenvModules
        nixt.applyNixtTests
        lib.applyLib
      ];
    in
    builtins.foldl' (flk: applyModule: applyModule flk) { } modules;
in
{
  inherit buildFlake;
}