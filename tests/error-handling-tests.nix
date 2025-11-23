{ pkgs, lib, inputs }:
let
  # Create importer with empty inputs for testing error conditions
  importerWithoutDevenv = import ../src/importer.nix {
    inherit pkgs lib;
    inputs = builtins.removeAttrs inputs [ "devenv" ];
  };

  importerWithoutDarwin = import ../src/importer.nix {
    inherit pkgs lib;
    inputs = builtins.removeAttrs inputs [ "nix-darwin" ];
  };

  # Create a dummy path for testing
  dummyPath = /tmp/nonexistent;
in
{
  tests = [
    {
      name = "importDevenvs throws error when devenv missing";
      type = "unit";
      expected = true;
      actual =
        let
          result = builtins.tryEval (importerWithoutDevenv.importDevenvs dummyPath);
        in
        !result.success;
    }

    {
      name = "importDevenvs error mentions devenv input";
      type = "script";
      script = ''
        PATH=${pkgs.nix}/bin:${pkgs.gnugrep}/bin:$PATH

        error_output=$(nix-instantiate --eval --strict --expr '
          let
            pkgs = import ${inputs.nixpkgs} { system = "${pkgs.system}"; };
            lib = pkgs.lib;
            inputs = {};
            importer = import ${../src/importer.nix} {
              inherit pkgs lib inputs;
            };
          in
          importer.importDevenvs /tmp/nonexistent
        ' 2>&1 || true)

        if echo "$error_output" | grep -q "devenv is not in the flake inputs"; then
          echo "PASS: Error mentions missing devenv input"
          exit 0
        else
          echo "FAIL: Error message not helpful"
          echo "Got: $error_output"
          exit 1
        fi
      '';
    }

    {
      name = "importDarwinConfigurations throws error when nix-darwin missing";
      type = "unit";
      expected = true;
      actual =
        let
          result = builtins.tryEval (importerWithoutDarwin.importDarwinConfigurations dummyPath);
        in
        !result.success;
    }

    {
      name = "importDarwinConfigurations error mentions nix-darwin input";
      type = "script";
      script = ''
        PATH=${pkgs.nix}/bin:${pkgs.gnugrep}/bin:$PATH

        error_output=$(nix-instantiate --eval --strict --expr '
          let
            pkgs = import ${inputs.nixpkgs} { system = "${pkgs.system}"; };
            lib = pkgs.lib;
            inputs = {};
            importer = import ${../src/importer.nix} {
              inherit pkgs lib inputs;
            };
          in
          importer.importDarwinConfigurations /tmp/nonexistent
        ' 2>&1 || true)

        if echo "$error_output" | grep -q "nix-darwin is not in the flake inputs"; then
          echo "PASS: Error mentions missing nix-darwin input"
          exit 0
        else
          echo "FAIL: Error message not helpful"
          echo "Got: $error_output"
          exit 1
        fi
      '';
    }

    {
      name = "devenv error message provides solution";
      type = "script";
      script = ''
        PATH=${pkgs.nix}/bin:${pkgs.gnugrep}/bin:$PATH

        error_output=$(nix-instantiate --eval --strict --expr '
          let
            pkgs = import ${inputs.nixpkgs} { system = "${pkgs.system}"; };
            lib = pkgs.lib;
            inputs = {};
            importer = import ${../src/importer.nix} {
              inherit pkgs lib inputs;
            };
          in
          importer.importDevenvs /tmp/nonexistent
        ' 2>&1 || true)

        if echo "$error_output" | grep -q "devenv.url"; then
          echo "PASS: Error provides solution with devenv.url"
          exit 0
        else
          echo "FAIL: Error doesn't provide solution"
          echo "Got: $error_output"
          exit 1
        fi
      '';
    }

    {
      name = "nix-darwin error message provides solution";
      type = "script";
      script = ''
        PATH=${pkgs.nix}/bin:${pkgs.gnugrep}/bin:$PATH

        error_output=$(nix-instantiate --eval --strict --expr '
          let
            pkgs = import ${inputs.nixpkgs} { system = "${pkgs.system}"; };
            lib = pkgs.lib;
            inputs = {};
            importer = import ${../src/importer.nix} {
              inherit pkgs lib inputs;
            };
          in
          importer.importDarwinConfigurations /tmp/nonexistent
        ' 2>&1 || true)

        if echo "$error_output" | grep -q "nix-darwin.url"; then
          echo "PASS: Error provides solution with nix-darwin.url"
          exit 0
        else
          echo "FAIL: Error doesn't provide solution"
          echo "Got: $error_output"
          exit 1
        fi
      '';
    }
  ];
}
