# nixDirInputs is the flake inputs from the nixDir project
nixDirInputs: let

  # getPkgs returns the nixpkgs repository for the given system with optional
  # embedded overlays from the self flake.
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
            (n: _: builtins.hasAttr n overlaysToInject)
            self.overlays);
      }
    else
      import nixpkgs {
        inherit system;
      };

  # runPreCommit returns the pre-commit-hooks run call for the
  # nix/pre-commit.nix
  runPreCommit = root: inputs: pkgs: let
    inherit (pkgs) system;
    config0 = import "${root}/pre-commit.nix" system inputs pkgs;
    # add the src attribute to the pre-commit configuration
    config = config0 // {
        src = root;
      };
  in
    nixDirInputs.pre-commit-hooks.lib.${system}.run config;

  # eachDefaultSystemMapWithPkgs imports nixpkgs with specified overlays for
  # each given system
  eachSystemMapWithPkgs = overlaysToInject: systems: inputs: f:
    nixDirInputs.utils.lib.eachSystemMap systems (system: f (getPkgs overlaysToInject system inputs));

  # importDirFiles imports directories using a given strategy. All the
  # strategies involve providing the system and inputs of the flake into the
  # file. The strategy could be one of the following:
  #
  # - withCallPackage
  #
  #   Imports the given nix file with a `pkgs.callPackage` call. This strategy
  #   enforces that the third argument of the imported nix file must be an
  #   attribute-set of required dependencies.
  #
  # - withPkgs
  #
  #   Uses the nixpkgs import as the third argument of the function.
  #
  # - withNoPkgs
  #
  #   No packages argument is given to the imported nix file.
  #
  # - nixtTests
  #
  #   The imported file receives the flake's inputs and the nixt API to
  #   create unit tests
  #
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
        throw ''
          nixDir is confused, it found two conflicting entries.

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
            else if importStrategy == "nixtTest"
            then import "${path}/${entryName}" inputs { inherit (inputs.nixt.lib) describe it; }
            else throw "implementation error: invalid importStrategy ${importStrategy}";
        })
      {}
      (nixSubDirNames ++ nixFiles);
  in
    entries;

  # importPkgs is used to import the `nix/packages` directory
  importPkgs = inputs: pkgs: path: importDirFiles "withCallPackage" inputs pkgs path;

  # importModules is used to import the `nix/modules/[devenv,nixos,home-manager]` directories
  importModules = inputs: path: importDirFiles "withNoPkgs" inputs null path;

  # importShells is used to import the `nix/devShells` directory
  importShells = importPkgs;

  # importNixtTests is used to import the `nix/tests` directory
  importNixtTests =
    nixDir: inputs:
    let
      path = nixDir + "/nixt";
      block = nixDirInputs.nixt.lib.block;
      testPerFile = importDirFiles "nixtTest" inputs null path;
      toPath = s: path + s;
      blocks =
        builtins.foldl'
          (acc: fileName:
            if builtins.typeOf testPerFile.${fileName} != "list" then
              acc ++ [{ path = toPath "/${fileName}.nix"; suites = [ testPerFile.${fileName} ]; }]
            else
              acc ++ [{ path = toPath "/${fileName}.nix"; suites = testPerFile.${fileName}; }]
          )
          []
          (builtins.attrNames testPerFile);
    in
      blocks;

  # buildFlake is the only exported function of this API. It is the main entry
  # point for nix flake authors to transform a nix directory into a nix flake
  buildFlake = {
    dirName ? "nix",
    injectPreCommit ? true,
    injectDevenvModules ? [],
    injectOverlays ? [],
    root,
    systems,
    inputs,
  }: let
    nixDir = root + "/${dirName}";

    overlaysToInject =
      builtins.foldl' (acc: name: acc // {"${name}" = true;}) {} injectOverlays;

    devShellsWithPreCommit =
      if builtins.typeOf injectPreCommit == "list" then
        builtins.foldl' (acc: name: acc // {"${name}" = true;}) {} injectPreCommit
      else if builtins.typeOf injectPreCommit == "bool" then
        {}
      else
        throw "error: injectPreCommit must be a string of a list of devShell/devenv profile names";

    shouldInjectPreCommit = devShellName:
      (builtins.typeOf injectPreCommit == "bool" && injectPreCommit)
        || (builtins.hasAttr devShellName devShellsWithPreCommit);

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
      {
        lib = (
          { getPkgs = system: getPkgs overlaysToInject system inputs; }
          // import "${nixDir}/lib.nix" inputs
        );
      };

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

              devenvPreCommitModule = devShellName:
                if shouldInjectPreCommit devShellName then
                  ({...}:
                    pkgs.lib.recursiveUpdate
                      {
                        pre-commit =
                          import "${nixDir}/pre-commit.nix" pkgs.system inputs pkgs;
                      }
                      { pre-commit.rootSrc = root; })
                else
                  {};

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
                        if pkgs.lib.hasAttr moduleName modules then
                          acc ++ [ modules."${moduleName}" ]
                        else
                          acc
                      ) [] injectDevenvModules
                  else
                    # expect a bool or a list of strings
                    throw "error: injectDevenvModules must be a string of a list of devenv module names"
                else
                  [];

              applyDevenvCfg = devShellName: devenvCfg:
                let
                  result =
                    nixDirInputs.devenv.lib.mkShell {
                      inherit pkgs;
                      inputs = nixDirInputs;
                      modules =
                        (devenvModules ++ [(devenvPreCommitModule devShellName) devenvCfg]);
                    };
                in result //
                  {
                    nixDirPreCommitInjected = shouldInjectPreCommit devShellName;
                  });
            in
              builtins.mapAttrs (name: cfg: applyDevenvCfg name cfg) devenvsCfg
          );
        });

    applyPreCommitLib =
      applyOutput
        (builtins.pathExists "${nixDir}/pre-commit.nix")
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
              emptyPreCommitInstallationScript = "";
              preCommitInstallationScript = devShellName:
                if hasPreCommit && shouldInjectPreCommit devShellName
                then (runPreCommit nixDir inputs pkgs).shellHook
                else emptyPreCommitInstallationScript;
            in
              pkgs.lib.foldl'
                (
                  acc: devShellName:
                  # we cannot have a configuration for both devenv and devShell
                  # with the same name so we throw as soon as we find a collision.
                  if
                    builtins.pathExists "${nixDir}/devenvs/${devShellName}"
                    || builtins.pathExists "${nixDir}/devenvs/${devShellName}.nix"
                  then
                    throw ''
                    nixDir is confused, it found two conflicting files/directories.

                    One is an entry in `devShells/${devShellName}` and the other is `devenvs/${devShellName}`.

                    Please remove one of the two
                  ''
                  else let
                    devShellCfg = devShellCfgs.${devShellName};
                  in
                    acc
                    // {
                      ${devShellName} =
                        devShellCfg.overrideAttrs
                          (final: prev: {
                            shellHook = prev.shellHook + preCommitInstallationScript devShellName;
                            nixDirPreCommitInjected = shouldInjectPreCommit devShellName;
                          });
                    }
                )
                {}
                (builtins.attrNames devShellCfgs)
          );
        };

    applyNixtTests =
      applyOutput
      (builtins.pathExists "${nixDir}/nixt")
        (
          let
              testBlocks = importNixtTests nixDir inputs;
          in
            {
              __nixt = inputs.nixt.lib.grow {
                blocks = testBlocks;
              };
            }
        );

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
      applyNixtTests
    ];
in {
  inherit buildFlake;
}
