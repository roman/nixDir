{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    devenv.url = "github:cachix/devenv";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs = { nixpkgs.follows = "nixpkgs"; };

    nixtest.url = "gitlab:technofab/nixtest?dir=lib";

    systems.url = "github:nix-systems/default";
    systems.flake = false;
  };

  outputs = { self, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ inputs.devenv.flakeModule inputs.nixtest.flakeModule ];
      flake = {
        flakeModule = import ./. self;
        flakeModules.default = import ./. self;
      };
      perSystem = { pkgs, lib, config, ... }: {
        devenv.shells.default = {
          devenv.root = builtins.toString ./.;

          packages = [ config.treefmt.build.wrapper ];

          git-hooks.hooks = {
            deadnix.enable = true;
            nixfmt-classic.enable = true;
            nil.enable = true;
          };
        };

        # Test suite configuration
        nixtest.suites = {
          # Tests for file/directory conflict detection (test.nix + test/default.nix).
          "conflict-detection" = import ./tests/conflict-detection-tests.nix {
            inherit pkgs lib inputs;
          };

          # Tests for scopeInputsToSystem function that extracts system-specific values
          # from flake inputs (e.g., inputs.foo.packages.${system} -> inputs.foo.packages).
          "scope-inputs" = import ./tests/scopeInputs-tests.nix {
            inherit pkgs lib inputs;
          };

          # Tests for smart importDir that auto-detects module signatures using tryEval
          # and handles both `inputs: { pkgs, ... }:` and `{ pkgs, ... }:` signatures.
          "smart-importDir" = import ./tests/smart-importDir-tests.nix {
            inherit pkgs lib inputs;
          };

          # Tests for nixDir flake module configuration options and structure.
          "module-config" = import ./tests/module-config-tests.nix {
            inherit pkgs lib inputs;
          };

          # Integration tests using the example project to verify end-to-end functionality.
          "integration" = import ./tests/integration-tests.nix {
            inherit pkgs lib inputs;
          };

          # Tests for error handling when required inputs (devenv, nix-darwin) are missing.
          "error-handling" = import ./tests/error-handling-tests.nix {
            inherit pkgs lib inputs;
          };
        };
      };
    };
}
