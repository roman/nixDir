{ self, nixpkgs, ... } @ nixDirInputs: { inputs
                                       , root
                                       , systems
                                       , dirName ? "nix"
                                       , nixDir ? root + "/${dirName}"
                                       , pathExists ? builtins.pathExists
                                       , importFile ? (name: import name)
                                       , readDir ? builtins.readDir
                                         # overrides of importers (used in unit-tests)
                                       , importDevShells ? null
                                       , importNixtBlocks ? null
                                       , importDevenvShells ? null
                                       , importDevenvModules ? null
                                       , importPreCommitConfig ? null
                                       , importPackages ? null
                                       , importOverlays ? null
                                       , importLibs ? null
                                       , getEntriesForPath ? null
                                       , ...
                                       } @ buildFlakeCfg:

let
  inherit (nixpkgs) lib;
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;

  checkDirFileConflict = entry:
    if pathExists "${entry}/default.nix" && pathExists "${entry}.nix"
    then
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
      (lib.filterAttrs (name: ty: ty == "directory") (readDir path));

  # nixFiles returns all the ".nix" files contained in a directory
  nixFiles = path:
    builtins.attrNames (lib.filterAttrs isNixFile (readDir path));

  # nixSubDirNames returns all the sub-directories that contain a "default.nix"
  # file inside them
  nixSubDirNames = path:
    builtins.foldl'
      (acc: subdir:
        let
          files =
            lib.attrNames
              (lib.filterAttrs hasDefaultNixFile (readDir (checkDirFileConflict "${path}/${subdir}")));
        in
        if builtins.length files == 1
        then acc ++ [ subdir ]
        else acc) [ ]
      (subDirNames path);


  # importDirFiles imports nix files from a directory using various strategies:
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
  importDirFiles =
    pkgs: importStrategy: path:
    builtins.foldl'
      (acc: entryName:
      let
        # the key sometimes may be a directory name, other times it may be a
        # .nix file name. Remove the .nix suffix to standarize.
        key =
          lib.removeSuffix ".nix" entryName;
      in
      acc // {
        "${key}" =
          if importStrategy == "withCallPackage"
          then pkgs.callPackage (importFile "${path}/${entryName}" inputs) { }
          else if importStrategy == "withPkgs"
          then (importFile "${path}/${entryName}") inputs pkgs
          else if importStrategy == "withNoPkgs"
          then (importFile "${path}/${entryName}") inputs
          else if importStrategy == "nixtTest"
          then (importFile "${path}/${entryName}") inputs { inherit (inputs.nixt.lib) describe it; }
          else throw "implementation error: invalid importStrategy ${importStrategy}";
      })
      { }
      (nixSubDirNames path ++ nixFiles path);

  _getEntriesForPath = path:
    if getEntriesForPath != null then
      getEntriesForPath path
    else if pathExists path then
      builtins.map
        (lib.removeSuffix ".nix")
        (nixSubDirNames path ++ nixFiles path)
    else
      [ ];

  _importPreCommitConfig =
    pkgs: importFile (nixDir + "/pre-commit.nix") inputs pkgs;

  # importPackages is used to import the nixDir/packages directory
  _importPackages =
    pkgs: importDirFiles pkgs "withCallPackage" (nixDir + "/packages");

  # _importDevShells is used to import the nixDir/devShells directory
  _importDevShells =
    pkgs: importDirFiles pkgs "withPkgs" (nixDir + "/devShells");

  # _importDevenvModules is used to import the nixDir/modules/devenv directory
  _importDevenvModules =
    importDirFiles null "withNoPkgs" (nixDir + "/modules/devenv");

  # _importDevenvShells is used to import the nixDir/devenvs directory
  _importDevenvShells =
    importDirFiles null "withNoPkgs" (nixDir + "/devenvs");


  _importOverlays =
    importFile (nixDir + "/overlays.nix") inputs;

  # importNixtBlocks is used to import the nixDir/tests/nixt directory
  _importNixtBlocks =
    let
      path = nixDir + "/tests/nixt";
      block = nixDirInputs.nixt.lib.block;
      testPerFile = importDirFiles null "nixtTest" path;
      toPath = s: path + s;
      nixtBlocks =
        builtins.foldl'
          (acc: fileName:
            # construct a list of TestSuite in the situation the file exports a
            # single TestSuite
            if builtins.typeOf testPerFile.${fileName} != "list" then
              acc ++ [{ path = toPath "/${fileName}.nix"; suites = [ testPerFile.${fileName} ]; }]
            else
              acc ++ [{ path = toPath "/${fileName}.nix"; suites = testPerFile.${fileName}; }])
          [ ]
          (builtins.attrNames testPerFile);
    in
    nixtBlocks;
in
{

  importDevShells =
    if importDevShells == null then
      _importDevShells
    else
      importDevShells;

  importDevenvShells =
    if importDevenvShells == null then
      _importDevenvShells
    else
      importDevenvShells;

  importDevenvModules =
    if importDevenvModules == null then
      _importDevenvModules
    else
      importDevenvModules;

  importPreCommitConfig =
    if importPreCommitConfig == null then
      _importPreCommitConfig
    else
      importPreCommitConfig;

  importPackages =
    if importPackages == null then
      _importPackages
    else
      importPackages;

  importOverlays =
    if importOverlays == null then
      _importOverlays
    else
      importOverlays;

  importNixtBlocks =
    if importNixtBlocks == null then
      _importNixtBlocks
    else
      importNixtBlocks;

  getEntriesForPath = _getEntriesForPath;
}
