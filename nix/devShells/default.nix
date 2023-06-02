{ self, nixt, ... }: pkgs:

pkgs.mkShell {
  buildInputs = [
    nixt.packages.${pkgs.system}.default
    pkgs.figlet
    pkgs.lolcat
    pkgs.jq
    (pkgs.bats.withLibraries (p: [ p.bats-support p.bats-assert ]))
  ];
  shellHook =
    ''
      figlet nixDir | lolcat
    '';
}
