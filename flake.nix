{
  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-trusted-substituters = "https://devenv.cachix.org";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    nixt.url = "github:nix-community/nixt";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };

    devenv = {
      url = "github:cachix/devenv/latest";
      inputs.pre-commit-hooks.follows = "pre-commit-hooks";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs
    , nixt
    , utils
    , devenv
    , pre-commit-hooks
    , ...
    } @ inputs:
    let
      lib = import ./nix/lib.nix inputs;
      inherit (lib) buildFlake;
    in
    buildFlake {
      inherit inputs;
      root = ./.;
      injectPreCommit = true;
      injectNixtCheck = true;
      systems = [ "x86_64-darwin" "x86_64-linux" "aarch64-darwin" ];
    };
}
