pkgs:

pkgs.mkShell {
  buildInputs = [ pkgs.hello ];
  shellHook = ''
    echo "Test devShell from regular devshells/"
  '';
}
