{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "nixdir-skill";
  version = "0.1.0";

  src = ../../skill/nixdir-skill;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/claude/skills/nixdir-skill
    cp SKILL.md $out/share/claude/skills/nixdir-skill/
    cp -r references $out/share/claude/skills/nixdir-skill/
    runHook postInstall
  '';

  meta = with lib; {
    description = "nixDir skill for Claude Code";
    platforms = platforms.all;
  };
}
