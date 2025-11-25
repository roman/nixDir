{
  inputs = {
    nixDir.url = "path:../../..";
    nixpkgs.follows = "nixDir/nixpkgs";
    flake-parts.follows = "nixDir/flake-parts";
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      imports = [ inputs.nixDir.flakeModule ];

      nixDir = {
        enable = true;
        root = ./.;
        filterUnsupportedSystems = true;
        installFlakeOverlay = false;
        generateFlakeOverlay = false;
      };
    };
}
