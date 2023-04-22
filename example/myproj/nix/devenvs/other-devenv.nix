_system: _inputs: { pkgs, ... }:

{
  packages = [ pkgs.cowsay ];
  enterShell = ''
    cowsay 'no pre-commit'
  '';
}
