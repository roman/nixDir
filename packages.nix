{ nixpkgs, ... } @ nixDirInputs: {
  inputs
, systems
, root
, dirName ? "nix"
, nixDir ? "${root}/${dirName}"
, pathExists ? builtins.pathExists
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
            allPackages = importPackages pkgs;

            isSystemSupported = pkg:
              !(lib.hasAttrByPath [ "meta" "platforms" ] pkg) ||
              (builtins.elem pkgs.system pkg.meta.platforms);

            step = acc: pkgName:
              let
                pkg = allPackages.${pkgName};
              in
                if isSystemSupported pkg then
                  acc // { "${pkgName}" = allPackages.${pkgName}; }
                else
                  acc;
          in
            builtins.foldl' step {} (builtins.attrNames allPackages)
        );
      };
in
{
  inherit applyPackages;
}
