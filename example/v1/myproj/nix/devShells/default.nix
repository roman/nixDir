# devShells receive the system, the flake inputs, and a attribute set with
# required nixpkgs packages.
system: inputs: { mkShell
                , figlet
                , lolcat
                ,
                }:
mkShell {
  buildInputs = [ figlet lolcat ];
  shellHook = ''
    figlet myproj | lolcat
  '';
}
