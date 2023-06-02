nixDirInputs: { root
              , dirName ? "nix"
              , pathExists ? builtins.pathExists
              , importFile ? (path: import path)
              , nixDir ? "${root}/${dirName}"
              , ...
              } @ buildFlakeCfg:
let
  precommit = import ./precommit.nix nixDirInputs buildFlakeCfg;
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;
  inherit (precommit) shouldInjectPreCommitLib;
  inherit (utils) applyFlakeOutput;
in
{

  applyLib =
    let
      getPkgsExt =
        { inherit (utils) getPkgs; };
      preCommitExt =
        if shouldInjectPreCommitLib then
          { inherit (precommit) preCommitRunScript; }
        else
          { };

    in
    applyFlakeOutput
      (pathExists "${nixDir}/lib.nix")
      {
        lib = (
          getPkgsExt //
          preCommitExt //
          importFile "${nixDir}/lib.nix" nixDirInputs
        );
      };
}
