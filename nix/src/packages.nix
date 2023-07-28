{ nixpkgs, ... } @ nixDirInputs: { inputs
                                 , systems
                                 , root
                                 , dirName ? "nix"
                                 , nixDir ? "${root}/${dirName}"
                                 , pathExists ? builtins.pathExists
                                   # packages is a function defined at the
                                   # flake.nix file
                                 , packages ? null
                                   # generateAllPackage indicates if we want to
                                   # create a meta package that includes all the
                                   # packages of the flake; this is useful when
                                   # we want to build all the packages to copy
                                   # them to a remote nix-store
                                 , generateAllPackage ? false
                                 , ...
                                 } @ buildFlakeCfg:

let
  inherit (nixpkgs) lib;

  importer = import ./importer.nix nixDirInputs buildFlakeCfg;
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;

  inherit (importer) importPackages;
  inherit (utils) applyFlakeOutput eachSystemMapWithPkgs;

  applyPackages =
    applyFlakeOutput
      (pathExists "${nixDir}/packages" ||
        generateAllPackage ||
        packages != null)
      {
        packages = eachSystemMapWithPkgs systems (pkgs:
          let
            getPkgsFromConfig =
              # packages is a function received as an argument in the buildFlake
              # invokation
              if packages == null then
                (_pkgs: { })
              else
                packages;

            cfgPkgs = getPkgsFromConfig pkgs;

            # packages coming from the ./nix/pacakges directory
            dirPkgs =
              if pathExists "${nixDir}/packages" then
                importPackages pkgs
              else
                { };

            allPkgs = cfgPkgs // dirPkgs;

            isSystemSupported = pkg:
              !(lib.hasAttrByPath [ "meta" "platforms" ] pkg) ||
              (builtins.elem pkgs.system pkg.meta.platforms);

            step = acc: pkgName:
              let
                pkg = allPkgs.${pkgName};
              in
              if isSystemSupported pkg then
                acc // { "${pkgName}" = allPkgs.${pkgName}; }
              else
                acc;

            duplicatedKeys =
              let
                a = lib.attrNames cfgPkgs;
                b = lib.attrNames dirPkgs;
              in
              lib.intersectLists a b;

            resultPkgs =
              # validate there are no entries with the same name on both the
              # buildFlake packages parameter and the packages coming from the
              # ./nix/packages directory.
              if builtins.length duplicatedKeys != 0 then
                throw ''
                  nixDir is confused, it found some package entries in both the `packages` parameter and the file system.

                  Duplicated entries: ${lib.concatStringsSep ", " duplicatedKeys}
                ''
              else
                builtins.foldl' step { } (builtins.attrNames allPkgs);

            shellPkgs =
              # shellPkgs are all the devShells derivations, these allow us to
              # cache shells the same way we do packages.
              lib.concatMapAttrs
                (name: shell:
                  # skip devenv shells. They must be skipped given they are
                  # impure and caching them wouldn't make much sense.
                  if lib.hasPrefix "devenv-" shell.name then
                    { }
                  else
                    { "${name}-shell" = shell.inputDerivation; })
                inputs.self.devShells.${pkgs.system};

            result =
              # create a package that includes _all_ the packages of the
              # flake. This is useful when uploading packages to a nix-store
              if generateAllPackage then
                resultPkgs // {
                  all = pkgs.symlinkJoin {
                    name = "all";
                    buildInputs = lib.attrValues shellPkgs;
                    paths = lib.attrValues resultPkgs;
                  };
                }
              else
                resultPkgs;

          in
          result
        );
      };
in
{
  inherit applyPackages;
}
