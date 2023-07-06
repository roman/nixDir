nixDirInputs: { root
              , dirName ? "nix"
              , nixDir ? "${root}/${dirName}"
              , pathExists ? builtins.pathExists
              , ...
              } @ buildFlakeCfg:

let
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;
  importer = import ./importer.nix nixDirInputs buildFlakeCfg;

  inherit (utils) applyFlakeOutput;
  inherit (importer) importDarwinModules importNixosModules importHomeManagerModules;

  applyDarwinModules =
    applyFlakeOutput
      (pathExists "${nixDir}/modules/darwin")
      {
        darwinModules = importDarwinModules;
      };

  applyNixosModules =
    applyFlakeOutput
      (pathExists "${nixDir}/modules/nixos")
      {
        nixosModules = importNixosModules;
      };

  applyHomeManagerModules =
    applyFlakeOutput
      (pathExists "${nixDir}/modules/home-manager")
      {
        homeManagerModules = importHomeManagerModules;
      };
in
{
  inherit
    applyDarwinModules
    applyNixosModules
    applyHomeManagerModules;
}
