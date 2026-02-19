# Regular devenv module (no inputs required)
# Signature: { config, lib, pkgs, ... }
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.test-service;
in
{
  options = {
    services.test-service = {
      enable = lib.mkEnableOption "Test service for unit tests";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ pkgs.hello ];
  };
}
