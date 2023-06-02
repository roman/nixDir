{ nixpkgs, nixt, ... } @ nixDirInputs: { inputs
                                       , systems
                                       , root
                                       , dirName ? "nix"
                                       , nixDir ? "${root}/${dirName}"
                                       , pathExists ? builtins.pathExists
                                       , injectNixtCheck ? false
                                       , ...
                                       } @ buildFlakeCfg:

let
  inherit (nixpkgs) lib;
  importer = import ./importer.nix nixDirInputs buildFlakeCfg;
  utils = import ./utils.nix nixDirInputs buildFlakeCfg;

  inherit (importer) importNixtBlocks;
  inherit (utils) applyFlakeOutput eachSystemMapWithPkgs;

  applyNixtTests =
    applyFlakeOutput
      (pathExists "${nixDir}/tests/nixt")
      (
        let
          testBlocks = importNixtBlocks;
        in
        {
          __nixt = inputs.nixt.lib.grow {
            blocks = testBlocks;
          };
        } //
        (if injectNixtCheck then
          {
            apps = eachSystemMapWithPkgs systems (pkgs:
              {
                nixt =
                  let
                    program = pkgs.writeShellScript "nixt-check.sh" ''
                      OUT="$(${pkgs.nix}/bin/nix eval --impure --show-trace .#__nixt)"
                      if [ $? -eq 1 ]; then
                        echo "$OUT"
                        exit 1
                      fi
                      ${nixt.packages.${pkgs.system}.default}/bin/nixt -vv
                    '';
                  in
                  {
                    type = "app";
                    program = "${program}";
                  };
              }
            );
          }
        else
          { })
      );
in
{
  inherit applyNixtTests;
}
