{ pkgs, lib, inputs, importFile ? import, readDir ? builtins.readDir
, pathExists ? builtins.pathExists, }:
let
  # checkDirFileConflict checks if there are conflicting entries for a package
  # definition.
  checkDirFileConflict = entry:
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
  subDirNames = path:
    builtins.attrNames
    (lib.filterAttrs (_name: ty: ty == "directory") (readDir path));

  # nixFiles returns all the ".nix" files contained in a directory.
  nixFiles = path:
    builtins.attrNames (lib.filterAttrs isNixFile (readDir path));

  # nixSubDirNames traverses each subdirectory looking for a default.nix file.
  nixSubDirNames = path:
    builtins.foldl' (acc: subdir:
      let
        files = lib.attrNames (lib.filterAttrs hasDefaultNixFile
          (readDir (checkDirFileConflict "${path}/${subdir}")));
      in if builtins.length files == 1 then acc ++ [ subdir ] else acc) [ ]
    (subDirNames path);

  # scopeInputsToSystem scopes flake inputs to a specific system.
  # For any attribute in an input that has a ${system} key, it extracts that value.
  # This transforms inputs.foo.packages.${system}.bar -> inputs.foo.packages.bar
  scopeInputsToSystem = system: inputs:
    lib.mapAttrs (name: input:
      lib.mapAttrs (outputName: outputValue:
        if builtins.isAttrs outputValue && outputValue ? ${system} then
          outputValue.${system}
        else
          outputValue) input) inputs;

  dirCallPackage = path:
    builtins.foldl' (acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
      in acc // { "${key}" = pkgs.callPackage "${path}/${entryName}" { }; }) { }
    (nixSubDirNames path ++ nixFiles path);

  # importPackages traverses each file/subdirectory in the given path looking for a
  # package configuration.
  importPackages = dirCallPackage;

  # importDirWithoutInputs imports files from a directory without passing inputs.
  # The imported files should be plain attribute sets or functions expecting module args.
  importDirWithoutInputs = path:
    builtins.foldl' (acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
      in acc // { "${key}" = importFile "${path}/${entryName}"; }) { }
    (nixSubDirNames path ++ nixFiles path);

  # importDir is a smart importer that automatically detects if imported files
  # expect inputs or not. It scopes inputs to the current system for cleaner module code.
  # - Files with signature `inputs: { pkgs, ... }: ...` get scoped inputs
  # - Files with signature `{ pkgs, ... }: ...` work as-is
  importDir = path:
    let scopedInputs = scopeInputsToSystem pkgs.system inputs;
    in builtins.foldl' (acc: entryName:
      let
        key = lib.removeSuffix ".nix" entryName;
        imported = importFile "${path}/${entryName}";
        # Try to call with scoped inputs first
        withInputsResult = builtins.tryEval (imported scopedInputs);
        # If successful, use the result (a function expecting moduleArgs)
        # If failed, use the original import (already a function expecting moduleArgs)
        finalValue =
          if withInputsResult.success then withInputsResult.value else imported;
      in acc // { "${key}" = finalValue; }) { }
    (nixSubDirNames path ++ nixFiles path);

  importDirWithInputs = path:
    builtins.foldl' (acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key = lib.removeSuffix ".nix" entryName;
      in acc // { "${key}" = importFile "${path}/${entryName}" inputs; }) { }
    (nixSubDirNames path ++ nixFiles path);

  # importDevenvs traverses each file in the given path looking for a devenv
  # configuration.
  importDevenvs = path:
    lib.mapAttrs (name: attrs:
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
        attrs) (importDir path);

  # importNixOSModules traverses each file in the given path looking for a NixOS
  # configuration.
  importNixOSModules = importDir;

  # importNixOSConfigurations traverses each file in the given path looking for a NixOS
  # configuration.
  importNixOSConfigurations = path: lib.mapAttrs (_name: attrs:
    inputs.nixpkgs.lib.nixosSystem
    (attrs // { specialArgs = { inherit inputs; }; }))
    (importDirWithInputs path);

  # importDarwinModules traverses each file in the given path looking for a nix-darwin
  # configuration.
  importDarwinModules = importDir;

  # importNixDarwinConfigurations traverses each file in the given path looking for a
  # nix-darwin configuration.
  importDarwinConfigurations = path:
    lib.mapAttrs (name: attrs:
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
        inputs.nix-darwin.lib.darwinSystem
        (attrs // { specialArgs = { inherit inputs; }; }))
    (importDirWithInputs path);

  # importHomeManagerModules traverses each file in the given path looking for a
  # home-manager configuration.
  importHomeManagerModules = importDir;

  # importDevenvModules traverses each file in the given path looking for a
  # devenv configuration.
  importDevenvModules = importDir;
in {
  inherit importPackages importDevenvs importNixOSModules
    importNixOSConfigurations importDarwinModules importDarwinConfigurations
    importHomeManagerModules importDevenvModules importDirWithoutInputs
    importDir importDirWithInputs scopeInputsToSystem;
}
