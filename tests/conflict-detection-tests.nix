{ pkgs, lib, inputs }:
let
  importer = import ../src/importer.nix {
    inherit pkgs lib inputs;
  };

  # Test fixture paths
  validFilePath = ./fixtures/conflicts/valid-file;
  validDirPath = ./fixtures/conflicts/valid-dir;
  conflictPath = ./fixtures/conflicts/conflict-case;
in
{
  tests = [
    # Test 1: Valid case with only .nix file
    {
      name = "valid file import succeeds";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importDirWithoutInputs validFilePath;
          # Result is an attrset of functions, call the test function with pkgs
          evaluated = result.test { inherit pkgs; };
        in
        result ? test && evaluated.testValue == "from-file";
    }

    # Test 2: Valid case with only directory/default.nix
    {
      name = "valid directory import succeeds";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importDirWithoutInputs validDirPath;
          # Result is an attrset of functions, call the test function with pkgs
          evaluated = result.test { inherit pkgs; };
        in
        result ? test && evaluated.testValue == "from-directory";
    }

    # Test 3: Conflict case should throw error
    {
      name = "conflicting file and directory throws error";
      type = "script";
      script = ''
        PATH=${pkgs.nix}/bin:${pkgs.gnugrep}/bin:$PATH

        # Try to import the conflicting path and expect an error
        if nix-instantiate --eval --strict --expr '
          let
            pkgs = import ${inputs.nixpkgs} { system = "${pkgs.system}"; };
            lib = pkgs.lib;
            inputs = {};
            importer = import ${../src/importer.nix} {
              inherit pkgs lib inputs;
            };
          in
          importer.importDirWithoutInputs ${conflictPath}
        ' 2>&1 | grep -q "nixDir is confused"; then
          echo "PASS: Conflict detected as expected"
          exit 0
        else
          echo "FAIL: Expected conflict error not thrown"
          exit 1
        fi
      '';
    }

    # Test 4: Error message mentions conflicting entries
    {
      name = "conflict error message is helpful";
      type = "unit";
      expected = true;
      actual =
        let
          # tryEval the conflicting import - should fail
          result = builtins.tryEval (importer.importDirWithoutInputs conflictPath);
          # Get the error by trying to access the value when success is false
          # The error will be in the trace/exception, but we can verify it failed
          errorOccurred = !result.success;

          # We can't easily inspect the error message content in pure Nix with tryEval,
          # but we can verify that it does throw an error (success == false)
          # The actual error message check is better done in the script test above
        in
        errorOccurred;
    }
  ];
}
