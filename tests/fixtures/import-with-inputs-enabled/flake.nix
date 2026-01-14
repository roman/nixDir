{
  description = "Test fixture for importWithInputs = true";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixDir.url = "path:../../..";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nixDir.flakeModules.default ];

      systems = [ "x86_64-linux" ];

      nixDir = {
        enable = true;
        root = ./.;
        importWithInputs = true; # Set with-inputs import by default.
      };
    };
}
