{
  description = "example flake for nixDir";

  inputs = {
    nixDir = {
      url = "git+file:./../../";
    };
    # use the same dependencies as the root flake
    nixpkgs.follows = "nixDir/nixpkgs";
    flake-parts.follows = "nixDir/flake-parts";
    nix-darwin.url = "github:LnL7/nix-darwin";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    devenv.follows = "nixDir/devenv";
    nix2container.follows = "nixDir/nix2container";
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      imports = [
        inputs.devenv.flakeModule
        inputs.nixDir.flakeModule
      ];
      nixDir = {
        # (Required) Enable discovery of flake outputs from a directory (required).
        enable = true;

        # (Required) Specify the root of the current flake for automatic wiring of various
        # flake outputs.
        root = ./.;

        # (Optional) Specify the directory with our nix config is called nix. The value
        # "nix" is the default value, the declaration is here for demonstration purposes.
        dirName = "nix";

        # (Optional) Receive attribute set of devenv modules defined in the flake and specify which
        # devenv modules should be automatically included by default on devenvs entries from
        # this flake.
        installDevenvModules = mods: [ mods.my-hello-service ];

        # (Optional) Another option available for is to install _all_ devenv modules defined
        # in this flake using the installAllDevenvModules.
        # installAllDevenvModules = true;

        # (Optional) Generates an "all" package that includes every package in the
        # flake. This is useful when uploading packages to a remote nix-store (optional,
        # defaults to false).
        generateAllPackage = true;

        # (Optional) Generates a flake overlay that contains all the packages defined in
        # this flake.
        generateFlakeOverlay = true;

        # (Optional) Have all the packages defined in this flake available in the
        # flake-part's perSystem pkgs argument for this flake. This setting sets
        # generateFlakeOverlay to true automatically.
        installFlakeOverlay = true;

        # (Optional) Have all the packages from the overlays in the given list available in
        # the perSystem pkgs argument for this flake.
        installOverlays = [
          inputs.devenv.overlays.default
        ];
      };
    };
}
