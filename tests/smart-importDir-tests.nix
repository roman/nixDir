{ pkgs, lib, inputs }:
let
  # Create mock inputs with testInput for scoping tests
  mockInputs = inputs // {
    testInput = {
      packages = {
        ${pkgs.system} = { testPkg = "test-package"; };
      };
    };
  };

  importer = import ../src/importer.nix {
    inherit pkgs lib;
    inputs = mockInputs;
  };

  testPath = ./fixtures/smart-import;

  # Import using smart importDir
  result = importer.importDir testPath;

  # Mock config for module evaluation
  mockConfig = {};
in
{
  tests = [
    {
      name = "imports module with inputs signature";
      type = "unit";
      expected = true;
      actual =
        let
          evaluated = result.with-inputs { inherit pkgs; config = mockConfig; };
        in
        evaluated.hasInputs;
    }

    {
      name = "module with inputs receives inputs";
      type = "unit";
      expected = true;
      actual =
        let
          evaluated = result.with-inputs { inherit pkgs; config = mockConfig; };
        in
        builtins.length evaluated.inputKeys > 0;
    }

    {
      name = "module with inputs receives pkgs";
      type = "unit";
      expected = true;
      actual =
        let
          evaluated = result.with-inputs { inherit pkgs; config = mockConfig; };
        in
        evaluated.hasPkgs;
    }

    {
      name = "imports module without inputs signature";
      type = "unit";
      expected = false;
      actual =
        let
          evaluated = result.without-inputs { inherit pkgs; config = mockConfig; };
        in
        evaluated.hasInputs;
    }

    {
      name = "module without inputs receives pkgs";
      type = "unit";
      expected = true;
      actual =
        let
          evaluated = result.without-inputs { inherit pkgs; config = mockConfig; };
        in
        evaluated.hasPkgs;
    }

    {
      name = "scoped inputs have testInput";
      type = "unit";
      expected = true;
      actual =
        let
          evaluated = result.scoped-inputs { inherit pkgs; config = mockConfig; };
        in
        evaluated.hasTestInput;
    }

    {
      name = "scoped inputs have packages attribute";
      type = "unit";
      expected = true;
      actual =
        let
          evaluated = result.scoped-inputs { inherit pkgs; config = mockConfig; };
        in
        evaluated.testInputHasPackages;
    }

    {
      name = "scoped inputs can access package directly";
      type = "unit";
      expected = true;
      actual =
        let
          evaluated = result.scoped-inputs { inherit pkgs; config = mockConfig; };
        in
        evaluated.canAccessPackage;
    }

    {
      name = "importDir returns attrset with all modules";
      type = "unit";
      expected = true;
      actual =
        result ? with-inputs &&
        result ? without-inputs &&
        result ? scoped-inputs;
    }

    {
      name = "imported values are functions";
      type = "unit";
      expected = true;
      actual =
        builtins.isFunction result.with-inputs &&
        builtins.isFunction result.without-inputs &&
        builtins.isFunction result.scoped-inputs;
    }
  ];
}
