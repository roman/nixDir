_inputs: { pkgs, ... }:

{
  packages = [ pkgs.cowsay ];
  enterShell = ''
    cowsay 'no pre-commit'
  '';
}
