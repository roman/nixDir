{
  flakeInputs,
}:
let
  constants = import ./constants.nix;
  inherit (constants)
    strategies
    dirNames
    flkAttrNames
    inputNames
    kinds
    ;
in
{
  # === Flake-level outputs ===

  ${kinds.nixosModules} = {
    dirPath = dirNames.nixosModules;
    flakeAttr = flkAttrNames.nixosModules;
    strategy = strategies.plain;
    wrapper = null;
    requiresInput = null;
    perSystem = false;
  };

  ${kinds.darwinModules} = {
    dirPath = dirNames.darwinModules;
    flakeAttr = flkAttrNames.darwinModules;
    strategy = strategies.plain;
    wrapper = null;
    requiresInput = null;
    perSystem = false;
  };

  ${kinds.homeManagerModules} = {
    dirPath = dirNames.homeManagerModules;
    flakeAttr = flkAttrNames.homeManagerModules;
    strategy = strategies.plain;
    wrapper = null;
    requiresInput = null;
    perSystem = false;
  };

  ${kinds.devenvModules} = {
    dirPath = dirNames.devenvModules;
    flakeAttr = flkAttrNames.devenvModules;
    strategy = strategies.plain;
    wrapper = null;
    requiresInput = null;
    perSystem = false;
  };

  ${kinds.nixosConfigurations} = {
    dirPath = dirNames.nixosConfigurations;
    flakeAttr = flkAttrNames.nixosConfigurations;
    strategy = strategies.plain;
    wrapper =
      _name: attrs:
      flakeInputs.nixpkgs.lib.nixosSystem (
        attrs
        // {
          specialArgs = {
            inputs = flakeInputs;
          };
        }
      );
    requiresInput = null;
    perSystem = false;
  };

  ${kinds.darwinConfigurations} = {
    dirPath = dirNames.darwinConfigurations;
    flakeAttr = flkAttrNames.darwinConfigurations;
    strategy = strategies.plain;
    wrapper =
      _name: attrs:
      flakeInputs.nix-darwin.lib.darwinSystem (
        attrs
        // {
          specialArgs = {
            inputs = flakeInputs;
          };
        }
      );
    requiresInput = inputNames.nixDarwin;
    perSystem = false;
  };

  # === Per-system outputs ===

  ${kinds.packages} = {
    dirPath = dirNames.packages;
    flakeAttr = flkAttrNames.packages;
    strategy = strategies.callPackage;
    wrapper = null;
    requiresInput = null;
    perSystem = true;
  };

  ${kinds.devShells} = {
    dirPath = dirNames.devShells;
    flakeAttr = flkAttrNames.devShells;
    strategy = strategies.passPkgs;
    wrapper = null;
    requiresInput = null;
    perSystem = true;
  };

  ${kinds.devenvShells} = {
    dirPath = dirNames.devenvShells;
    flakeAttr = null; # Goes to devenv.shells, handled specially
    strategy = strategies.plain;
    wrapper = null;
    requiresInput = inputNames.devenv;
    perSystem = true;
  };
}
