{
  pkgs,
  lib,
  inputs,
  importFile ? import,
  readDir ? builtins.readDir,
  pathExists ? builtins.pathExists,
  importWithInputs ? false,
  strictDiscovery ? false,
  followSymlinks ? false,
  maxDepth ? 3,
}:
let
  constants = import ./constants.nix;
  inherit (constants) strategies discoveryErrors;

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

  # nixFiles returns all the ".nix" files contained in a directory.
  nixFiles = path: builtins.attrNames (lib.filterAttrs isNixFile (readDir path));

  # isHiddenDir checks if a directory name starts with "."
  isHiddenDir = name: lib.hasPrefix "." name;

  # hasBlockingFile checks if a sibling .nix file blocks directory traversal.
  # e.g., foo.nix blocks traversal into foo/ (but not foo/default.nix leaf discovery)
  hasBlockingFile = path: dirName: pathExists "${path}/${dirName}.nix";

  # deriveDisplayPath extracts a relative display path from a Nix store path.
  # Store paths follow: /nix/store/{32-char-hash}-{name}/{relative-path}
  # Returns "./{relative-path}" for error messages.
  deriveDisplayPath =
    path:
    let
      pathStr = toString path;
      afterStore = lib.removePrefix "/nix/store/" pathStr;
      parts = lib.splitString "/" afterStore;
      relativePath = lib.concatStringsSep "/" (lib.tail parts);
    in
    "./${relativePath}";

  # formatIgnored formats a list of ignored items for error messages.
  # Uses structured reason records with type field for pattern matching.
  formatIgnored =
    displayRoot: ignored:
    lib.concatMapStringsSep "\n" (
      item:
      let
        reasonStr =
          if item.reason.type == discoveryErrors.blocked then
            "blocked by ${displayRoot}/${item.reason.blockingFile}"
          else if item.reason.type == discoveryErrors.depthExceeded then
            "depth exceeded (maxDepth=${toString item.reason.maxDepth})"
          else
            "unknown reason";
      in
      "  - ${displayRoot}/${item.path} (${reasonStr})"
    ) ignored;

  # validateDiscovery checks if any items were ignored and throws in strict mode.
  # Derives display path from outputRoot store path.
  validateDiscovery =
    outputRoot: result:
    let
      displayRoot = deriveDisplayPath outputRoot;
      reasonTypes = lib.unique (map (item: item.reason.type) result.ignored);
      hasBlocked = builtins.elem discoveryErrors.blocked reasonTypes;
      hasDepthExceeded = builtins.elem discoveryErrors.depthExceeded reasonTypes;

      recommendations = lib.concatStringsSep "\n" (
        lib.optional hasBlocked "- Remove the blocking .nix file or rename the directory"
        ++ lib.optional hasDepthExceeded "- Increase maxDepth if they are too deeply nested"
        ++ [ "- Set nixDir.strictDiscovery = false to allow silent ignoring" ]
      );
    in
    if strictDiscovery && result.ignored != [ ] then
      throw ''
        nixDir: strictDiscovery is enabled but some directories were ignored.

        The following were not discovered in ${displayRoot}:
        ${formatIgnored displayRoot result.ignored}

        Either:
        ${recommendations}
      ''
    else
      result.discovered;

  # discoverDirsWithFlakeOutputs recursively finds directories containing default.nix files.
  # Works for all output types: packages, modules, configurations, devshells, etc.
  #
  # Arguments:
  #   - outputRoot: the output directory being imported (e.g., "nix/packages/", "nix/modules/nixos/")
  #   - currentPath: current directory being scanned (starts at outputRoot)
  #   - pathFromRoot: accumulated path from outputRoot (e.g., "tools/cli" for packages/tools/cli/)
  #   - depth: current nesting depth (0 at outputRoot)
  #
  # Returns { discovered, ignored } where:
  #   - discovered: list of { name, pathFromRoot }
  #   - ignored: list of { path, reason } for items that were skipped
  #
  # Leaf rule: directory with default.nix is a leaf (entry found, don't recurse deeper).
  # Conflict check: errors if both foo/default.nix and foo.nix exist at same level.
  discoverDirsWithFlakeOutputs =
    {
      outputRoot,
      currentPath,
      pathFromRoot ? "",
      depth ? 0,
    }:
    let
      contents = readDir currentPath;
      isDirectoryEntry =
        name: type:
        type == "directory"
        || (followSymlinks && type == "symlink" && pathExists "${currentPath}/${name}/.");
      dirs = lib.filterAttrs isDirectoryEntry contents;
      dirNames = builtins.attrNames dirs;
      visibleDirs = builtins.filter (n: !isHiddenDir n) dirNames;

      processDir =
        dirName:
        let
          dirPath = "${currentPath}/${dirName}";
          newPathFromRoot = if pathFromRoot == "" then dirName else "${pathFromRoot}/${dirName}";
          hasDefaultNix = pathExists "${dirPath}/default.nix";
          isBlockedByFile = hasBlockingFile currentPath dirName;
          # Check for conflict: foo/default.nix AND foo.nix at same level
          checkedPath = checkDirFileConflict dirPath;
        in
        # Depth exceeded - track as ignored, scan for nested default.nix to report
        if depth >= maxDepth then
          let
            # Check if there are any default.nix files in this subtree that would be ignored
            hasNestedPackages = pathExists "${dirPath}/default.nix";
          in
          {
            discovered = [ ];
            ignored =
              if hasNestedPackages then
                [
                  {
                    path = newPathFromRoot;
                    reason = {
                      type = discoveryErrors.depthExceeded;
                      inherit maxDepth;
                    };
                  }
                ]
              else
                [ ];
          }
        # Blocked by sibling file (foo.nix blocks foo/) - track as ignored if has packages
        else if isBlockedByFile then
          let
            # Scan the blocked directory for any default.nix that would be ignored
            scanBlocked =
              scanPath:
              let
                blockedContents = readDir scanPath;
                blockedDirs = lib.filterAttrs (_: t: t == "directory") blockedContents;
              in
              if pathExists "${scanPath}/default.nix" then
                true
              else
                builtins.any (d: scanBlocked "${scanPath}/${d}") (builtins.attrNames blockedDirs);
            hasBlockedPackages = scanBlocked dirPath;
          in
          {
            discovered = [ ];
            ignored =
              if hasBlockedPackages then
                [
                  {
                    path = newPathFromRoot;
                    reason = {
                      type = discoveryErrors.blocked;
                      blockingFile = "${newPathFromRoot}.nix";
                    };
                  }
                ]
              else
                [ ];
          }
        # Leaf directory (has default.nix) - discovered, don't recurse deeper
        # The checkedPath evaluation triggers the conflict check
        else if hasDefaultNix then
          builtins.seq checkedPath {
            discovered = [
              {
                name = dirName;
                pathFromRoot = newPathFromRoot;
              }
            ];
            ignored = [ ];
          }
        # Organizational directory - recurse
        else
          discoverDirsWithFlakeOutputs {
            inherit outputRoot;
            currentPath = dirPath;
            pathFromRoot = newPathFromRoot;
            depth = depth + 1;
          };

      results = map processDir visibleDirs;
    in
    {
      discovered = builtins.concatLists (map (r: r.discovered) results);
      ignored = builtins.concatLists (map (r: r.ignored) results);
    };

  # nixSubDirNames traverses subdirectories recursively looking for default.nix files.
  # Returns list of { name, pathFromRoot } records for directories containing default.nix.
  # In strict mode, throws if any directories were ignored.
  nixSubDirNames =
    path:
    validateDiscovery path (discoverDirsWithFlakeOutputs {
      outputRoot = path;
      currentPath = path;
    });

  # mkImportDir creates an import function that discovers and imports files from a directory.
  # This is the core building block - takes a single-file import function and applies it
  # to all discovered files/directories.
  mkImportDir =
    importFn: path:
    let
      fromDirs = builtins.listToAttrs (
        map (entry: {
          name = entry.name;
          value = importFn "${path}/${entry.pathFromRoot}";
        }) (nixSubDirNames path)
      );

      fromFiles = builtins.listToAttrs (
        map (fileName: {
          name = lib.removeSuffix ".nix" fileName;
          value = importFn "${path}/${fileName}";
        }) (nixFiles path)
      );
    in
    fromDirs // fromFiles;

  # importByStrategy creates an import function based on strategy and withInputs flag.
  # This single function replaces 18 import* functions from the old importer.
  importByStrategy =
    { strategy, withInputs }:
    let
      importFn =
        if strategy == strategies.callPackage then
          if withInputs then p: pkgs.callPackage (importFile p inputs) { } else p: pkgs.callPackage p { }
        else if strategy == strategies.passPkgs then
          if withInputs then p: importFile p inputs pkgs else p: importFile p pkgs
        else if strategy == strategies.plain then
          if withInputs then p: importFile p inputs else importFile
        else
          throw "nixDir: unknown import strategy '${strategy}'";
    in
    mkImportDir importFn;

  # Backward-compatible import functions using the new generic approach
  dirCallPackage = importByStrategy {
    strategy = strategies.callPackage;
    withInputs = false;
  };

  importDirWithoutInputs = importByStrategy {
    strategy = strategies.plain;
    withInputs = false;
  };

  importDirWithInputs = importByStrategy {
    strategy = strategies.plain;
    withInputs = true;
  };

  importDevShells = importByStrategy {
    strategy = strategies.passPkgs;
    withInputs = false;
  };

  importDevShellsWithInputs = importByStrategy {
    strategy = strategies.passPkgs;
    withInputs = true;
  };

  importPackagesWithInputs = importByStrategy {
    strategy = strategies.callPackage;
    withInputs = true;
  };

  # Wrapper for devenvs that validates devenv input exists
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

  importDevenvs = _importDevenvs importDirWithoutInputs;
  importDevenvsWithInputs = _importDevenvs importDirWithInputs;

  # Wrapper for NixOS configurations
  _importNixOSConfigurations =
    innerImporter: path:
    lib.mapAttrs (
      _name: attrs: inputs.nixpkgs.lib.nixosSystem (attrs // { specialArgs = { inherit inputs; }; })
    ) (innerImporter path);

  importNixOSConfigurations = _importNixOSConfigurations importDirWithoutInputs;
  importNixOSConfigurationsWithInputs = _importNixOSConfigurations importDirWithInputs;

  # Wrapper for Darwin configurations with input validation
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

  importDarwinConfigurations = _importDarwinConfigurations importDirWithoutInputs;
  importDarwinConfigurationsWithInputs = _importDarwinConfigurations importDirWithInputs;

  # Aliases for type-specific imports (all use the same underlying function)
  importPackages = dirCallPackage;
  importNixOSModules = importDirWithoutInputs;
  importNixOSModulesWithInputs = importDirWithInputs;
  importDarwinModules = importDirWithoutInputs;
  importDarwinModulesWithInputs = importDirWithInputs;
  importHomeManagerModules = importDirWithoutInputs;
  importHomeManagerModulesWithInputs = importDirWithInputs;
  importDevenvModules = importDirWithoutInputs;
  importDevenvModulesWithInputs = importDirWithInputs;
in
{
  # Export the new generic functions
  inherit mkImportDir importByStrategy;

  # When importWithInputs is true, all regular import functions use the WithInputs variants
  importPackages = if importWithInputs then importPackagesWithInputs else importPackages;
  importNixOSModules = if importWithInputs then importNixOSModulesWithInputs else importNixOSModules;
  importDevenvs = if importWithInputs then importDevenvsWithInputs else importDevenvs;
  importNixOSConfigurations =
    if importWithInputs then importNixOSConfigurationsWithInputs else importNixOSConfigurations;
  importDarwinModules =
    if importWithInputs then importDarwinModulesWithInputs else importDarwinModules;
  importDarwinConfigurations =
    if importWithInputs then importDarwinConfigurationsWithInputs else importDarwinConfigurations;
  importHomeManagerModules =
    if importWithInputs then importHomeManagerModulesWithInputs else importHomeManagerModules;
  importDevenvModules =
    if importWithInputs then importDevenvModulesWithInputs else importDevenvModules;
  importDevShells = if importWithInputs then importDevShellsWithInputs else importDevShells;
  importDir = if importWithInputs then importDirWithInputs else importDirWithoutInputs;

  # Keep WithInputs variants available for with-inputs/ directory support
  inherit
    importPackagesWithInputs
    importNixOSModulesWithInputs
    importDevenvsWithInputs
    importNixOSConfigurationsWithInputs
    importDarwinModulesWithInputs
    importDarwinConfigurationsWithInputs
    importHomeManagerModulesWithInputs
    importDevenvModulesWithInputs
    importDevShellsWithInputs
    importDirWithoutInputs
    importDirWithInputs
    ;
}
