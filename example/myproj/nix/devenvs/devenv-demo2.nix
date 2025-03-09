{ pkgs, ... }:

{
  packages = [ pkgs.cowsay ];
  enterShell = ''
    cowsay 'no pre-commit'
  '';
}
