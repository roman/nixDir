{ nixpkgs, ... } @ nixDirInputs: { inputs
                                 , systems
                                 , root
                                 , dirName ? "nix"
                                 , nixDir ? "${root}/${dirName}"
                                 , pathExists ? builtins.pathExists
                                   # packages is a function defined at the
                                   # flake.nix file
                                 , packages ? (_pkgs: { })
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
      (pathExists "${nixDir}/packages")
      {
        packages = eachSystemMapWithPkgs systems (pkgs:
          let
            # packages coming from the buildFlake invokation
            cfgPkgs = packages pkgs;

            # packages coming from the ./nix/pacakges directory
            dirPkgs = importPackages pkgs;

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

          in
          resultPkgs
        );
      };
in
{
  inherit applyPackages;
}
