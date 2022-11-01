nixDirInputs: let
  # getPkgs returns the nixpkgs repository for the given system with embedded
  # overlays from the input flake.
  getPkgs = system: {
    self,
    nixpkgs,
    ...
  }:
    if self ? overlays
    then
      import nixpkgs {
        inherit system;
        overlays =
          builtins.attrValues
          # remove default as it usually contains packages built by this flake
          (builtins.removeAttrs self.overlays ["default"]);
      }
    else
      import nixpkgs {
        inherit system;
      };

  # runPreCommit
  runPreCommit = root: inputs: pkgs: let
    inherit (pkgs) system;
    config =
      # using callPackage returns extra fields that we don't want included
      # in the config record
      builtins.removeAttrs
      (pkgs.callPackage (import "${root}/pre-commit.nix" system inputs) {})
      ["override" "overrideDerivation"];
  in
    nixDirInputs.pre-commit-hooks.lib.${system}.run config;

  # eachDefaultSystemMapWithPkgs
  eachSystemMapWithPkgs = systems: inputs: f:
    nixDirInputs.utils.lib.eachSystemMap systems (system: f (getPkgs system inputs));

  # dirAndFilesToAttrSet
  dirAndFilesToAttrSet = inputs: pkgs: path: let
    inherit (pkgs) system lib callPackage;

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
          dirNix is confused, it found two conflicting entries; one is a directory (${entry}/default.nix), and the other a file (${entry}.nix), please remove one of them.
        ''
      else entry;

    nixSubDirNames = builtins.foldl' (acc: subdir: let
      files =
        lib.attrNames
        (lib.filterAttrs hasDefaultNix (builtins.readDir (checkDirFileConflict "${path}/${subdir}")));
    in
      if builtins.length files == 1
      then acc ++ [subdir]
      else acc) []
    subDirNames;

    entries = builtins.foldl' (acc: entryName: let
      # the key sometimes may be a directory name, other times it may be a
      # .nix file name. Remove the .nix suffix to standarize.
      key =
        lib.removeSuffix ".nix" entryName;
    in
      acc
      // {
        "${key}" =
          callPackage (import "${path}/${entryName}" system inputs) {};
      }) {} (nixSubDirNames ++ nixFiles);
  in
    entries;
  #
  # dirToAttrSet
  dirToAttrSet = inputs: path: let
    inherit (inputs.nixpkgs) lib;

    hasDefaultNix = name: ty: ty == "regular" && name == "default.nix";

    subDirNames =
      builtins.attrNames
      (lib.filterAttrs (name: ty: ty == "directory") (builtins.readDir path));

    nixSubDirNames = builtins.foldl' (acc: subdir: let
      files =
        lib.attrNames
        (lib.filterAttrs hasDefaultNix (builtins.readDir "${path}/${subdir}"));
    in
      if builtins.length files == 1
      then acc ++ [subdir]
      else acc) []
    subDirNames;

    entries = builtins.foldl' (acc: entryName:
      acc
      // {
        "${entryName}" =
          import "${path}/${entryName}" inputs;
      }) {}
    nixSubDirNames;
  in
    entries;

  buildFlake = {
    dirName ? "nix",
    injectPreCommit ? true,
    root,
    systems,
    inputs,
  }: let
    nixDir = "${root}/${dirName}";

    applyOutput = check: entry: outputs:
      if check
      then outputs // entry
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
        packages =
          eachSystemMapWithPkgs systems inputs (pkgs: dirAndFilesToAttrSet inputs pkgs "${nixDir}/packages");
      };

    applyNixOSModules =
      applyOutput
      (builtins.pathExists "${nixDir}/nixos-modules")
      {nixosModules = dirToAttrSet inputs "${nixDir}/nixos-modules";};

    applyHomeManagerModules =
      applyOutput
      (builtins.pathExists "${nixDir}/hm-modules")
      {homeManagerModules = dirToAttrSet inputs "${nixDir}/hm-modules";};

    applyDevShells = let
      hasPreCommit = builtins.pathExists "${nixDir}/pre-commit.nix";
    in
      applyOutput
      (builtins.pathExists "${nixDir}/devShells")
      {
        devShells = eachSystemMapWithPkgs systems inputs (
          pkgs: let
            devShells = dirAndFilesToAttrSet inputs pkgs "${nixDir}/devShells";
          in
            if hasPreCommit && injectPreCommit
            then let
              preCommitRunHook = (runPreCommit nixDir inputs pkgs).shellHook;
            in
              pkgs.lib.mapAttrs
              (_: val:
                val.overrideAttrs
                (final: prev: {
                  shellHook = prev.shellHook + preCommitRunHook;
                }))
              devShells
            else devShells
        );
      };
  in
    builtins.foldl' (outputs: apply: apply outputs) {}
    # IMPORTANT: don't change the order of this apply functions unless is
    # truly necessary
    [applyDevShells applyPackages applyHomeManagerModules applyNixOSModules applyLib applyOverlay];
in {
  inherit buildFlake;
}