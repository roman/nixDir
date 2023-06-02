{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  systems = [ system "x86_64-darwin" ];

  root = ./.;

  mkBuildFlakeCfg =
    { injectNixtCheck ? false
    }:
    {
      root = ./.;
      inputs = {
        inherit nixpkgs;
        self = { };
      };
      inherit systems injectNixtCheck;
      pathExists = lib.hasSuffix "nix/tests/nixt";
      importNixtBlocks = [ (describe "foo" (it "bar" true)) ];
    };

  specs = [
    {
      it = "generates an app when injectNixtCheck is true";
      args = {
        injectNixtCheck = true;
      };
      assertion =
        lib.hasAttrByPath [ "apps" "x86_64-linux" "nixt" ];
    }
    {
      it = "generates a __nixt field";
      args = {
        injectNixtCheck = false;
      };
      assertion = lib.hasAttrByPath [ "__nixt" ];
    }
  ];
in
[
  (describe "applyNixtTests"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [
          (it spec.it
            (
              let
                buildFlakeCfg = mkBuildFlakeCfg {
                  inherit (spec.args) injectNixtCheck;
                };
                sut = import "${self}/nix/src/nixt.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyNixtTests { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      specs))
]
