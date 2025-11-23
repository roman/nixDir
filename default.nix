_nixDirFlake:
{ lib, inputs, config, system, ... }:
let
  cfg = config.nixDir;
  path = "${cfg.root}/${cfg.dirName}";

  # checkConflicts validates that there are no overlapping keys between
  # regular and with-inputs directories. Having the same name in both
  # locations is likely a mistake by the flake author.
  checkConflicts = outputType: regular: withInputs:
    let
      conflicts = builtins.filter (name: regular ? ${name}) (builtins.attrNames withInputs);
      hasConflicts = builtins.length conflicts > 0;
    in
      if hasConflicts then
        throw ''
          nixDir found conflicting ${outputType} entries in both regular and with-inputs directories:
          ${lib.concatStringsSep ", " conflicts}

          Each entry should exist in either the regular directory OR the with-inputs directory, not both.

          Regular: ${cfg.dirName}/${outputType}/
          With-inputs: ${cfg.dirName}/with-inputs/${outputType}/

          Please move or rename the conflicting entries.
        ''
      else
        regular // withInputs;
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

      installDevenvModules = lib.mkOption {
        type = lib.types.functionTo lib.types.unspecified;
        description =
          "a function that returns a list of devenv modules that we want to import into our devenv configuration";
        default = (_: [ ]);
      };

      installAllDevenvModules = lib.mkOption {
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

      generateFlakeOverlay = lib.mkOption {
        type = lib.types.bool;
        description =
          "build an overlay that contains all the packages in the flake";
        default = true;
      };

      installFlakeOverlay = lib.mkOption {
        type = lib.types.bool;
        description =
          "install the flake overlay to the pkgs in flake-parts modules";
        default = true;
      };

      installOverlays = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        description =
          "install given list of overlays to the pkgs in flake-parts modules";
        default = [ ];
      };

      nixpkgsConfig = lib.mkOption {
        type = lib.types.attrs;
        description = "add configuration to nixpkgs import";
        default = { };
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
          withInputsNixosModulesPath = "${path}/with-inputs/modules/nixos";

          regularModules = if builtins.pathExists nixosModulesPath then
            importer.importNixOSModules nixosModulesPath
          else
            { };

          withInputsModules = if builtins.pathExists withInputsNixosModulesPath then
            importer.importDirWithInputs withInputsNixosModulesPath
          else
            { };

          allModules = checkConflicts "modules/nixos" regularModules withInputsModules;
        in lib.mkMerge [ acc { nixosModules = allModules; } ];

      addNixOSConfigurations = acc:
        let
          nixosConfigurationsPath = "${path}/configurations/nixos";
          withInputsNixosConfigurationsPath = "${path}/with-inputs/configurations/nixos";

          regularConfigs = if builtins.pathExists nixosConfigurationsPath then
            importer.importNixOSConfigurations nixosConfigurationsPath
          else
            { };

          withInputsConfigs = if builtins.pathExists withInputsNixosConfigurationsPath then
            importer.importNixOSConfigurationsWithInputs withInputsNixosConfigurationsPath
          else
            { };

          allConfigs = checkConflicts "configurations/nixos" regularConfigs withInputsConfigs;
        in lib.mkMerge [ acc { nixosConfigurations = allConfigs; } ];

      addNixDarwinModules = acc:
        let
          nixDarwinModulesPath = "${path}/modules/darwin";
          withInputsDarwinModulesPath = "${path}/with-inputs/modules/darwin";

          regularModules = if builtins.pathExists nixDarwinModulesPath then
            importer.importDarwinModules nixDarwinModulesPath
          else
            { };

          withInputsModules = if builtins.pathExists withInputsDarwinModulesPath then
            importer.importDirWithInputs withInputsDarwinModulesPath
          else
            { };

          allModules = checkConflicts "modules/darwin" regularModules withInputsModules;
        in lib.mkMerge [ acc { darwinModules = allModules; } ];

      addNixDarwinConfigurations = acc:
        let
          nixDarwinConfigurationsPath = "${path}/configurations/darwin";
          withInputsDarwinConfigurationsPath = "${path}/with-inputs/configurations/darwin";

          regularConfigs = if builtins.pathExists nixDarwinConfigurationsPath then
            importer.importDarwinConfigurations nixDarwinConfigurationsPath
          else
            { };

          withInputsConfigs = if builtins.pathExists withInputsDarwinConfigurationsPath then
            importer.importDarwinConfigurationsWithInputs withInputsDarwinConfigurationsPath
          else
            { };

          allConfigs = checkConflicts "configurations/darwin" regularConfigs withInputsConfigs;
        in lib.mkMerge [ acc { darwinConfigurations = allConfigs; } ];

      addHomeManagerModules = acc:
        let
          homeManagerModulesPath = "${path}/modules/home-manager";
          withInputsHomeManagerModulesPath = "${path}/with-inputs/modules/home-manager";

          regularModules = if builtins.pathExists homeManagerModulesPath then
            importer.importHomeManagerModules homeManagerModulesPath
          else
            { };

          withInputsModules = if builtins.pathExists withInputsHomeManagerModulesPath then
            importer.importDirWithInputs withInputsHomeManagerModulesPath
          else
            { };

          homeManagerModules = checkConflicts "modules/home-manager" regularModules withInputsModules;
        in lib.mkMerge [ acc { inherit homeManagerModules; } ];

      addDevenvModules = acc:
        let
          devenvModulesPath = "${path}/modules/devenv";
          withInputsDevenvModulesPath = "${path}/with-inputs/modules/devenv";

          regularModules = if builtins.pathExists devenvModulesPath then
            importer.importDevenvModules devenvModulesPath
          else
            { };

          withInputsModules = if builtins.pathExists withInputsDevenvModulesPath then
            importer.importDirWithInputs withInputsDevenvModulesPath
          else
            { };

          devenvModules = checkConflicts "modules/devenv" regularModules withInputsModules;
        in lib.mkMerge [ acc { inherit devenvModules; } ];

      addFlakeOverlay = acc:
        lib.mkMerge [
          acc
          (lib.mkIf (cfg.generateFlakeOverlay || cfg.installFlakeOverlay) {
            overlays = {
              flake = _final: prev:
                inputs.self.packages.${prev.stdenv.hostPlatform.system};
            };
          })
        ];

    in builtins.foldl' (acc: f: f acc) { } [
      addFlakeOverlay
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
            withInputsPackagesPath = "${path}/with-inputs/packages";

            regularPackages = if builtins.pathExists packagesPath then
              importer.importPackages packagesPath
            else
              { };

            withInputsPackages = if builtins.pathExists withInputsPackagesPath then
              lib.mapAttrs (_name: pkg: pkgs.callPackage pkg { })
                (importer.importDirWithInputs withInputsPackagesPath)
            else
              { };

            resultPackages = checkConflicts "packages" regularPackages withInputsPackages;
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
            { devenv.modules = cfg.installDevenvModules devenvModules; }
            (lib.mkIf cfg.installAllDevenvModules {
              devenv.modules = builtins.attrValues devenvModules;
            })
            acc
          ];

        installOverlays = acc:
          let
            shouldOverridePkgs = cfg.installFlakeOverlay
              || (builtins.length (cfg.installOverlays) > 0)
              || (cfg.nixpkgsConfig != { });

            overlayInstall = lib.mkIf shouldOverridePkgs ({
              _module.args.pkgs = import inputs.nixpkgs ({
                inherit system;
                config = cfg.nixpkgsConfig;
                overlays = (if cfg.installFlakeOverlay then
                  [ inputs.self.overlays.flake ]
                else
                  [ ]) ++ cfg.installOverlays;
              });
            });

          in lib.mkMerge [ acc overlayInstall ];

      in builtins.foldl' (acc: f: f acc) { } ([ addPackages ]
        ++ lib.optionals (inputs ? nixpkgs) [ installOverlays ]
        ++ lib.optionals (inputs ? devenv) [ addDevenvs addDevenvModules ]);
  };
}

