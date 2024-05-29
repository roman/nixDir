nixDirInputs: { root
              , inputs
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
      true
      {
        lib =
          let
            userLib =
              if pathExists "${nixDir}/lib.nix" then
                importFile "${nixDir}/lib.nix" inputs
              else
                { };
          in
          (
            getPkgsExt //
            preCommitExt //
            userLib
          );
      };
}
