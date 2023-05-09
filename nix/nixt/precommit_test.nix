{ self, nixpkgs, ...} @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  systems = [ "x86_64-linux" ];
in

[
  (describe "hasPreCommitFile"
    [
      (it "indicates when pre-commit.nix file is present"
        (let
          root = ./.;
          buildFlakeCfg = {
            inherit root systems;
            inputs = nixDirInputs;
            # mock path check mechanism to always work
            pathExists = _: true;
          };
          precommit = import "${self}/precommit.nix" nixDirInputs buildFlakeCfg;
        in
          precommit.hasPreCommitFile))
    ])

  (describe "preCommitDevShellConfig"
    [
      (it "is not exported when pre-commit.nix file is not present"
        (let
          root = ./.;
          buildFlakeCfg = {
            inherit root systems;
            inputs = nixDirInputs;
            # mock path check mechanism to always fail
            pathExists = _: false;
          };
          precommit = import "${self}/precommit.nix" nixDirInputs buildFlakeCfg;
        in
          # precommit does not export symbols that it cannot build
          !(precommit ? preCommitDevShellConfig)))

      (it "builds a function that returns a valid configuration"
        (let
          root = ./.;
          preCommitCfg = {
            src = root;
            hooks.nixpkgs-fmt.enable = true;
          };
          buildFlakeCfg = {
            inherit root systems;
            inputs = nixDirInputs;
            injectPreCommit = true;
            # mock import mechanism to always work
            pathExists = _: true;
            importFile = _: _: _: preCommitCfg;
          };
          precommit = import "${self}/precommit.nix" nixDirInputs buildFlakeCfg;
        in
          (lib.hasAttrByPath ["preCommitDevShellConfig"] precommit) &&
          ((precommit.preCommitDevShellConfig "x86_64-linux") == preCommitCfg)))

      (it "builds a function that returns a valid configuration even when src is not present"
        (let
          root = ./.;
          preCommitCfg = {
            hooks.nixpkgs-fmt.enable = true;
          };
          buildFlakeCfg = {
            inherit root systems;
            inputs = nixDirInputs;
            injectPreCommit = true;
            # mock import mechanism to always work
            pathExists = _: true;
            importFile = _: _: _: preCommitCfg;
          };
          precommit = import "${self}/precommit.nix" nixDirInputs buildFlakeCfg;
        in
          (lib.hasAttrByPath ["preCommitDevShellConfig"] precommit) &&
          ((precommit.preCommitDevShellConfig "x86_64-linux").src == root)))
    ])

  (describe "preCommitInstallationScript"
    [
      (it "exports the installation script from the pre-commit-hooks utility"
        (let
          root = ./.;
          preCommitCfg = {
            hooks.nixpkgs-fmt.enable = true;
          };
          buildFlakeCfg = {
            inherit root systems;
            inputs = nixDirInputs;
            injectPreCommit = true;
            # mock import mechanism to always work
            pathExists = _: true;
            importFile = _: _: _: preCommitCfg;
          };
          precommit = import "${self}/precommit.nix" nixDirInputs buildFlakeCfg;
        in
          (lib.hasAttrByPath ["preCommitInstallationScript"] precommit) &&
          (lib.stringLength (precommit.preCommitInstallationScriptForShell "x86_64-linux" "devShellName") > 0)))

      (it "doesn't export installation script for devShells that are not in the injectPreCommit list"
        (let
          root = ./.;
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          preCommitCfg = {
            hooks.nixpkgs-fmt.enable = true;
          };
          buildFlakeCfg = {
            inherit root systems;
            inputs = {
              inherit (nixDirInputs) nixpkgs;
              self = {
                devShells.x86_64-linux = {
                  default = pkgs.mkShell {
                    shellHook = "echo 'default'";
                  };
                  other = pkgs.mkShell {
                    shellHook = "echo 'other'";
                  };
                };
              };
            };
            injectPreCommit = [ "other" ];
            # mock import mechanism to always work
            pathExists = _: true;
            importFile = _: _: _: preCommitCfg;
          };
          precommit = import "${self}/precommit.nix" nixDirInputs buildFlakeCfg;
        in
          (lib.hasAttrByPath ["preCommitInstallationScriptForShell"] precommit) &&
          (lib.stringLength (precommit.preCommitInstallationScriptForShell "x86_64-linux" "default") == 0) &&
          (lib.stringLength (precommit.preCommitInstallationScriptForShell "x86_64-linux" "other") > 0))
      )

    ])
]
