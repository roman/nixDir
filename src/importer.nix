{
  pkgs,
  lib,
  inputs,
  importFile ? import,
  readDir ? builtins.readDir,
  pathExists ? builtins.pathExists,
}:
let
  # checkDirFileConflict checks if there are conflicting entries for a package
  # definition.
  checkDirFileConflict =
    entry:
    if pathExists "${entry}/default.nix" && pathExists "${entry}.nix" then
      throw ''
        nixDir is confused, it found two conflicting entries.
              
        One is a directory (${entry}/default.nix), and the other a file (${entry}.nix).
                      
        Please remove one of the two.
      ''
    else
      entry;

  # isNixFile verifies a filename ends with a ".nix" suffix
  isNixFile = name: ty: ty == "regular" && lib.hasSuffix ".nix" name;

  # hasDefaultNixFile verifies a filename is called default.nix
  hasDefaultNixFile = name: ty: ty == "regular" && name == "default.nix";

  # subDirNames returns the names of the sub-directories contained in the given
  # path
  subDirNames =
    path: builtins.attrNames (lib.filterAttrs (_name: ty: ty == "directory") (readDir path));

  # nixFiles returns all the ".nix" files contained in a directory.
  nixFiles = path: builtins.attrNames (lib.filterAttrs isNixFile (readDir path));

  # nixSubDirNames traverses each subdirectory looking for a default.nix file.
  nixSubDirNames =
    path:
    builtins.foldl' (
      acc: subdir:
      let
        files = lib.attrNames (
          lib.filterAttrs hasDefaultNixFile (readDir (checkDirFileConflict "${path}/${subdir}"))
        );
      in
      if builtins.length files == 1 then acc ++ [ subdir ] else acc
    ) [ ] (subDirNames path);

  dirCallPackage =
    path:
    builtins.foldl' (
      acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
      in
      acc // { "${key}" = pkgs.callPackage "${path}/${entryName}" { }; }
    ) { } (nixSubDirNames path ++ nixFiles path);

  # importPackages traverses each file/subdirectory in the given path looking for a
  # package configuration.
  importPackages = dirCallPackage;

  # importDirWithoutInputs imports files from a directory without passing inputs.
  # The imported files should be plain attribute sets or functions expecting module args.
  importDirWithoutInputs =
    path:
    builtins.foldl' (
      acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
      in
      acc // { "${key}" = importFile "${path}/${entryName}"; }
    ) { } (nixSubDirNames path ++ nixFiles path);

  # importDir imports files that expect standard module arguments.
  # For modules that need flake inputs, use with-inputs/ directory structure.
  importDir = importDirWithoutInputs;

  importDirWithInputs =
    path:
    builtins.foldl' (
      acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
      in
      acc // { "${key}" = importFile "${path}/${entryName}" inputs; }
    ) { } (nixSubDirNames path ++ nixFiles path);

  _importDevenvs =
    innerImporter: path:
    lib.mapAttrs (
      name: attrs:
      if !(inputs ? devenv) then
        throw ''
          nixDir detected a devenv/${name} entry, but devenv is not in the flake inputs.

          Please include devenv to your flake inputs:

          {
            inputs = {
                   # ...
                   devenv.url = "github:cachix/devenv";
            };
          }
        ''
      else
        attrs
    ) (innerImporter path);

  # importDevenvs traverses each file in the given path looking for a devenv configuration.
  importDevenvs = _importDevenvs importDir;

  # importDevenvsWithInputs for with-inputs/ directory.
  importDevenvsWithInputs = _importDevenvs importDirWithInputs;

  # importNixOSModules traverses each file in the given path looking for a NixOS
  # configuration.
  importNixOSModules = importDir;

  # importNixOSModulesWithInputs for with-inputs/ directory.
  importNixOSModulesWithInputs = importDirWithInputs;

  _importNixOSConfigurations =
    innerImporter: path:
    lib.mapAttrs (
      _name: attrs: inputs.nixpkgs.lib.nixosSystem (attrs // { specialArgs = { inherit inputs; }; })
    ) (innerImporter path);

  # importNixOSConfigurations traverses each file in the given path looking for a NixOS
  # configuration. Regular (portable) version - files return { system, modules, ... }
  importNixOSConfigurations = _importNixOSConfigurations importDir;

  # importNixOSConfigurationsWithInputs for with-inputs/ directory.
  # Files have signature: inputs: { system, modules, ... }
  importNixOSConfigurationsWithInputs = _importNixOSConfigurations importDirWithInputs;

  # importDarwinModules traverses each file in the given path looking for a nix-darwin
  # configuration.
  importDarwinModules = importDir;

  # importDarwinModulesWithInputs for with-inputs/ directory.
  # Files have signature: inputs: { system, modules, ... }
  importDarwinModulesWithInputs = importDirWithInputs;

  _importDarwinConfigurations =
    innerImporter: path:
    lib.mapAttrs (
      name: attrs:
      if !(inputs ? nix-darwin) then
        throw ''
          nixDir detected a configurations/darwin/${name} entry, but nix-darwin is not in the flake inputs.

          Please include nix-darwin to your flake inputs:

          {
            inputs = {
                   # ...
                   nix-darwin.url = "github:LnL7/nix-darwin";
            };
          }
        ''
      else
        inputs.nix-darwin.lib.darwinSystem (attrs // { specialArgs = { inherit inputs; }; })
    ) (innerImporter path);

  # importDarwinConfigurations traverses each file in the given path looking for a
  # nix-darwin configuration. Regular (portable) version - files return { system, modules, ... }
  importDarwinConfigurations = _importDarwinConfigurations importDir;

  # importDarwinConfigurationsWithInputs for with-inputs/ directory.
  # Files have signature: inputs: { system, modules, ... }
  importDarwinConfigurationsWithInputs = _importDarwinConfigurations importDirWithInputs;

  # importHomeManagerModules traverses each file in the given path looking for a
  # home-manager configuration.
  importHomeManagerModules = importDir;

  # importHomeManagerModulesWithInputs for with-inputs/ directory.
  # Files have signature: inputs: { system, modules, ... }
  importHomeManagerModulesWithInputs = importDirWithInputs;

  # importDevenvModules traverses each file in the given path looking for a
  # devenv configuration.
  importDevenvModules = importDir;

  # importDevShells traverses each file in the given path looking for a devShell
  # configuration. Files have signature: pkgs: mkShell { ... }
  importDevShells =
    path:
    builtins.foldl' (
      acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
        # Import the file and call it with pkgs only (portable)
        shell = importFile "${path}/${entryName}" pkgs;
      in
      acc // { "${key}" = shell; }
    ) { } (nixSubDirNames path ++ nixFiles path);

  # importDevShellsWithInputs traverses each file in the given path looking for a devShell
  # configuration. Files have signature: inputs: pkgs: mkShell { ... }
  importDevShellsWithInputs =
    path:
    builtins.foldl' (
      acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
        # Import the file and call it with inputs and pkgs
        shell = importFile "${path}/${entryName}" inputs pkgs;
      in
      acc // { "${key}" = shell; }
    ) { } (nixSubDirNames path ++ nixFiles path);
in
{
  inherit
    importPackages
    importNixOSModules
    importNixOSModulesWithInputs
    importDevenvs
    importDevenvsWithInputs
    importNixOSConfigurations
    importNixOSConfigurationsWithInputs
    importDarwinModules
    importDarwinModulesWithInputs
    importDarwinConfigurations
    importDarwinConfigurationsWithInputs
    importHomeManagerModules
    importHomeManagerModulesWithInputs
    importDevenvModules
    importDevShells
    importDevShellsWithInputs
    importDirWithoutInputs
    importDir
    importDirWithInputs
    ;
}
