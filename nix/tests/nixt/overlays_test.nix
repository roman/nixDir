{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  systems = [ system ];
  pathExists = lib.hasSuffix "nix/overlays.nix";
  mkBuildFlakeCfg =
    {}:
    let
      root = ./.;

      # use x86_64-linux architecture as our standard pkgs
      pkgs = import nixpkgs { inherit system; };

      importOverlays = {
        some-overlay = final: prev: { };
      };

      inputs = {
        inherit nixpkgs;
        self = { };
      };
    in
    {
      inherit root inputs systems;
      inherit pathExists importOverlays;
    };
in

[
  (describe "applyOverlays"
    [
      (it "when nix/overlays.nix is present creates an overlays field"
        (
          let
            buildFlakeCfg = mkBuildFlakeCfg { };
            sut = import "${self}/nix/src/overlays.nix" nixDirInputs buildFlakeCfg;
            flk = sut.applyOverlays { };
          in
          builtins.hasAttr "overlays" flk
          && lib.hasAttrByPath [ "overlays" "some-overlay" ] flk
        ))
    ])

]
