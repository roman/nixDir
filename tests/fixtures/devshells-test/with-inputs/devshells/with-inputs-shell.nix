inputs: pkgs:

pkgs.mkShell {
  buildInputs = [ pkgs.hello ];
  shellHook = ''
    echo "Test devShell from with-inputs/devshells/"
    echo "Has ${toString (builtins.length (builtins.attrNames inputs))} inputs"
  '';
}
