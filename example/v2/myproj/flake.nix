{
  description = "example flake for nixDir";

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-trusted-substituters = "https://devenv.cachix.org";
  };

  inputs = {
    nixDir = {
      url = "git+file:./../../../";
    };
    # use the same dependencies as the root flake
    nixpkgs.follows = "nixDir/nixpkgs";
    devenv.follows = "nixDir/devenv";
    nixt.follows = "nixDir/nixt";
  };

  outputs = { nixDir, ... } @ inputs:
    nixDir.lib.buildFlake {
      # flake inputs, these inputs are propagated across all nix configuration
      # managed by nixDir
      inputs = inputs;
      # specify the systems that are supported
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      # specify the directory that contains the nix directory.
      root = ./.;
      # specify the directory with our nix config is called nix. This is the
      # default value, the declaration is here for demonstration purposes.
      dirName = "nix";
      # inject the pre-commit of this project to all devShells and devenv
      # configurations.
      #
      # By default the pre-commit hooks will always get injected to all shells.
      #
      # We can specify which devShells should not have the pre-commit hooks by
      # omitting their name on the list, or we can set the value to `false` so
      # that no shell has the pre-commit hooks injected.
      injectPreCommit = [ "default" "devenv" ];
      # use a list of module names (e.g. nix/modules/devenv/my-hello-service) or
      # a boolean value to signal we want all our devenv modules imported when
      # we have an entry in the nix/devenvs directory.
      injectDevenvModules = [ "my-hello-service" ];
      # use a list of overlay names (defined in nix/overlays.nix) that we want injected
      # to the packages we import across all files in this project.
      injectOverlays = [ "default" ];
      # specify packages in the flake itself if you want to avoid using the file
      # system; packages support the systems provided in the systems parameter.
      packages = (pkgs: {
        flkPkg = pkgs.lolcat;
      });
      # generates an "all" package that includes every package in the flake. This
      # is useful when uploading packages to a remote nix-store (defaults to false).
      generateAllPackage = true;
      # Specify various configurations. These keys are pass-through to the
      # output flake
      #
      # nixConfigurations = { };
      # darwinConfigurations = {  };
      # homeManagerConfigurations = {  };
    };
}
