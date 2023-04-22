{
  description = "example flake for nixDir";

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-trusted-substituters = "https://devenv.cachix.org";
  };

  inputs = {
    nixDir = {
      url = "git+file:../../";
    };
    nixpkgs.follows = "nixDir/nixpkgs";
  };

  outputs = {nixDir, ...} @ inputs:
    nixDir.lib.buildFlake {
      # flake inputs, these inputs are propagated across all nix configuration
      # managed by nixDir
      inputs = inputs;
      # specify the systems that are supported
      systems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
      # specify the directory that contains the nix directory.
      root = ./.;
      # specify the directory with our nix config is called nix. This is the
      # default value, the declaration is here for demonstration purposes.
      dirName = "nix";
      # inject the pre-commit of this project to all devShells and devenv configurations
      injectPreCommit = [ "default" "devenv" ];
      # use a list of module names (e.g. nix/modules/devenv/my-hello-service) or
      # a boolean value to signal we want all our devenv modules imported when
      # we have an entry in the nix/devenvs directory.
      injectDevenvModules = [ "my-hello-service" ];
      # use a list of overlay names (defined in nix/overlays.nix) that we want injected
      # to the packages we import across all files in this project.
      injectOverlays = [ "default" ];
    };
}
