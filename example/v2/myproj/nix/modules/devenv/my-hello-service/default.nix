inputs: { config, lib, pkgs, ... }:

let
  cfg = config.services.my-hello;

  startScript = pkgs.writeShellScriptBin "start-my-hello" ''
    set -euo pipefail
    while true; do ${pkgs.hello}/bin/hello -g "my-hello enabled" && sleep 1; done
  '';
in
{
  options = {
    services.my-hello = {
      enable = lib.mkEnableOption "My Hello World app";
    };
  };

  config = lib.mkIf cfg.enable {
    processes.my-hello.exec = ''${startScript}/bin/start-my-hello'';
  };
}
