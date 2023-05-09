{ nixpkgs, ... } @ nixDirInputs: {
  inputs
, systems
, root
, dirName ? "nix"
, nixDir ? "${root}/${dirName}"
, injectDevenvModules
, pathExists ? builtins.pathExists
, ...
} @ buildFlakeCfg:

let
  precommit = import ./precommit.nix nixDirInputs buildFlakeCfg;
  importer = import ./importer.nix nixDirInputs buildFlakeCfg;
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;

  inherit (nixpkgs) lib;
  inherit (precommit) shouldInjectPreCommit;
  inherit (utils) applyFlakeOutput eachSystemMapWithPkgs;
  inherit (importer) importDevenvShells importDevenvModules;

  allDevenvModules = importDevenvModules;

  # getDevenvModule fetches the devenvModule from all the available
  # devenvModules and fails hard if an unknown name is given.
  getDevenvModule = moduleName:
    if builtins.typeOf moduleName == "string" then
      if lib.hasAttr moduleName allDevenvModules then
        allDevenvModules.${moduleName}
      else
        let
          availableDevenvModules =
            lib.concatStringsSep ", "
              (lib.attrNames allDevenvModules);
        in
          throw ''
            nixDir is confused, it can't find the devenv module `${moduleName}` in this flake's nix/modules/devenv directory.

            Available modules are: ${availableDevenvModules}
          ''
      else
        throw "what that fukc is going on?";

  # devenvShellModules are all the modules that will get included in the devenv
  # configuration.
  devenvShellModules =
    if builtins.typeOf injectDevenvModules == "bool" then
      if injectDevenvModules then
        builtins.attrValues allDevenvModules
      else
        []
    else if builtins.typeOf injectDevenvModules == "list" then
      builtins.foldl'
        (acc: moduleName:
          let
            module = getDevenvModule moduleName;
          in
            acc ++ [module])
        []
        injectDevenvModules
    else
        let
          availableDevenvModules =
            lib.concatStringsSep ", "
              (lib.attrNames allDevenvModules);
        in
          throw ''
            nixDir is confused; it was expecting `injectDevenvModules` to be either a boolean or a list of strings, got ${builtins.toString injectDevenvModules} instead.

            Available modules are: ${availableDevenvModules}
          '';

  # applyDevenvModules injects the devenvModules output in the flake
  applyDevenvModules =
    applyFlakeOutput
      (pathExists "${nixDir}/modules/devenv")
      {
        devenvModules = allDevenvModules;
      };

  # applyDevenvShells injects the devShells output in the flake with devenv profiles
  applyDevenvShells =
    applyFlakeOutput
      (pathExists "${nixDir}/devenvs")
      (final: {
        devShells = eachSystemMapWithPkgs systems (pkgs:
          let
            devenvConfigs = importDevenvShells;

            mkDevenvShell = modules:
              nixDirInputs.devenv.lib.mkShell {
                inherit pkgs modules inputs;
              };

            step = acc: devenvName:
              let
                # devenvBaseModule represents a nix/devenvs/$name entry
                devenvBaseModule =
                  if
                    (pathExists "${nixDir}/devShells/${devenvName}")
                    || (pathExists "${nixDir}/devShells/${devenvName}.nix")
                  then
                    throw ''
                        nixDir is confused, it found two conflicting files/directories.

                        One is an entry in `devShells/${devenvName}` and the other is `devenvs/${devenvName}`.

                        Please remove one of the entries to avoid conflicts.
                    ''
                  else
                    devenvConfigs.${devenvName};

                preCommitInjected = shouldInjectPreCommit pkgs.system devenvName;

                # devenvModulesSpec contains the list of all possible devenv
                # modules that could get injected in the final devenv profile
                devenvModulesSpec =
                  [
                    { apply = true; module = devenvBaseModule; }
                    { apply = preCommitInjected;
                      module = {pkgs, ...}:
                        precommit.preCommitDevenvConfig pkgs.system; }
                  ]
                  ++ builtins.map (module: { apply = true; module = module; }) devenvShellModules;

                # devenvModules contains the list of all devenv modules that
                # will get injected in the final devenv profile
                devenvModules =
                  builtins.foldl'
                    (acc: spec:
                      if spec.apply then
                        acc ++ [ spec.module ]
                      else
                        acc)
                    []
                    devenvModulesSpec;
              in
                acc // {
                  "${devenvName}" =
                    (mkDevenvShell devenvModules)
                    // { nixDirPreCommitInjected = preCommitInjected; };
                };
          in
            builtins.foldl' step {} (builtins.attrNames devenvConfigs)
        );
      });
in
{
  inherit applyDevenvShells applyDevenvModules;
}
