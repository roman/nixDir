nixDirInputs: let
  # getPkgs returns the nixpkgs repository for the given system with embedded
  # overlays from the input flake.
  getPkgs = overlaysToInject: system: {
    self,
    nixpkgs,
    ...
  }:
    if self ? overlays
    then
      import nixpkgs
      {
        inherit system;
        overlays =
          builtins.attrValues
          (nixpkgs.lib.filterAttrs
            # select only the overlays to inject
            (n: _: overlaysToInject ? n)
            self.overlays);
      }
    else
      import nixpkgs {
        inherit system;
      };

  # runPreCommit
  runPreCommit = root: inputs: pkgs: let
    inherit (pkgs) system;
    config =
      import "${root}/pre-commit.nix" system inputs pkgs;
  in
    nixDirInputs.pre-commit-hooks.lib.${system}.run config;

  # eachDefaultSystemMapWithPkgs
  eachSystemMapWithPkgs = overlaysToInject: systems: inputs: f:
    nixDirInputs.utils.lib.eachSystemMap systems (system: f (getPkgs overlaysToInject system inputs));

  # importDirFiles
  importDirFiles = importStrategy: inputs: pkgs: path: let
    inherit (inputs.nixpkgs) lib;

    isNixFile = name: ty: ty == "regular" && lib.hasSuffix ".nix" name;

    hasDefaultNix = name: ty: ty == "regular" && name == "default.nix";

    subDirNames =
      builtins.attrNames
      (lib.filterAttrs (name: ty: ty == "directory") (builtins.readDir path));

    nixFiles =
      builtins.attrNames (lib.filterAttrs isNixFile (builtins.readDir path));

    checkDirFileConflict = entry:
      if builtins.pathExists "${entry}/default.nix" && builtins.pathExists "${entry}.nix"
      then
        builtins.abort ''
          dirNix is confused, it found two conflicting entries.

          One is a directory (${entry}/default.nix), and the other a file (${entry}.nix).

          Please remove one of the two.
        ''
      else entry;

    nixSubDirNames =
      builtins.foldl'
      (acc: subdir: let
        files =
          lib.attrNames
          (lib.filterAttrs hasDefaultNix (builtins.readDir (checkDirFileConflict "${path}/${subdir}")));
      in
        if builtins.length files == 1
        then acc ++ [subdir]
        else acc) []
      subDirNames;

    entries =
      builtins.foldl'
      (acc: entryName: let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key =
          lib.removeSuffix ".nix" entryName;
      in
        acc
        // {
          "${key}" =
            if importStrategy == "withCallPackage"
            then pkgs.callPackage (import "${path}/${entryName}" pkgs.system inputs) {}
            else if importStrategy == "withPkgs"
            then import "${path}/${entryName}" pkgs.system inputs pkgs
            else if importStrategy == "withNoPkgs"
            then import "${path}/${entryName}" pkgs.system inputs
            else builtins.abort "implementation error: invalid importStrategy ${importStrategy}";
        })
      {}
      (nixSubDirNames ++ nixFiles);
  in
    entries;

  importPkgs = inputs: pkgs: path: importDirFiles "withCallPackage" inputs pkgs path;

  importModules = inputs: path: importDirFiles "withNoPkgs" inputs null path;

  importShells = importPkgs;

  buildFlake = {
    dirName ? "nix",
    injectPreCommit ? true,
    injectDevenvModules ? [],
    injectOverlays ? [],
    root,
    systems,
    inputs,
  }: let
    nixDir = "${root}/${dirName}";

    overlaysToInject =
      builtins.foldl' (acc: name: acc // {"${name}" = true;}) {} injectOverlays;

    applyOutput = check: entry0: outputs: let
      entry =
        if builtins.isFunction entry0
        then entry0 outputs
        else entry0;
    in
      if check
      then nixDirInputs.nixpkgs.lib.recursiveUpdate outputs entry
      else outputs;

    applyLib =
      applyOutput
      (builtins.pathExists "${nixDir}/lib.nix")
      {lib = import "${nixDir}/lib.nix" inputs;};

    applyOverlay =
      applyOutput
      (builtins.pathExists "${nixDir}/overlays.nix")
      {overlays = import "${nixDir}/overlays.nix" inputs;};

    applyPackages =
      applyOutput
      (builtins.pathExists "${nixDir}/packages")
      {
        packages = eachSystemMapWithPkgs overlaysToInject systems inputs (
          pkgs: let
            rejectPkgsWithUnsupportedSystem =
              # when the package derivation contains supported platforms, ensure
              # we filter only entries that are supported
              pkgs.lib.filterAttrs
              (_: pkg:
                if (pkg ? meta) && (pkg.meta ? platforms)
                then pkgs.lib.elem pkgs.system pkg.meta.platforms
                else
                  # in the scenario no platform information is given, default
                  # to keeping the package.
                  true);
          in
            rejectPkgsWithUnsupportedSystem
            (importPkgs inputs pkgs "${nixDir}/packages")
        );
      };

    applyNixOSModules =
      applyOutput
        (builtins.pathExists "${nixDir}/modules/nixos")
        {nixosModules = importModules inputs "${nixDir}/modules/nixos";};

    applyHomeManagerModules =
      applyOutput
        (builtins.pathExists "${nixDir}/modules/home-manager")
        {homeManagerModules = importModules inputs "${nixDir}/modules/home-manager";};

    applyDevenvModules =
      applyOutput
        (builtins.pathExists "${nixDir}/modules/devenv")
        {devenvModules = importModules inputs "${nixDir}/modules/devenv";};

    applyDevenvs =
      applyOutput
        (builtins.pathExists "${nixDir}/devenvs")
        (final: {
          devShells = eachSystemMapWithPkgs overlaysToInject systems inputs (
            pkgs: let
              devenvsCfg =
                importModules inputs "${nixDir}/devenvs";

              devenvModules =
                # if we have devenvModules initialized
                if final ? devenvModules then
                  if builtins.typeOf injectDevenvModules == "bool" then
                    # when the injectDevenvModules is a bool, include all
                    # defined nix/modules/devenv entries into this devenv
                    # configuration
                    builtins.attrValues final.devenvModules


                  else if builtins.typeOf injectDevenvModules == "list" then
                    # when the injectDevenvModules is a list of strings, we
                    # import only the specified modules inside the
                    # nix/modules/devenv directory
                    let
                      modules = final.devenvModules;
                    in
                      builtins.foldl' (acc: moduleName:
                        if pkgs.lib.hasAttrByPath [moduleName] modules then
                          acc ++ [ modules."${moduleName}" ]
                        else
                          acc
                      ) [] injectDevenvModules
                  else
                    # expect a bool or a list of strings
                    builtins.abort "error: injectDevenvModules must be a string of a list of devenv module names"
                else
                  [];

              applyDevenvCfg = devenvCfg:
                nixDirInputs.devenv.lib.mkShell {
                  inherit pkgs;
                  inputs = nixDirInputs;
                  modules =
                    devenvModules ++ [ devenvCfg ];
                };
            in
              builtins.mapAttrs (_: cfg: applyDevenvCfg cfg) devenvsCfg
          );
        });

    applyPreCommitLib =
      applyOutput
        (builtins.pathExists "${nixDir}/pre-commit.nix" && injectPreCommit)
        {
          lib = {preCommitRunHook = eachSystemMapWithPkgs overlaysToInject systems inputs (pkgs: (runPreCommit nixDir inputs pkgs).shellHook);};
        };

    applyDevShells = let
      hasPreCommit = builtins.pathExists "${nixDir}/pre-commit.nix";
    in
      applyOutput
      (builtins.pathExists "${nixDir}/devShells")
        {
          # Create the devShells entry for the final flake output configuration
          devShells = eachSystemMapWithPkgs overlaysToInject systems inputs (
            pkgs: let
              devShellCfgs = importShells inputs pkgs "${nixDir}/devShells";
              emptyPreCommitRunHook = "";
              preCommitRunHook =
                if hasPreCommit && injectPreCommit
                then runPreCommit nixDir inputs pkgs
                else emptyPreCommitRunHook;
            in
              pkgs.lib.foldl'
                (
                  acc: devShellName:
                  # we cannot have a configuration for both devenv and devShell
                  # with the same name so we abort as soon as we find a collision.
                  if
                    builtins.pathExists "${nixDir}/devenvs/${devShellName}"
                    || builtins.pathExists "${nixDir}/devenvs/${devShellName}.nix"
                  then
                    builtins.abort ''
                    dirNix is confused, it found two conflicting files/directories.

                    One is an entry in `devShells/${devShellName}` and the other is `devenvs/${devShellName}`.

                    Please remove one of the two
                  ''
                  else let
                    devEnvCfg = devShellCfgs.${devShellName};
                  in
                    acc
                    // {
                      ${devShellName} =
                        devEnvCfg.overrideAttrs
                          (final: prev: {
                            shellHook = prev.shellHook + preCommitRunHook;
                          });
                    }
                )
                {}
                (builtins.attrNames devShellCfgs)
          );
        };
  in
    builtins.foldl' (outputs: apply: apply outputs) {}
    # IMPORTANT: don't change the order of this apply functions unless is
    # truly necessary
    [
      applyDevenvModules
      applyDevenvs
      applyDevShells
      applyPackages
      applyHomeManagerModules
      applyNixOSModules
      applyPreCommitLib
      applyLib
      applyOverlay
    ];
in {
  inherit buildFlake;
}
