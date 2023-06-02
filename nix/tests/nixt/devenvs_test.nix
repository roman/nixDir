{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  systems = [ system ];

  pathExists_noPreCommit = path:
    # ignore devenvs profiles
    (builtins.match ".*devShells.*" (builtins.toString path) == null) &&
    # ignore pre-commit.nix file
    (!lib.hasSuffix "pre-commit.nix" path);

  pathExists_devShellsConflictEntry = name: path:
    (lib.hasSuffix "nix/devShells/${name}.nix" path
      || lib.hasSuffix "nix/devenvs" path);

  pathExists_preCommitPresent = path:
    (builtins.match ".*devShells.*" (builtins.toString path)) == null;

  mkBuildFlakeCfg =
    { devenvNames ? [ ]
    , devenvModules ? [ ]
    , injectPreCommit ? false
    , injectDevenvModules ? false
    , pathExists
    }:
    let
      # root config for nixDir.lib.buildFlake call
      root = ./.;

      # use x86_64-linux architecture as our standard pkgs
      pkgs = import nixpkgs { inherit system; };

      # utility function to construct shells
      mkDevenv = name:
        ({ pkgs, ... }: {
          enterShell = ''
            echo ${name}
          '';
        });

      # map that contains the direct result of importDevShells as well as
      # the value inside the self input
      importDevenvShells =
        builtins.foldl'
          (acc: name: acc // { "${name}" = mkDevenv name; })
          { }
          devenvNames;

      importPreCommitConfig =
        pkgs:
        { pre-commit.hooks.nixpkgs-fmt.enable = true; };

      mkDevenvModule = moduleName:
        ({ pkgs, config, ... }:
          let
            cfg = config.${moduleName};
          in
          {
            options = {
              "${moduleName}" = {
                enable = lib.mkEnableOption "enable ${moduleName}";
              };
            };

            config = lib.mkIf cfg.enable {
              enterShell = ''
                echo "module ${moduleName}"
              '';
            };
          });

      importDevenvModules =
        builtins.foldl'
          (acc: moduleName: acc // { "${moduleName}" = mkDevenvModule moduleName; })
          { }
          devenvModules;


      # parameter used inside the buildFlake configuration, mock
      # it as not to require a real flake to test code
      inputs = {
        inherit nixpkgs;
        # this is used for meta checks
        self = {
          devShells.${system} =
            builtins.foldl'
              (acc: devenvName:
                acc // {
                  "${devenvName}" = nixDirInputs.devenv.lib.mkShell {
                    inherit pkgs;
                    inputs = nixDirInputs;
                    modules = [ mkDevenv devenvName ];
                  };
                }
              )
              { }
              devenvNames;
        };
      };

      # used by the precommit logic inside devshells
      getEntriesForPath = path:
        if lib.hasSuffix "nix/devenvs" path then
          devenvNames
        else
          [ ];
    in
    # configuration value used in the nixDir.lib.buildFlake call
    {
      root = ./.;
      # parameters usually provided by flake authors in the
      # nixDir.lib.buildFlake call
      inherit inputs systems injectPreCommit injectDevenvModules;
      # override functions for unit-test
      inherit importDevenvShells importDevenvModules importPreCommitConfig pathExists getEntriesForPath;
    };

  devenvShellSpecs =
    [
      {
        it = "generates a devShell entry when files are present in the nix/devenv directory";
        args = {
          devenvNames = [ "testing" ];
          injectPreCommit = false;
          injectDevenvModules = false;
          pathExists = pathExists_noPreCommit;
        };
        assertion = flk:
          lib.hasAttrByPath [ "devShells" "x86_64-linux" "testing" ] flk &&
          lib.hasAttrByPath [ "devShells" "x86_64-linux" "testing" "config" "devenv" ] flk &&
          (lib.hasPrefix "echo testing" flk.devShells.x86_64-linux.testing.config.enterShell);
      }
      {
        it = "reports a conflict when nix/devShells entry with same name exists";
        args = {
          devenvNames = [ "testing" ];
          injectPreCommit = false;
          injectDevenvModules = false;
          pathExists = pathExists_devShellsConflictEntry "testing";
        };
        assertion = flk:
          let
            eval = builtins.tryEval (flk.devShells.x86_64-linux.testing);
          in
            !eval.success;
      }
      {
        it = "reports an error when injectPreCommit entry doesn't have valid entry name";
        args = {
          devenvNames = [ "foo" "bar" ];
          injectPreCommit = [ "unknown" ];
          injectDevenvModules = false;
          pathExists = pathExists_preCommitPresent;
        };
        assertion = flk:
          let
            eval = builtins.tryEval (flk.devShells.x86_64-linux.foo);
          in
            !eval.success;
      }
      # {
      #   it = "generates a devShell with pre-commit when pre-commit.nix and injectPreCommit hook has entry name";
      #   args = {
      #     devenvNames = ["testing" "other"];
      #     injectPreCommit = ["testing"];
      #     injectDevenvModules = false;
      #     pathExists = pathExists_preCommitPresent;
      #   };
      #   assertion = flk:
      #     # `testing` devShell gets pre-commit installed
      #     flk.devShells.x86_64-linux.testing.nixDirPreCommitInjected &&
      #     # `other` devShell doesn't get pre-commit applied due to
      #     # injectPreCommit configuration
      #     !flk.devShells.x86_64-linux.other.nixDirPreCommitInjected;
      # }
      # {
      #   it =  "generates all devShells with pre-commit when pre-commit.nix and injectPreCommit is true";
      #   args = {
      #     devenvNames = ["testing" "other"];
      #     injectPreCommit = true;
      #     injectDevenvModules = false;
      #     pathExists = pathExists_preCommitPresent;
      #   };
      #   assertion = flk:
      #     flk.devShells.x86_64-linux.testing.nixDirPreCommitInjected &&
      #     flk.devShells.x86_64-linux.other.nixDirPreCommitInjected;
      # }
      # {
      #   it =  "doesn't generate any devShells with pre-commit when injectPreCommit is false";
      #   args = {
      #     devenvNames = ["testing" "other"];
      #     injectPreCommit = false;
      #     injectDevenvModules = false;
      #     pathExists = pathExists_preCommitPresent;
      #   };
      #   assertion = flk:
      #     !flk.devShells.x86_64-linux.testing.nixDirPreCommitInjected &&
      #     !flk.devShells.x86_64-linux.other.nixDirPreCommitInjected;
      # }
      # {
      #   it = "reports an error when injectDevenvModules has an invalid value type";
      #   args = {
      #     devenvNames = ["testing"];
      #     devenvModules = ["mymodule"];
      #     injectPreCommit = false;
      #     injectDevenvModules = 123;
      #     pathExists = pathExists_preCommitPresent;
      #   };
      #   assertion = flk:
      #     let
      #       eval = builtins.tryEval (flk.devShells.x86_64-linux.testing);
      #     in
      #       !eval.success;
      # }
      # {
      #   it = "reports an error when injectDevenvModules has an entry that doesn't exist in nix/modules/devenv";
      #   args = {
      #     devenvNames = ["testing"];
      #     devenvModules = ["mymodule"];
      #     injectPreCommit = false;
      #     injectDevenvModules = ["unknown"];
      #     pathExists = pathExists_preCommitPresent;
      #   };
      #   assertion = flk:
      #     let
      #       eval = builtins.tryEval (flk.devShells.x86_64-linux.testing);
      #     in
      #       !eval.success;
      # }
      # {
      #   it = "imports devenv module when a valid nix/modules/devenv name is specified in injectDevenvModules";
      #   args = {
      #     devenvNames = ["testing"];
      #     devenvModules = ["mymodule"];
      #     injectPreCommit = false;
      #     injectDevenvModules = ["mymodule"];
      #     pathExists = pathExists_preCommitPresent;
      #   };
      #   assertion = flk:
      #     lib.hasAttrByPath ["devShells" "x86_64-linux" "testing" "config" "mymodule"] flk;
      # }
    ];

in
[
  (describe "applyDevenvShells"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [
          (it spec.it
            (
              let

                buildFlakeCfg = mkBuildFlakeCfg {
                  inherit (spec.args) devenvNames devenvModules pathExists injectPreCommit injectDevenvModules;
                };
                sut = import "${self}/nix/src/devenvs.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyDevenvShells { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      devenvShellSpecs))

  (describe "applyDevModules"
    [
      (it "generates a devenvModules flake attribute with contents from the nix/modules/devenv directory"
        (
          let
            buildFlakeCfg = mkBuildFlakeCfg {
              devenvModules = [ "mymodule" ];
              pathExists = pathExists_noPreCommit;
              injectPreCommit = false;
              injectDevenvModules = false;
            };
            sut = import "${self}/nix/src/devenvs.nix" nixDirInputs buildFlakeCfg;
            flk = sut.applyDevenvModules { };
          in
          lib.hasAttr "devenvModules" flk &&
          lib.hasAttrByPath [ "devenvModules" "mymodule" ] flk
        ))
    ])

]
