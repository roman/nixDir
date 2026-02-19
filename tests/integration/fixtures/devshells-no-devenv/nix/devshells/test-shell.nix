pkgs:
pkgs.mkShell {
  name = "test-shell-no-devenv";
  packages = [ pkgs.hello ];
}
