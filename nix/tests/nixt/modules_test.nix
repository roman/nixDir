{ self, nixpkgs, ... } @ nixDirInputs: { describe, it }:

let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  systems = [ ];
  mkBuildFlakeCfg =
    { pathExists
    , homeManagerModules ? [ ]
    , darwinModules ? [ ]
    , nixosModules ? [ ]
    }:
    let
      pkgs = import nixpkgs { inherit system; };

      inputs = {
        inherit nixpkgs;
        self = { };
      };

      # https://daiderd.com/nix-darwin/manual/index.html
      mkDarwinModule = name:
        ({ pkgs, ... }: {
          networking.hostName = name;
          homebrew.enable = true;
        });

      # https://search.nixos.org/options?
      mkNixosModule = name:
        ({ pkgs, ... }: {
          networking.hostName = name;
          services.mysql.enable = true;
        });

      # https://rycee.gitlab.io/home-manager/options.html
      mkHomeManagerModule = name:
        ({ pkgs, ... }: {
          programs.emacs.enable = true;
          home.username = name;
        });


      importDarwinModules =
        builtins.foldl'
          (acc: name: acc // { "${name}" = mkDarwinModule name; })
          { }
          darwinModules;

      importNixosModules =
        builtins.foldl'
          (acc: name: acc // { "${name}" = mkNixosModule name; })
          { }
          nixosModules;

      importHomeManagerModules =
        builtins.foldl'
          (acc: name: acc // { "${name}" = mkHomeManagerModule name; })
          { }
          homeManagerModules;

    in
    {
      root = ./.;
      inherit inputs systems;
      # override importer functions to avoid relying on filesystem presence
      inherit pathExists importDarwinModules importNixosModules importHomeManagerModules;
    };

  nixosSpecs = [
    {
      it = "generates a nixosModules output";
      args = {
        pathExists = lib.hasSuffix "nix/modules/nixos";
        nixosModules = [ "one" "two" ];
      };
      assertion = flk:
        lib.hasAttrByPath [ "nixosModules" "one" ] flk &&
        lib.hasAttrByPath [ "nixosModules" "two" ] flk;
    }
  ];

  darwinSpecs = [
    {
      it = "generates a darwinModules output";
      args = {
        pathExists = lib.hasSuffix "nix/modules/darwin";
        darwinModules = [ "one" "two" ];
      };
      assertion = flk:
        lib.hasAttrByPath [ "darwinModules" "one" ] flk &&
        lib.hasAttrByPath [ "darwinModules" "two" ] flk;
    }
  ];

  homeManagerSpecs = [
    {
      it = "generates a homeManagerModules output";
      args = {
        pathExists = lib.hasSuffix "nix/modules/home-manager";
        homeManagerModules = [ "one" "two" ];
      };
      assertion = flk:
        lib.hasAttrByPath [ "homeManagerModules" "one" ] flk &&
        lib.hasAttrByPath [ "homeManagerModules" "two" ] flk;
    }
  ];

in
[
  (describe "applyNixosModules"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [
          (it spec.it
            (
              let
                buildFlakeCfg = mkBuildFlakeCfg {
                  inherit (spec.args) nixosModules pathExists;
                };
                sut = import "${self}/nix/src/modules.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyNixosModules { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      nixosSpecs))

  (describe "applyDarwinModules"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [
          (it spec.it
            (
              let
                buildFlakeCfg = mkBuildFlakeCfg {
                  inherit (spec.args) darwinModules pathExists;
                };
                sut = import "${self}/nix/src/modules.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyDarwinModules { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      darwinSpecs))

  (describe "applyHomeManagerModules"
    (builtins.foldl'
      (testsuites: spec:
        testsuites ++
        [
          (it spec.it
            (
              let
                buildFlakeCfg = mkBuildFlakeCfg {
                  inherit (spec.args) homeManagerModules pathExists;
                };
                sut = import "${self}/nix/src/modules.nix" nixDirInputs buildFlakeCfg;
                flk = sut.applyHomeManagerModules { };
              in
              spec.assertion flk
            ))
        ])
      [ ]
      homeManagerSpecs))
]
