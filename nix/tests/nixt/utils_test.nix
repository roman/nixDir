{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  systems = [ "x86_64-linux" ];
in

[
  (describe "getPkgs"
    [
      (it "throws an error when entry in 'injectOverlays' is not a known overlay"
        (
          let
            # create the nixDir.buildFlake configuration
            buildFlakeCfg = {
              # the nixDir.buildFlake configuration
              # requires at least two inputs, self and nixpkgs
              inputs = {
                inherit nixpkgs systems;
                # self is going to be mocked value, in this case a
                # flake that has an overlay with a "hello" key
                self = {
                  overlays = {
                    hello = final: prev: { };
                  };
                };
              };
              # provide an overlay name that doesn't exist
              injectOverlays = [ "other" ];
            };

            # import the internal utils file
            utils = import "${self}/nix/src/utils.nix" nixDirInputs buildFlakeCfg;

            # evaluate the overlaysToInject, which is a value that performs the
            # validation of overlays
            pkgs = utils.getPkgs "x86_64-linux";
            result =
              builtins.tryEval (builtins.deepSeq pkgs pkgs);
          in
          # result should not be a success because "other" is not present in the
            # overlays list
            !result.success
        ))
      (it "includes packages from specified overlays on injectedOverlays"
        (
          let
            # create the nixDir.buildFlake configuration
            buildFlakeCfg = {
              # the nixDir.buildFlake configuration requires at least two inputs,
              # self and nixpkgs
              inputs = {
                inherit nixpkgs systems;
                # self is going to be mocked value, in this case a flake that has
                # an overlay with a "hello" key
                self = {
                  overlays = {
                    hello = final: prev: {
                      nixDir-package-example1 = prev.hello;
                    };
                    other = final: prev: {
                      nixDir-package-example2 = prev.hello;
                    };
                  };
                };
              };
              # provide an overlay name that exists
              injectOverlays = [ "hello" ];
            };
            # import the internal utils file
            utils = import "${self}/nix/src/utils.nix" nixDirInputs buildFlakeCfg;
            pkgs = utils.getPkgs "x86_64-linux";
          in
          (pkgs ? nixDir-package-example1) &&
          !(pkgs ? nixDir-package-example2)
        ))

      (it "includes packages from all overlays when injectOverlays is true"
        (
          let
            # create the nixDir.buildFlake configuration
            buildFlakeCfg = {
              # the nixDir.buildFlake configuration requires at least two inputs,
              # self and nixpkgs
              inputs = {
                inherit nixpkgs systems;
                # self is going to be mocked value, in this case a flake that has
                # an overlay with a "hello" key
                self = {
                  overlays = {
                    hello = final: prev: {
                      nixDir-package-example1 = prev.hello;
                    };
                    other = final: prev: {
                      nixDir-package-example2 = prev.hello;
                    };
                  };
                };
              };
              # inject all overlays
              injectOverlays = true;
            };
            # import the internal utils file
            utils = import "${self}/nix/src/utils.nix" nixDirInputs buildFlakeCfg;
            pkgs = utils.getPkgs "x86_64-linux";
          in
          (pkgs ? nixDir-package-example1) &&
          (pkgs ? nixDir-package-example2)
        )
      )
    ])

]
