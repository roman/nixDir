{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = {
    nixpkgs,
    utils,
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
