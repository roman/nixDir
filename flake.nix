{
  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";

    devenv = {
      url = "github:cachix/devenv/latest";
      inputs.pre-commit-hooks.follows = "pre-commit-hooks";
    };
  };

  outputs = {
    nixpkgs,
    utils,
    devenv,
    pre-commit-hooks,
    ...
  } @ inputs: {
    lib = import ./lib.nix inputs;
    devShells = utils.lib.eachDefaultSystemMap (system: let
      pkgs = import nixpkgs {inherit system;};
      preCommitRun = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    in {
      default = pkgs.mkShell {
        buildInputs = builtins.attrValues {inherit (pkgs) figlet lolcat;};
        shellHook =
          ''
            figlet nixDir | lolcat
          ''
          + preCommitRun.shellHook;
      };
    });
  };
}
