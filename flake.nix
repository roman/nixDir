{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    devenv.url = "github:cachix/devenv";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";

    nixtest.url = "gitlab:technofab/nixtest?dir=lib";

    systems.url = "github:nix-systems/default";
    systems.flake = false;
  };

  outputs =
    { self, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.devenv.flakeModule
        inputs.nixtest.flakeModule
      ];
      flake = {
        flakeModule = import ./. self;
        flakeModules.default = import ./. self;
      };
      perSystem =
        {
          pkgs,
          lib,
          ...
        }:
        {
          devenv.shells.default = {
            git-hooks.hooks = {
              deadnix = {
                enable = true;
                settings.edit = true;
              };
              nixfmt-rfc-style.enable = true;
              nil.enable = true;
            };
          };

          # Test suite configuration
          nixtest.suites = {
            # Tests for file/directory conflict detection (test.nix + test/default.nix).
            "conflict-detection" = import ./tests/conflict-detection-tests.nix {
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

            # Tests for with-inputs directory pattern and conflict detection.
            "with-inputs" = import ./tests/with-inputs-tests.nix {
              inherit pkgs lib inputs;
            };

            # Tests for devShells and devenvs import and conflict detection.
            "devshells" = import ./tests/devshells-tests.nix {
              inherit pkgs lib inputs;
            };

            # Tests for platform-aware package filtering based on meta.platforms.
            "platform-filtering" = import ./tests/platform-filtering-tests.nix {
              inherit pkgs lib inputs;
            };

            # Tests for devenv modules import (importDevenvModules and importDevenvModulesWithInputs).
            "devenv-modules" = import ./tests/devenv-modules-tests.nix {
              inherit pkgs lib inputs;
            };
          };
        };
    };
}
