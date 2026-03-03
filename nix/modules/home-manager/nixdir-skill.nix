{ lib, config, ... }:

let
  cfg = config.programs.nixdir-skill;
in
{
  options.programs.nixdir-skill = {
    enable = lib.mkEnableOption "nixdir-skill for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The nixdir-skill package";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".claude/skills/nixdir-skill" = {
      source = "${cfg.package}/share/claude/skills/nixdir-skill";
      recursive = true;
    };
  };
}
