{ self, nixpkgs, ...} @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  systems = [ system ];

  pathExists_preCommitPresent = path:
    (builtins.match ".*devenvs.*" (builtins.toString path)) == null;

  pathExists_devenvConflictEntry = name: path:
    (lib.hasSuffix "nix/devenvs/${name}.nix" path
     || lib.hasSuffix "nix/devShells" path);

  pathExists_noPreCommit = path:
    # ignore devenvs profiles
    (builtins.match ".*devenvs.*" (builtins.toString path) == null) &&
    # ignore pre-commit.nix file
    (!lib.hasSuffix "pre-commit.nix" path);

  mkBuildFlakeCfg = {
    devShellNames,
    injectPreCommit,
    pathExists
  }:
    let
      # root config for nixDir.lib.buildFlake call
      root = ./.;

      # use x86_64-linux architecture as our standard pkgs
      pkgs = import nixpkgs { inherit system; };

      # utility function to construct shells
      mkDevShell = name: pkgs:
        pkgs.mkShell  {
          shellHook = "echo ${name}";
        };

      # map that contains the direct result of importDevShells as well as
      # the value inside the self input
      importDevShells = pkgs:
        builtins.foldl'
          (acc: name: acc // { "${name}" = mkDevShell name pkgs; })
          {}
          devShellNames;

      # parameter used inside the buildFlake configuration, mock
      # it as not to require a real flake to test code
      inputs = {
        inherit nixpkgs;
        self = {
          devShells.${system} = importDevShells pkgs;
        };
      };
    in
      # configuration value used in the nixDir.lib.buildFlake call
      {
        root = ./.;
        # parameters usually provided by flake authors in the
        # nixDir.lib.buildFlake call
        inherit inputs systems injectPreCommit;
        # override functions for unit-test
        inherit importDevShells pathExists;
      };

  specs =
    [
      {
        it = "generates a devShell entry when files are present in the nix/devShells directory";
        args = {
          devShellNames = ["testing"];
          injectPreCommit = false;
          pathExists = pathExists_noPreCommit;
        };
        assertion = flk:
          lib.hasAttrByPath ["devShells" "x86_64-linux" "testing"] flk;
      }
      {
        it = "reports a conflict when nix/devenvs entry with same name exists";
        args = {
          devShellNames = ["testing"];
          injectPreCommit = false;
          pathExists = pathExists_devenvConflictEntry "testing";
        };
        assertion = flk:
          let
            eval = builtins.tryEval (flk.devShells.x86_64-linux.testing);
          in
            !eval.success;
      }
      {
        it = "reports an error when injectPreCommit entry doesn't have valid entry name";
        args = {
          devShellNames = ["other" "testing"];
          injectPreCommit = [ "unknown" ];
          pathExists = pathExists_preCommitPresent;
        };
        assertion = flk:
          let
            eval = builtins.tryEval (flk.devShells.x86_64-linux);
          in
            !eval.success;
      }
      {
        it = "generates a devShell with pre-commit when pre-commit.nix and injectPreCommit hook has entry name";
        args = {
          devShellNames = ["testing" "other"];
          injectPreCommit = ["testing"];
          pathExists = pathExists_preCommitPresent;
        };
        assertion = flk:
          # `testing` devShell gets pre-commit installed
          flk.devShells.x86_64-linux.testing.nixDirPreCommitInjected &&
          # `other` devShell doesn't get pre-commit applied due to
          # injectPreCommit configuration
          !flk.devShells.x86_64-linux.other.nixDirPreCommitInjected;
      }
      {
        it =  "generates all devShells with pre-commit when pre-commit.nix and injectPreCommit is true";
        args = {
          devShellNames = ["testing" "other"];
          injectPreCommit = true;
          pathExists = pathExists_preCommitPresent;
        };
        assertion = flk:
          flk.devShells.x86_64-linux.testing.nixDirPreCommitInjected &&
          flk.devShells.x86_64-linux.other.nixDirPreCommitInjected;
      }
      {
        it =  "doesn't generate any devShells with pre-commit when injectPreCommit is false";
        args = {
          devShellNames = ["testing" "other"];
          injectPreCommit = false;
          pathExists = pathExists_preCommitPresent;
        };
        assertion = flk:
          !flk.devShells.x86_64-linux.testing.nixDirPreCommitInjected &&
          !flk.devShells.x86_64-linux.other.nixDirPreCommitInjected;
      }
    ];

in

[
  (describe "applyDevShells"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [(it spec.it
          (let
            buildFlakeCfg = mkBuildFlakeCfg {
              inherit (spec.args) devShellNames pathExists injectPreCommit;
            };
            sut = import "${self}/devshells.nix" nixDirInputs buildFlakeCfg;
            flk = sut.applyDevShells {};
          in
            spec.assertion flk))])
    []
    specs)
  )
]
