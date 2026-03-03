{ lib, config, ... }:

let
  cfg = config.nixdir-skill;

  mkSkillFiles =
    pkg:
    let
      skillDir = "${pkg}/share/claude/skills/nixdir-skill";
      referenceFiles = builtins.attrNames (builtins.readDir "${skillDir}/references");
    in
    lib.listToAttrs (
      [
        {
          name = ".claude/skills/nixdir-skill/SKILL.md";
          value.text = builtins.readFile "${skillDir}/SKILL.md";
        }
      ]
      ++ map (name: {
        name = ".claude/skills/nixdir-skill/references/${name}";
        value.text = builtins.readFile "${skillDir}/references/${name}";
      }) referenceFiles
    );
in
{
  options.nixdir-skill = {
    enable = lib.mkEnableOption "nixdir-skill for Claude Code (local project)";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The nixdir-skill package";
    };
  };

  config = lib.mkIf cfg.enable {
    files = mkSkillFiles cfg.package;
  };
}
