{ nixpkgs, ... } @ nixDirInputs:

let
  buildFlake = cfg:
    let
      overlays = import ./src/overlays.nix nixDirInputs cfg;
      packages = import ./src/packages.nix nixDirInputs cfg;
      devshells = import ./src/devshells.nix nixDirInputs cfg;
      devenvs = import ./src/devenvs.nix nixDirInputs cfg;
      nixt = import ./src/nixt.nix nixDirInputs cfg;
      passthrough = import ./src/passthrough.nix nixDirInputs cfg;
      flkModules = import ./src/modules.nix nixDirInputs cfg;
      lib = import ./src/lib.nix nixDirInputs cfg;

      modules = [
        overlays.applyOverlays
        devshells.applyDevShells
        devenvs.applyDevenvShells
        devenvs.applyDevenvModules
        nixt.applyNixtTests
        flkModules.applyDarwinModules
        flkModules.applyNixosModules
        flkModules.applyHomeManagerModules
        passthrough.applyPassthroughKeys
        packages.applyPackages
        lib.applyLib
      ];
    in
    builtins.foldl' (flk: applyModule: applyModule flk) { } modules;
in
{
  inherit buildFlake;
}
