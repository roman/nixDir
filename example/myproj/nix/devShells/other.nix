pkgs:

pkgs.mkShell {
  buildInputs = [ pkgs.cowsay ];
  shellHook = ''
    cowsay other
  '';
}
