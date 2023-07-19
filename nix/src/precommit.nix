{ nixpkgs, ... } @ nixDirInputs: { inputs
                                 , root
                                 , systems
                                 , injectPreCommit ? true
                                 , dirName ? "nix"
                                 , nixDir ? "${root}/${dirName}"
                                 , pathExists ? builtins.pathExists
                                 , ...
                                 } @ buildFlakeCfg:

let
  inherit (nixpkgs) lib;
  inherit (inputs) self;


  utils = import ./utils.nix nixDirInputs buildFlakeCfg;
  importer = import ./importer.nix nixDirInputs buildFlakeCfg;

  inherit (importer) importPreCommitConfig getEntriesForPath;
  inherit (utils) getFlakeInput;

  pre-commit-hooks =
    getFlakeInput "pre-commit-hooks" "github:cachix/pre-commit-hooks.nix";

  availableDevShells =
    builtins.foldl'
      (acc: entry: acc // { "${entry}" = true; })
      { }
      (getEntriesForPath "${nixDir}/devShells" ++
        getEntriesForPath "${nixDir}/devenvs");

  # preCommitPath is the default path for the pre-commit configuration
  preCommitPath = nixDir + "/pre-commit.nix";

  # hasPreCommitFile indicates if the standard pre-commit file is present
  hasPreCommitFile = pathExists preCommitPath;

  # doesDevShellExists check if the given devShellName is present in the
  # flake's devShells attribute-set.
  doesDevShellExist = system: devShellName:
    builtins.hasAttr devShellName availableDevShells;

  # devShellsToInject collects all the devShells that may have the pre-commit
  # script injected
  devshellsToInject = system:
    # do not validate empty case as it is impossible to create an empty
    # devShell entry using nixDir
    builtins.foldl'
      (acc: devShellName:
        # validate that the overlay we want injected in the pkgs import is not
        # used
        if doesDevShellExist system devShellName then
          acc // { "${devShellName}" = true; }
        else
          let
            availableDevShellsText =
              builtins.concatStringsSep ", " (builtins.attrNames availableDevShells);
          in
          throw ''
            nixDir is confused, it can't find the devShell `${devShellName}` in this flake's devShells set.

            Available options are: ${availableDevShellsText}
          ''
      )
      { }
      injectPreCommit;

  # shouldInjectPreCommitLib indicates if lib should include the
  # preCommitRunHook value
  shouldInjectPreCommitLib =
    hasPreCommitFile && injectPreCommit != null;

  # shouldInjectPreCommit indicates if the given shell name should have a
  # pre-commit hook injected
  shouldInjectPreCommit = system: devShellName:
    if !hasPreCommitFile then
      false
    else if builtins.typeOf injectPreCommit == "bool" then
      injectPreCommit
    else if builtins.typeOf injectPreCommit == "list" then
      builtins.hasAttr devShellName (devshellsToInject system)
    else
      throw ''
        nixDir is confused, it was expecting `injectPreCommit` to be either a boolean or a list of devShells/devenv names";
      '';

  # preCommitConfig contains the pre-commit-hooks configuration
  preCommitConfig = utils.eachSystemMapWithPkgs systems importPreCommitConfig;

  # preCommitDevShellConfig enhances the configuration for vanilla devShells
  preCommitDevShellConfig = system:
    let
      config = preCommitConfig.${system};
    in
    if !(builtins.hasAttr "src" config) then
    # If not specified, set the `src` of the pre-commit-hooks config to be
    # the root of the flake.
      config // { src = root; }
    else
      config;

  # preCommitDevenvConfig enhances the configuration for devenv devShells
  preCommitDevenvConfig = system:
    let
      config = preCommitConfig.${system};
    in
    if !(lib.hasAttrByPath [ "pre-commit" "rootSrc" ] config) then
      config // { rootSrc = root; }
    else
      config;

  preCommitDevenvModule = { pkgs, ... }:
    {
      pre-commit = preCommitDevenvConfig pkgs.system;
    };

  # preCommitRunScript prints the execution of the pre-commit script
  preCommitRunScript = system:
    pre-commit-hooks.lib.${system}.run (preCommitDevShellConfig system);

  preCommitInstallationScript = system:
    (preCommitRunScript system).shellHook;

  # preCommitInstallationScriptForShell prints the hook installation script for vanilla
  # devShells. There is no need to have a devenv version, as devenv manages it's
  # installation automatically.
  preCommitInstallationScriptForShell = system: devShellName:
    let
      run =
        pre-commit-hooks.lib.${system}.run (preCommitDevShellConfig system);
    in
    if shouldInjectPreCommit system devShellName then
      run.shellHook
    else
      "";
in

if hasPreCommitFile then
  {
    inherit hasPreCommitFile preCommitInstallationScriptForShell
      preCommitDevShellConfig
      preCommitDevenvConfig preCommitDevenvModule
      preCommitInstallationScript
      preCommitRunScript
      shouldInjectPreCommit shouldInjectPreCommitLib;
  }
else
  {
    inherit hasPreCommitFile shouldInjectPreCommit shouldInjectPreCommitLib;
  }
