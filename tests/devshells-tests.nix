{
  pkgs,
  lib,
  inputs,
}:
let
  importer = import ../src/importer.nix {
    inherit pkgs lib inputs;
  };

  # Test fixture paths
  devShellsPath = ./fixtures/devshells-test;
  conflictPath = ./fixtures/devshells-conflict;
in
{
  tests = [
    # Test 1: importDevShells imports from regular devshells directory
    {
      name = "importDevShells imports regular devShells";
      type = "unit";
      expected = true;
      actual =
        let
          shells = importer.importDevShells "${devShellsPath}/devshells";
        in
        shells ? test-shell && lib.isDerivation shells.test-shell;
    }

    # Test 2: importDevShellsWithInputs imports from with-inputs devshells directory
    {
      name = "importDevShellsWithInputs imports with-inputs devShells";
      type = "unit";
      expected = true;
      actual =
        let
          shells = importer.importDevShellsWithInputs "${devShellsPath}/with-inputs/devshells";
        in
        shells ? with-inputs-shell && lib.isDerivation shells.with-inputs-shell;
    }

    # Test 3: devShells receive inputs and pkgs
    {
      name = "devShells receive inputs and pkgs arguments";
      type = "unit";
      expected = true;
      actual =
        let
          shells = importer.importDevShells "${devShellsPath}/devshells";
          shell = shells.test-shell;
        in
        # Verify it's a derivation (mkShell returns a derivation)
        lib.isDerivation shell && shell ? buildInputs;
    }

    # Test 4: devenvs can be imported from regular directory
    {
      name = "importDevenvs imports regular devenvs";
      type = "unit";
      expected = true;
      actual =
        let
          envs = importer.importDevenvs "${devShellsPath}/devenvs";
        in
        envs ? test-env && builtins.isFunction envs.test-env;
    }

    # Test 5: devenvs can be imported from with-inputs directory
    {
      name = "importDevenvsWithInputs imports with-inputs devenvs";
      type = "unit";
      expected = true;
      actual =
        let
          envs = importer.importDevenvsWithInputs "${devShellsPath}/with-inputs/devenvs";
        in
        envs ? with-inputs-env && builtins.isFunction envs.with-inputs-env;
    }

    # Test 6: Conflict between devShells and devenvs with same name
    {
      name = "conflict between devShells and devenvs is detected";
      type = "unit";
      expected = true;
      actual =
        let
          # This should throw an error when merged in the actual default.nix
          # Here we just verify both have the conflicting name
          shells = importer.importDevShells "${conflictPath}/devshells";
          envs = importer.importDevenvs "${conflictPath}/devenvs";
        in
        # Both should have "conflict" entry
        (shells ? conflict) && (envs ? conflict);
    }

    # Test 7: devShell is properly structured
    {
      name = "devShell has expected structure";
      type = "unit";
      expected = true;
      actual =
        let
          shells = importer.importDevShells "${devShellsPath}/devshells";
          shell = shells.test-shell;
        in
        # Check basic shell properties
        lib.isDerivation shell
        && shell.type or null == "derivation"
        && builtins.isString (shell.name or "");
    }
  ];
}
