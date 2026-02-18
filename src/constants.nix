{
  # Import strategies - how files are imported
  #
  # plain:       Direct import (import file). Used for modules and configurations
  #              that receive standard module arguments or need no transformation.
  #
  # callPackage: Uses pkgs.callPackage file {}. Used for packages that follow the
  #              standard Nix package pattern with auto-injected dependencies.
  #
  # passPkgs:    Passes pkgs as argument (import file pkgs). Used for devShells
  #              where the file needs access to pkgs for mkShell.
  strategies = {
    plain = "plain";
    callPackage = "callPackage";
    passPkgs = "passPkgs";
  };

  # Directory paths (relative to nix/)
  dirNames = {
    packages = "packages";
    devShells = "devshells";
    devenvShells = "devenvs";
    nixosModules = "modules/nixos";
    darwinModules = "modules/darwin";
    homeManagerModules = "modules/home-manager";
    devenvModules = "modules/devenv";
    nixosConfigurations = "configurations/nixos";
    darwinConfigurations = "configurations/darwin";
    withInputs = "with-inputs";
  };

  # Flake output attribute names
  flkAttrNames = {
    packages = "packages";
    devShells = "devShells";
    nixosModules = "nixosModules";
    darwinModules = "darwinModules";
    homeManagerModules = "homeManagerModules";
    devenvModules = "devenvModules";
    nixosConfigurations = "nixosConfigurations";
    darwinConfigurations = "darwinConfigurations";
  };

  # Required flake inputs for validation
  inputNames = {
    devenv = "devenv";
    nixDarwin = "nix-darwin";
  };

  # Output kind names (canonical identifiers)
  kinds = {
    packages = "packages";
    devShells = "devShells";
    devenvShells = "devenvShells";
    nixosModules = "nixosModules";
    darwinModules = "darwinModules";
    homeManagerModules = "homeManagerModules";
    devenvModules = "devenvModules";
    nixosConfigurations = "nixosConfigurations";
    darwinConfigurations = "darwinConfigurations";
  };

  # Discovery error reason types
  #
  # blocked:        A sibling .nix file blocks directory traversal (e.g., foo.nix blocks foo/)
  # depthExceeded:  Directory exceeds maxDepth limit during recursive discovery
  discoveryErrors = {
    blocked = "blocked";
    depthExceeded = "depth-exceeded";
  };
}
