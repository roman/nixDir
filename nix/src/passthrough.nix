{ nixpkgs, ... } @ nixDirInputs: buildFlakeCfg:

let
  inherit (nixpkgs) lib;

  utils = import ./utils.nix nixDirInputs buildFlakeCfg;
  inherit (utils) applyFlakeOutput;

  # all these keys _do not_ rely on a system entry
  passThroughKeys = [
    "darwinConfigurations"
    "nixosConfigurations"
    "homeManagerConfigurations"
    "colmena"
  ];

  applyPassthroughKeys =
    let
      step = acc: k:
        if builtins.hasAttr k buildFlakeCfg then
          acc // { "${k}" = buildFlakeCfg."${k}"; }
        else
          acc;
    in
    applyFlakeOutput
      true # always
      (final:
        let
          passthrough = builtins.foldl' step { } passThroughKeys;
        in
        lib.recursiveUpdate final passthrough);
in
{
  inherit applyPassthroughKeys;
}
