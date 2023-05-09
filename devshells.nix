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

  precommit = import ./precommit.nix nixDirInputs buildFlakeCfg;
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;
  importer = import ./importer.nix nixDirInputs buildFlakeCfg;

  inherit (nixpkgs) lib;
  inherit (precommit) preCommitInstallationScriptForShell shouldInjectPreCommit;
  inherit (utils) applyFlakeOutput eachSystemMapWithPkgs;
  inherit (importer) importDevShells;

  applyDevShells =
    applyFlakeOutput
      (pathExists "${nixDir}/devShells")
      {
        devShells = eachSystemMapWithPkgs systems (pkgs:
          let
            devShellCfgs =
              importDevShells pkgs;

            getDevShellCfg = devShellName:
              if
                (pathExists "${nixDir}/devenvs/${devShellName}")
                || (pathExists "${nixDir}/devenvs/${devShellName}.nix")
              then
                throw ''
                  nixDir is confused, it found two conflicting files/directories.

                  One is an entry in `devShells/${devShellName}` and the other is `devenvs/${devShellName}`.

                  Please remove one of the entries to avoid conflicts.
                ''
              else
                devShellCfgs.${devShellName};

            step = acc: devShellName:
              let
                devShellCfg = getDevShellCfg devShellName;
              in
                if shouldInjectPreCommit pkgs.system devShellName then
                  # include the pre-commit installation
                  acc // { "${devShellName}" =
                      (devShellCfg.overrideAttrs (final: prev:
                        {
                          shellHook = prev.shellHook + preCommitInstallationScriptForShell devShellName;
                          nixDirPreCommitInjected = true;
                        }));
                  }
                else
                  acc // { "${devShellName}" =
                      (devShellCfg.overrideAttrs (final: prev:
                        {
                          nixDirPreCommitInjected = false;
                        })); };
          in
            lib.foldl' step {} (builtins.attrNames devShellCfgs)
        );
      };
in
{
  inherit applyDevShells;
}
