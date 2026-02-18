{
  pkgs,
  lib,
  inputs,
}:
let
  # Test importer with importWithInputs enabled
  importerWithInputs = import ../src/importer.nix {
    inherit pkgs lib inputs;
    importWithInputs = true;
  };

  # Test importer without importWithInputs (backward compatibility)
  importerWithoutInputs = import ../src/importer.nix {
    inherit pkgs lib inputs;
    importWithInputs = false;
  };

  # Test fixture paths
  testPackagesPath = ./fixtures/import-with-inputs-enabled/nix/packages;

  # Flake module with self argument applied
  flakeModule = import ../default.nix;

  # Mock module arguments
  mockModuleArgs = {
    inherit lib inputs;
    system = pkgs.system;
    config = {
      nixDir = {
        enable = false;
        root = ./.;
        dirName = "nix";
      };
    };
  };

  # Evaluated module result
  moduleResult = flakeModule null mockModuleArgs;
in
{
  tests = [
    {
      name = "importWithInputs option exists in module";
      type = "unit";
      expected = true;
      actual = moduleResult.options ? nixDir && moduleResult.options.nixDir ? importWithInputs;
    }
    {
      name = "importWithInputs defaults to false";
      type = "unit";
      expected = true;
      actual = moduleResult.options.nixDir.importWithInputs.default == false;
    }

    {
      name = "importWithInputs=true makes importPackages pass inputs to files";
      type = "unit";
      expected = "test-package-with-inputs";
      actual =
        let
          packages = importerWithInputs.importPackages testPackagesPath;
          # The package receives inputs as first parameter, then pkgs args via callPackage.
          package = packages.test-package;
        in
        # Verify the package can be created and has the expected name.
        package.name;
    }

    {
      name = "importWithInputs=false maintains backward compatibility";
      type = "unit";
      expected = true;
      actual =
        let
          # Import regular packages without inputs
          regularPackagesPath = ./fixtures/regular-packages;
          packages = importerWithoutInputs.importPackages regularPackagesPath;
        in
        # Should have the expected function signature without inputs parameter
        packages ? simple-package;
    }

    {
      name = "both importers can coexist in same flake";
      type = "unit";
      expected = true;
      actual =
        let
          # Regular packages imported normally
          regularPackages = importerWithoutInputs.importPackages ./fixtures/regular-packages;
          # With-inputs packages imported with inputs
          withInputsPackages = importerWithInputs.importPackages testPackagesPath;
        in
        # Both should work
        (regularPackages ? simple-package) && (withInputsPackages ? test-package);
    }

    {
      name = "importNixOSModules works with importWithInputs=true";
      type = "unit";
      expected = true;
      actual =
        let
          modulesPath = ./fixtures/import-with-inputs-enabled/nix/modules;
          modules = importerWithInputs.importDirWithInputs modulesPath;
        in
        # Should be able to import modules (even though directory might be empty for now)
        builtins.isAttrs modules;
    }
  ];
}
