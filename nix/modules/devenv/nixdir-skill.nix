{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude.code.plugins.nixDir;
  defaultPackage = pkgs.callPackage ../../packages/nixdir-skill.nix { };

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
  options.claude.code.plugins.nixDir = {
    enable = lib.mkEnableOption "nixDir skill for Claude Code (local project)";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "pkgs.callPackage <nixDir>/nix/packages/nixdir-skill.nix { }";
      description = "The nixdir-skill package";
    };
  };

  config = lib.mkIf cfg.enable {
    files = mkSkillFiles cfg.package;
  };
}
