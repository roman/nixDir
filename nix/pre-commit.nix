{ nixt, ... } @ inputs: pkgs:

{
  hooks = {
    commitizen.enable = true;
    nixpkgs-fmt.enable = true;
    actionlint.enable = true;

    nixt = {
      enable = true;
      name = "nixt tests";
      description = "Runs nixt tests on the current flake";
      files = "^nix/tests/nixt";
      types = [ "nix" ];
      entry =
        let
          script = pkgs.writeShellScript "precommit-nixt" ''
            # check evaluation first as nixt doesn't report errors on invalid
            # nix expressions
            OUT="$(${pkgs.nix}/bin/nix eval --impure --show-trace .#__nixt)"
            if [ $? -eq 1 ]; then
              echo "$OUT"
              exit 1
            fi

            # run nixt tests
            ${nixt.packages.${pkgs.system}.default}/bin/nixt -vv
          '';
        in
        builtins.toString script;

    };
  };
}
