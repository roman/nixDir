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
                settings = {
                  exclude = [
                    "tests/fixtures/portable-config/configurations/nixos/test-host.nix"
                    "tests/fixtures/devshells-conflict/devshells/conflict.nix"
                    "tests/fixtures/devshells-conflict/devenvs/conflict.nix"
                    "tests/fixtures/with-inputs-conflict/modules/nixos/conflicting.nix"
                    "tests/fixtures/with-inputs-conflict/with-inputs/modules/nixos/conflicting.nix"
                    "tests/fixtures/devshells-test/devshells/test-shell.nix"
                    "tests/fixtures/devshells-test/with-inputs/devshells/with-inputs-shell.nix"
                    "tests/fixtures/devshells-test/with-inputs/devenvs/with-inputs-env.nix"
                    "tests/fixtures/devshells-test/devenvs/test-env.nix"
                    "tests/fixtures/with-inputs/modules/nixos/test-module.nix"
                    "tests/fixtures/with-inputs/packages/test-pkg.nix"
                    "tests/fixtures/conflicts/conflict-case/test/default.nix"
                    "tests/fixtures/conflicts/conflict-case/test.nix"
                    "tests/fixtures/conflicts/valid-file/test.nix"
                    "tests/fixtures/conflicts/valid-dir/test/default.nix"
                  ];
                };

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
          };
        };
    };
}
