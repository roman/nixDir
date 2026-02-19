_nixDirFlake:
{
  lib,
  inputs,
  config,
  ...
}:
let
  cfg = config.nixDir;
  path = "${cfg.root}/${cfg.dirName}";

  constants = import ./src/constants.nix;
  inherit (constants) dirNames flakeLevelKinds;

  flakeLib = import ./lib.nix {
    inherit lib;
    inherit (cfg) dirName;
  };
  inherit (flakeLib) checkConflicts filterByPlatform;

  # ===========================================================================
  # Options
  # ===========================================================================

  nixDirOptions = {
    enable = lib.mkEnableOption "enable nix configuration through directory conventions";

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
      description = "name of the directory that contains the nix configuration";
      default = "nix";
    };

    installDevenvModules = lib.mkOption {
      type = lib.types.functionTo lib.types.unspecified;
      description = "a function that returns a list of devenv modules that we want to import into our devenv configuration";
      default = (_: [ ]);
    };

    installAllDevenvModules = lib.mkOption {
      type = lib.types.bool;
      description = "automatically import all devenv module names";
      default = false;
    };

    generateAllPackage = lib.mkOption {
      type = lib.types.bool;
      description = "build a package that contains all the packages in the flake, these packages include all the declared devShells";
      default = false;
    };

    generateFlakeOverlay = lib.mkOption {
      type = lib.types.bool;
      description = "build an overlay that contains all the packages in the flake";
      default = false;
    };

    installFlakeOverlay = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Install the flake overlay to the pkgs in flake-parts modules.

        WARNING: Enabling this option can cause infinite recursion if your
        perSystem configuration references `self'.packages` or if package
        definitions have complex dependencies on pkgs during evaluation.
        Only enable if you specifically need your flake's packages available
        as `pkgs.<package-name>` within your own flake configuration.

        As an alternative, you can:

        1. Place packages that need access to flake inputs in the `with-inputs/packages/`
           directory, which provides access to inputs without requiring the flake overlay.

        2. Use the importWithInputs option to let all packages and modules have access
           to the inputs from this flake.
      '';
      default = false;
    };

    installOverlays = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      description = "install given list of overlays to the pkgs in flake-parts modules";
      default = [ ];
    };

    nixpkgsConfig = lib.mkOption {
      type = lib.types.attrs;
      description = "add configuration to nixpkgs import";
      default = { };
    };

    filterUnsupportedSystems = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Filter packages based on meta.platforms attribute.
        When enabled, packages are only exposed for systems listed in their meta.platforms.
        Packages without meta.platforms are available on all systems.
        Packages with meta.broken = true are always filtered out.
      '';
      default = true;
    };

    importWithInputs = lib.mkOption {
      type = lib.types.bool;
      description = ''
        When enabled, all files in the regular directory tree receive 'inputs'
        as their first parameter, similar to the with-inputs pattern.

        This eliminates the need for a separate with-inputs directory while
        maintaining access to flake inputs, reducing cognitive load from
        split directory structures.

        Example usage:
          # nix/packages/my-package.nix
          inputs: { pkgs, ... }:
          pkgs.writeShellScript "hello" ''''
            echo "Using ''${inputs.some-input}"
          ''''

        Note: The with-inputs directories continue to work when this option
        is enabled, but a warning will be shown if both directory trees exist
        to encourage unification in the default tree.
      '';
      default = false;
    };

    strictDiscovery = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Error when directories containing default.nix files are ignored during discovery.

        Directories can be ignored because:
        - They exceed maxDepth (default 3 levels of nesting)
        - A sibling .nix file blocks traversal (e.g., foo.nix blocks foo/)

        When enabled, nixDir throws an error listing all ignored directories,
        helping catch misconfigured directory structures early.

        Set to false to silently ignore such directories.
      '';
      default = false;
    };

    followSymlinks = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Follow symbolic links when discovering directories.

        When disabled (default), symlinks are skipped during directory traversal.
        When enabled, symlinks pointing to directories are followed and their
        contents are discovered as if they were regular directories.

        Note: Symlinks pointing to files are always skipped regardless of this setting.
      '';
      default = false;
    };
  };

  # ===========================================================================
  # Flake-level outputs (modules, configurations, overlays)
  # ===========================================================================

  flakeOutputs =
    let
      # Warn if both nix/<dir> and nix/with-inputs/<dir> exist when importWithInputs=true
      # deadnix: skip
      warnRedundantWithInputs =
        dir:
        if
          cfg.importWithInputs
          && builtins.pathExists "${path}/${dir}"
          && builtins.pathExists "${path}/${dirNames.withInputs}/${dir}"
        then
          builtins.trace ''
            nixDir warning: Both '${cfg.dirName}/${dir}' and '${cfg.dirName}/${dirNames.withInputs}/${dir}' exist.
            Consider unifying them in the default '${cfg.dirName}/${dir}' tree when using importWithInputs=true.
          '' true
        else
          false;

      outputDirPaths = builtins.attrValues {
        inherit (dirNames)
          packages
          devShells
          devenvShells
          nixosModules
          darwinModules
          homeManagerModules
          devenvModules
          nixosConfigurations
          darwinConfigurations
          ;
      };

      # Force evaluation of all dual-tree checks to emit warnings
      # deadnix: skip
      warning = builtins.any warnRedundantWithInputs outputDirPaths;

      importer = lib.deepSeq warning (
        import ./src/importer.nix {
          pkgs = null;
          inherit lib inputs;
          inherit (cfg) importWithInputs strictDiscovery followSymlinks;
        }
      );

      outputKinds = import ./src/output-kinds.nix { flakeInputs = inputs; };

      # Generic function to add any flake-level output kind
      addFlakeLevelOutput =
        kindName: acc:
        let
          kind = outputKinds.${kindName};
          regularPath = "${path}/${kind.dirPath}";
          withInputsPath = "${path}/${dirNames.withInputs}/${kind.dirPath}";

          importKind =
            p: withInputs:
            let
              raw = importer.importByStrategy {
                inherit (kind) strategy;
                inherit withInputs;
              } p;
            in
            if kind.wrapper != null then lib.mapAttrs kind.wrapper raw else raw;

          regular = if builtins.pathExists regularPath then importKind regularPath false else { };

          withInputsResult =
            if builtins.pathExists withInputsPath then importKind withInputsPath true else { };

          all = checkConflicts kind.dirPath regular withInputsResult;
        in
        lib.mkMerge [
          acc
          (lib.mkIf (all != { }) { ${kind.flakeAttr} = all; })
        ];

      flakeOverlay = lib.mkIf (cfg.generateFlakeOverlay || cfg.installFlakeOverlay) {
        overlays.flake = _final: prev: inputs.self.packages.${prev.stdenv.hostPlatform.system};
      };

      dataDriverOutputs = builtins.foldl' (
        acc: kindName: addFlakeLevelOutput kindName acc
      ) { } flakeLevelKinds;
    in
    lib.mkMerge [
      flakeOverlay
      dataDriverOutputs
    ];

  # ===========================================================================
  # Per-system outputs (packages, devShells, devenvs)
  # ===========================================================================

  perSystemOutputs =
    { system, pkgs, ... }:
    let
      importer = import ./src/importer.nix {
        inherit pkgs lib inputs;
        inherit (cfg) importWithInputs strictDiscovery followSymlinks;
      };

      # --- Packages ---

      packagesPath = "${path}/${dirNames.packages}";
      withInputsPackagesPath = "${path}/${dirNames.withInputs}/${dirNames.packages}";

      regularPackages =
        if builtins.pathExists packagesPath then importer.importPackages packagesPath else { };

      withInputsPackages =
        if builtins.pathExists withInputsPackagesPath then
          importer.importPackagesWithInputs withInputsPackagesPath
        else
          { };

      resultPackages = checkConflicts "packages" regularPackages withInputsPackages;

      filteredPackages =
        if cfg.filterUnsupportedSystems then filterByPlatform system resultPackages else resultPackages;

      # When generateAllPackage is true, we have a potential infinite recursion:
      # packages -> devShells -> pkgs (with overlay) -> packages
      # To avoid this, we disable filtering when generateAllPackage is enabled.
      shouldFilter = cfg.filterUnsupportedSystems && !cfg.generateAllPackage;

      finalPackages = if shouldFilter then filteredPackages else resultPackages;

      shellPkgs = lib.concatMapAttrs (
        name: shell:
        # skip devenv shells - they are impure and caching them wouldn't make sense
        if lib.hasPrefix "devenv-" shell.name then { } else { "${name}-shell" = shell.inputDerivation; }
      ) inputs.self.devShells.${pkgs.system};

      allPackage = pkgs.symlinkJoin {
        name = "all";
        buildInputs = lib.attrValues shellPkgs;
        paths = lib.attrValues finalPackages;
      };

      packagesOutput = lib.mkMerge [
        (lib.mkIf cfg.generateAllPackage {
          packages = finalPackages // {
            all = allPackage;
          };
        })
        (lib.mkIf (!cfg.generateAllPackage) { packages = finalPackages; })
      ];

      # --- DevShells ---

      devShellsPath = "${path}/${dirNames.devShells}";
      withInputsDevShellsPath = "${path}/${dirNames.withInputs}/${dirNames.devShells}";

      regularDevShells =
        if builtins.pathExists devShellsPath then importer.importDevShells devShellsPath else { };

      withInputsDevShells =
        if builtins.pathExists withInputsDevShellsPath then
          importer.importDevShellsWithInputs withInputsDevShellsPath
        else
          { };

      allDevShells = checkConflicts "devshells" regularDevShells withInputsDevShells;

      # --- Devenvs ---

      devenvsPath = "${path}/${dirNames.devenvShells}";
      withInputsDevenvsPath = "${path}/${dirNames.withInputs}/${dirNames.devenvShells}";

      regularDevenvs =
        if builtins.pathExists devenvsPath then importer.importDevenvs devenvsPath else { };

      withInputsDevenvs =
        if builtins.pathExists withInputsDevenvsPath then
          importer.importDevenvsWithInputs withInputsDevenvsPath
        else
          { };

      allDevenvs = checkConflicts "devenvs" regularDevenvs withInputsDevenvs;

      # Cross-conflict check: devShells vs devenvs
      crossConflicts = builtins.filter (name: allDevenvs ? ${name}) (builtins.attrNames allDevShells);

      # devShells output - always available, doesn't require devenv
      devShellsOutput = {
        devShells = allDevShells;
      };

      # devenvs output - only meaningful when devenv input exists
      devenvsOutput =
        if builtins.length crossConflicts > 0 then
          throw ''
            nixDir found conflicting entries between devShells and devenvs:
            ${lib.concatStringsSep ", " crossConflicts}

            DevEnv creates devShells internally, so each name must be unique across both.

            DevShells: ${cfg.dirName}/${dirNames.devShells}/ or ${cfg.dirName}/${dirNames.withInputs}/${dirNames.devShells}/
            DevEnvs: ${cfg.dirName}/${dirNames.devenvShells}/ or ${cfg.dirName}/${dirNames.withInputs}/${dirNames.devenvShells}/

            Please rename or remove the conflicting entries.
          ''
        else
          { devenv.shells = allDevenvs; };

      # --- Devenv Modules (perSystem) ---

      devenvModulesPath = "${path}/${dirNames.devenvModules}";

      discoveredDevenvModules =
        if builtins.pathExists devenvModulesPath then importer.importDevenvs devenvModulesPath else { };

      devenvModulesOutput = lib.mkMerge [
        { devenv.modules = cfg.installDevenvModules discoveredDevenvModules; }
        (lib.mkIf cfg.installAllDevenvModules {
          devenv.modules = builtins.attrValues discoveredDevenvModules;
        })
      ];

      # --- Overlays ---

      shouldOverridePkgs =
        cfg.installFlakeOverlay || (builtins.length cfg.installOverlays > 0) || (cfg.nixpkgsConfig != { });

      overlaysOutput = lib.mkIf shouldOverridePkgs {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = cfg.nixpkgsConfig;
          overlays =
            (if cfg.installFlakeOverlay then [ inputs.self.overlays.flake ] else [ ]) ++ cfg.installOverlays;
        };
      };
    in
    lib.mkMerge (
      [
        packagesOutput
        devShellsOutput
      ]
      ++ lib.optionals (inputs ? nixpkgs) [ overlaysOutput ]
      ++ lib.optionals (inputs ? devenv) [
        devenvsOutput
        devenvModulesOutput
      ]
    );

in
# =============================================================================
# Flake-parts module
# =============================================================================
{
  options.nixDir = nixDirOptions;

  config = lib.mkIf cfg.enable {
    flake = flakeOutputs;
    perSystem = perSystemOutputs;
  };
}
