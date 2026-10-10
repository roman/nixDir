{
  lib,
  inputs,
  ...
}:
let
  # Stand-in for home-manager that returns the arguments it was called with, so
  # the tests can assert what nixDir hands to homeManagerConfiguration without
  # adding home-manager to this flake's inputs.
  fakeHomeManager = {
    lib.homeManagerConfiguration = args: args;
  };

  # Stand-in for flake-parts' withSystem: the perSystem pkgs for a system is a
  # string naming that system.
  fakeWithSystem = system: f: f { pkgs = "pkgs-for-${system}"; };

  evalHomeConfigurations =
    flakeInputs:
    let
      evaluated = lib.evalModules {
        modules = [
          {
            options = {
              flake = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified;
                default = { };
              };
              perSystem = lib.mkOption {
                type = lib.types.unspecified;
                default = { };
              };
            };
          }
          (import ../../default.nix null)
          {
            nixDir = {
              enable = true;
              root = ./fixtures;
            };
          }
        ];
        specialArgs = {
          inherit lib;
          inputs = flakeInputs;
          withSystem = fakeWithSystem;
        };
      };
    in
    evaluated.config.flake.homeConfigurations;

  configurations = evalHomeConfigurations (inputs // { home-manager = fakeHomeManager; });

  withoutHomeManager = evalHomeConfigurations (builtins.removeAttrs inputs [ "home-manager" ]);
in
{
  tests = [
    {
      name = "system selects the perSystem pkgs of the flake";
      type = "unit";
      expected = "pkgs-for-x86_64-linux";
      actual = configurations.by-system.pkgs;
    }

    {
      name = "system is not passed to homeManagerConfiguration";
      type = "unit";
      expected = false;
      actual = configurations.by-system ? system;
    }

    {
      name = "explicit pkgs is passed through unchanged";
      type = "unit";
      expected = "explicit-pkgs";
      actual = configurations.by-pkgs.pkgs;
    }

    {
      name = "extraSpecialArgs carries the flake inputs";
      type = "unit";
      expected = true;
      actual = configurations.by-pkgs.extraSpecialArgs.inputs ? home-manager;
    }

    {
      name = "extraSpecialArgs keeps the arguments the file declares";
      type = "unit";
      expected = 42;
      actual = configurations.by-system.extraSpecialArgs.answer;
    }

    {
      name = "a configuration without the home-manager input fails to evaluate";
      type = "unit";
      expected = false;
      actual = (builtins.tryEval withoutHomeManager.by-system.modules).success;
    }
  ];
}
