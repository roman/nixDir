{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  systems = [ system "x86_64-darwin" ];

  root = ./.;

  mkBuildFlakeCfg =
    { injectNixtCheck ? true
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
      it = "doesn't generate a nixt app";
      args = {
        injectNixtCheck = false;
      };
      assertion = flk:
        !(lib.hasAttrByPath [ "apps" "x86_64-linux" "nixt" ] flk);
    }
    {
      it = "generates a __nixt field";
      args = { };
      assertion = lib.hasAttrByPath [ "__nixt" ];
    }
    {
      it = "generates a nixt app";
      args = { };
      assertion =
        lib.hasAttrByPath [ "apps" "x86_64-linux" "nixt" ];
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
                buildFlakeCfg = mkBuildFlakeCfg spec.args;
                sut = import "${self}/nix/src/nixt.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyNixtTests { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      specs))
]
