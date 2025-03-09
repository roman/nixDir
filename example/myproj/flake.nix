{
  description = "example flake for nixDir";

  inputs = {
    nixDir = { url = "git+file:./../../"; };
    # use the same dependencies as the root flake
    nixpkgs.follows = "nixDir/nixpkgs";
    flake-parts.follows = "nixDir/flake-parts";
    nix-darwin.url = "github:LnL7/nix-darwin";

    devenv.follows = "nixDir/devenv";
    nix2container.follows = "nixDir/nix2container";
  };

  outputs = { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      imports = [ inputs.devenv.flakeModule inputs.nixDir.flakeModule ];
      nixDir = {
        # Enable discovery of flake outputs from a directory (required).
        enable = true;

        # Specify the root of the current flake for automatic wiring of various flake
        # outputs (required).
        root = ./.;

        # Specify the directory with our nix config is called nix. The value "nix" is the
        # default value, the declaration is here for demonstration purposes (optional).
        dirName = "nix";

        # Use a list of module names (e.g. nix/modules/devenv/my-hello-service) to signal we
        # want this devenv module imported when we have an entry in the nix/devenvs
        # directory (optional) .
        injectDevenvModules = [ "my-hello-service" ];

        # Another option available for the same purpose is injectAllDevenvmodules.
        # injectAllDevenvModules = true;

        # Generates an "all" package that includes every package in the flake. This
        # is useful when uploading packages to a remote nix-store (optional, defaults to false).
        generateAllPackage = true;
      };
    };
}
