{ self, nixpkgs, nix-darwin, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  systems = [ "x86_64-linux" "x86_64-darwin" ];

  mkBuildFlakeCfg = extraKeys:
    {
      root = ./.;
      inherit systems;
      inputs = {
        inherit nixpkgs nix-darwin;
        self = { };
      };
    } // extraKeys;

  specs = [
    {
      it = "passes through specific keys";
      args = {
        keys = {
          nixosConfigurations = {
            nixosMachine = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              networking.hostName = "test";
            };
          };
          darwinConfigurations = {
            darwinMachine = nix-darwin.lib.darwinSystem {
              system = "aarch64-darwin";
            };
          };
        };
      };
      assertion = flk:
        lib.hasAttrByPath [ "nixosConfigurations" "nixosMachine" ] flk &&
        lib.hasAttrByPath [ "darwinConfigurations" "darwinMachine" ] flk;
    }
  ];
in
[
  (describe "applyPassthrough"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [
          (it spec.it
            (
              let
                buildFlakeCfg = mkBuildFlakeCfg spec.args.keys;
                sut = import "${self}/nix/src/passthrough.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyPassthroughKeys { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      specs))
]
