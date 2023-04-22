_system: _inputs: {
  mkShell
, cowsay
}:

mkShell {
  buildInputs = [ cowsay ];
  shellHook = ''
    cowsay other
  '';
}
