pkgs:

pkgs.mkShell {
  buildInputs = [ pkgs.hello ];
}
