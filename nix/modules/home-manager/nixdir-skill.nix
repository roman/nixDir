{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.programs.claude-code.plugins.nixDir;
  defaultPackage = pkgs.callPackage ../../packages/nixdir-skill.nix { };
in
{
  options.programs.claude-code.plugins.nixDir = {
    enable = lib.mkEnableOption "nixDir skill for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "pkgs.callPackage <nixDir>/nix/packages/nixdir-skill.nix { }";
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
