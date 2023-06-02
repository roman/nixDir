{
  description = "example flake for nixDir";

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  inputs = {
    nixDir = {
      url = "git+file:../../";
    };
    nixpkgs.follows = "nixDir/nixpkgs";
  };

  outputs = { nixDir, ... } @ inputs:
    nixDir.lib.buildFlake {
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      root = ./.;
      dirName = "nix";
      inputs = inputs;
    };
}
