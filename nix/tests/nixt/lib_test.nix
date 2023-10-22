{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  systems = [ "x86_64-linux" ];
in

[
  (describe "getPkgs"
    [
      (it "includes nixpkgsConfig setup"
        (
          let
            buildFlakeCfg = {
              root = ./.;
              inherit systems;
              nixpkgsConfig = {
                allowUnfree = true;
              };
              inputs = {
                inherit nixpkgs;
                # self is going to be mocked value to avoid infinite recursion
                self = { };
              };
            };
            sut = import "${self}/nix/src/lib.nix" nixDirInputs buildFlakeCfg;
            flake = sut.applyLib { };
            pkgs = flake.lib.getPkgs "x86_64-linux";
          in
          pkgs.config.allowUnfree
        ))
    ]
  )
]
