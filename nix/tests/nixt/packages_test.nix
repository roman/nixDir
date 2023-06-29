{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  systems = [ system "x86_64-darwin" ];

  root = ./.;

  mkPackageWithSystem = system: pkgName: pkgs:
    pkgs.stdenv.mkDerivation {
      name = pkgName;
      meta.platforms = [ system ];
    };

  mkPackageNoSystem = pkgName: pkgs:
    pkgs.stdenv.mkDerivation {
      name = "${pkgName}-nosystem";
    };

  mkImportPackages = pkgNames: pkgs:
    let
      step = acc: pkgName:
        acc // {
          "${pkgName}" = mkPackageWithSystem system pkgName pkgs;
          "${pkgName}-nosystem" = mkPackageNoSystem pkgName pkgs;
        };
    in
    builtins.foldl' step { } pkgNames;

  mkBuildFlakeCfg =
    { pkgNames
    }:
    {
      root = ./.;
      inputs = {
        inherit nixpkgs;
        self = { };
      };
      inherit systems;
      pathExists = lib.hasSuffix "nix/packages";
      importPackages = mkImportPackages pkgNames;
      packages = (pkgs: {
        flkPkg = pkgs.hello;
      });
    };

  specs = [
    {
      it = "generates packages when nix/packages files are present";
      args = {
        pkgNames = [ "mypkg" ];
      };
      assertion = flk:
        lib.hasAttrByPath [ "packages" "x86_64-linux" "mypkg" ] flk;
    }
    {
      it = "respects packages coming from the buildFlake call";
      args = {
        pkgNames = [ ];
      };
      assertion = flk:
        lib.hasAttrByPath [ "packages" "x86_64-linux" "flkPkg" ] flk;
    }
    {
      it = "fails when same entry is on both places";
      args = {
        pkgNames = [ "flkPkg" ];
      };
      assertion = flk:
        let
          eval = builtins.tryEval (flk.packages.x86_64-linux.flkPkg);
        in
          !eval.success;
    }
    {
      it = "filter packages with a matching system";
      args = {
        pkgNames = [ "mypkg" ];
      };
      assertion = flk:
        # no-system is present because (by default) packages without supported
        # platforms are always included
        lib.hasAttrByPath [ "packages" "x86_64-darwin" "mypkg-nosystem" ] flk
        # mypkg has x86_64-linux as it's platform, so it should not be available
        # on the x86_64-darwin map
        && !(lib.hasAttrByPath [ "packages" "x86_64-darwin" "mypkg" ] flk);
    }
  ];
in
[
  (describe "applyPackages"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [
          (it spec.it
            (
              let
                buildFlakeCfg = mkBuildFlakeCfg {
                  inherit (spec.args) pkgNames;
                };
                sut = import "${self}/nix/src/packages.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyPackages { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      specs))
]
