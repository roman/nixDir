{
  description = "go-capataz project's flake";

  # nixConfig.bash-prompt-suffix = "(flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixDir = {
      url = "git+file:../../";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixDir, ...} @ inputs:
    nixDir.lib.buildFlake {
      systems = ["x86_64-linux" "aarch64-darwin"];
      root = ./.;
      dirName = "nix";
      inputs = inputs;
    };
}
