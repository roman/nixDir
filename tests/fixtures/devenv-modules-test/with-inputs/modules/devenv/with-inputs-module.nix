# Devenv module that requires flake inputs
# Signature: flakeInputs: { config, lib, pkgs, ... }
flakeInputs:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.with-inputs-service;

  # Prove we received inputs by counting them
  inputCount = builtins.length (builtins.attrNames flakeInputs);
in
{
  options = {
    services.with-inputs-service = {
      enable = lib.mkEnableOption "Test service with inputs for unit tests";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ pkgs.cowsay ];
  };

  # For testing: expose metadata about the inputs we received
  _meta = {
    hasInputs = inputCount > 0;
    inherit inputCount;
  };
}
