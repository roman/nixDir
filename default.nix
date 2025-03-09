_nixDirFlake:
{ lib, inputs, config, ... }:
let
  cfg = config.nixDir;
  path = "${cfg.root}/${cfg.dirName}";
in {
  options = {
    nixDir = {
      enable = lib.mkEnableOption
        "enable nix configuration through directory conventions";

      # root could be inferred from inputs.self.outPath, unfortunately that triggers an
      # infinite recursion error in some situations. This attribute may be removed once the
      # lazy attribute-set issue is fixed.  More info:
      # https://github.com/NixOS/nix/issues/4090
      root = lib.mkOption {
        type = lib.types.path;
        description = "absolute path to the flake.";
      };

      dirName = lib.mkOption {
        type = lib.types.str;
        description =
          "name of the directory that contains the nix configuration";
        default = "nix";
      };

      injectDevenvModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description =
          "a list of devenv module names that we want to import into our devenv configuration";
        default = [ ];
      };

      injectAllDevenvModules = lib.mkOption {
        type = lib.types.bool;
        description = "automatically import all devenv module names";
        default = false;
      };

      generateAllPackage = lib.mkOption {
        type = lib.types.bool;
        description =
          "build a package that contains all the packages in the flake, these packages include all the declared devShells";
        default = false;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    flake = let
      importer = import ./src/importer.nix {
        pkgs = null;
        inherit lib inputs;
      };

      addNixOSModules = acc:
        let
          nixosModulesPath = "${path}/modules/nixos";
          nixosModules = if builtins.pathExists nixosModulesPath then {
            nixosModules = importer.importNixOSModules nixosModulesPath;
          } else
            { };
        in lib.mkMerge [ acc nixosModules ];

      addNixOSConfigurations = acc:
        let
          nixosConfigurationsPath = "${path}/configurations/nixos";
          nixosConfigurations =
            if builtins.pathExists nixosConfigurationsPath then {
              nixosConfigurations =
                importer.importNixOSConfigurations nixosConfigurationsPath;
            } else
              { };
        in lib.mkMerge [ acc nixosConfigurations ];

      addNixDarwinModules = acc:
        let
          nixDarwinModulesPath = "${path}/modules/darwin";
          darwinModules = if builtins.pathExists nixDarwinModulesPath then {
            darwinModules = importer.importDarwinModules nixDarwinModulesPath;
          } else
            { };
        in lib.mkMerge [ acc darwinModules ];

      addNixDarwinConfigurations = acc:
        let
          nixDarwinConfigurationsPath = "${path}/configurations/darwin";
          darwinConfigurations =
            if builtins.pathExists nixDarwinConfigurationsPath then {
              darwinConfigurations =
                importer.importDarwinConfigurations nixDarwinConfigurationsPath;
            } else
              { };
        in lib.mkMerge [ acc darwinConfigurations ];

      addHomeManagerModules = acc:
        let
          homeManagerModulesPath = "${path}/modules/home-manager";
          homeManagerModules =
            if builtins.pathExists homeManagerModulesPath then
              importer.importHomeManagerModules homeManagerModulesPath
            else
              { };
        in lib.mkMerge [ acc { inherit homeManagerModules; } ];

      addDevenvModules = acc:
        let
          devenvModulesPath = "${path}/modules/devenv";
          devenvModules = if builtins.pathExists devenvModulesPath then
            importer.importDevenvModules devenvModulesPath
          else
            { };
        in lib.mkMerge [ acc { inherit devenvModules; } ];

    in builtins.foldl' (acc: f: f acc) { } [
      addNixOSModules
      addNixOSConfigurations
      addNixDarwinModules
      addNixDarwinConfigurations
      addHomeManagerModules
      addDevenvModules
    ];

    perSystem = { system, pkgs, ... }:
      let
        importer = import ./src/importer.nix { inherit pkgs lib inputs; };

        addPackages = acc:
          let
            packagesPath = "${path}/packages";
            resultPackages = if builtins.pathExists packagesPath then
              importer.importPackages packagesPath
            else
              { };
            shellPkgs =
              # shellPkgs are all the devShells derivations, these allow us to
              # cache shells the same way we do packages.
              lib.concatMapAttrs (name: shell:
                # skip devenv shells. They must be skipped given they are
                # impure and caching them wouldn't make much sense.
                if lib.hasPrefix "devenv-" shell.name then
                  { }
                else {
                  "${name}-shell" = shell.inputDerivation;
                }) inputs.self.devShells.${pkgs.system};

            allPackage = pkgs.symlinkJoin {
              name = "all";
              buildInputs = lib.attrValues shellPkgs;
              paths = lib.attrValues resultPackages;
            };

            nixDirPackages = lib.mkMerge [
              (lib.mkIf cfg.generateAllPackage {
                packages = resultPackages // { all = allPackage; };
              })
              (lib.mkIf (!cfg.generateAllPackage) {
                packages = resultPackages;
              })
            ];
          in lib.mkMerge [ acc nixDirPackages ];

        addDevenvs = acc:
          let
            devenvsPath = "${path}/devenvs";
            devenvEntries = if builtins.pathExists devenvsPath then {
              devenv.shells = importer.importDevenvs devenvsPath;
            } else
              { };
          in lib.mkMerge [ acc devenvEntries ];

        addDevenvModules = acc:
          let
            devenvModulesPath = "${path}/modules/devenv";
            devenvModules = if builtins.pathExists devenvModulesPath then
              importer.importDevenvs devenvModulesPath
            else
              { };
          in lib.mkMerge [
            (lib.mkIf ((builtins.length cfg.injectDevenvModules) != 0) {
              devenv.modules = builtins.attrValues
                (lib.getAttrs cfg.injectDevenvModules devenvModules);
            })
            (lib.mkIf cfg.injectAllDevenvModules {
              devenv.modules = builtins.attrValues devenvModules;
            })
            acc
          ];
      in builtins.foldl' (acc: f: f acc) { } ([ addPackages ]
        ++ lib.optionals (inputs ? devenv) [ addDevenvs addDevenvModules ]);
  };
}

