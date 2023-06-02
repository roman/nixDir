# devShells receive the system, the flake inputs, and the imported nixpkgs input.
inputs: pkgs:

pkgs.mkShell {
  buildInputs = [ pkgs.figlet pkgs.lolcat ];
  shellHook = ''
    figlet myproj | lolcat
  '';
}
