# Regular devShells receive only pkgs (portable).
# For with-inputs devShells, use nix/with-inputs/devshells/ with signature: inputs: pkgs:
pkgs:

pkgs.mkShell {
  buildInputs = [ pkgs.figlet pkgs.lolcat ];
  shellHook = ''
    figlet myproj | lolcat
  '';
}
