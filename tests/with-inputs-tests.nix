{ pkgs, lib, inputs }:
let
  importer = import ../src/importer.nix {
    inherit pkgs lib inputs;
  };

  # Test fixture paths
  withInputsPath = ./fixtures/with-inputs;
  conflictPath = ./fixtures/with-inputs-conflict;
  portableConfigPath = ./fixtures/portable-config;
in
{
  tests = [
    # Test 1: Modules in with-inputs are imported as functions
    {
      name = "with-inputs module is imported as function";
      type = "unit";
      expected = true;
      actual =
        let
          modulesPath = "${withInputsPath}/modules/nixos";
          modules = importer.importDirWithInputs modulesPath;
          module = modules.test-module;
        in
        # Modules are functions that accept { pkgs, config, ... }
        builtins.isFunction module;
    }

    # Test 2: With-inputs module can be evaluated
    {
      name = "with-inputs module can be evaluated";
      type = "unit";
      expected = true;
      actual =
        let
          modulesPath = "${withInputsPath}/modules/nixos";
          modules = importer.importDirWithInputs modulesPath;
          # Call the module function with pkgs and minimal args
          evaluated = modules.test-module { inherit pkgs; config = {}; };
        in
        # Verify it has the _meta attribute showing it received inputs
        evaluated._meta.hasInputs == true && evaluated._meta.inputCount > 0;
    }

    # Test 3: Packages in with-inputs work correctly
    {
      name = "with-inputs package can be built";
      type = "unit";
      expected = true;
      actual =
        let
          packagesPath = "${withInputsPath}/packages";
          packages = importer.importDirWithInputs packagesPath;
          # Use callPackage to instantiate the package
          package = pkgs.callPackage packages.test-pkg { };
        in
        # Verify we got a derivation
        lib.isDerivation package;
    }

    # Test 4: Package with inputs can access input attributes
    {
      name = "package with inputs receives inputs correctly";
      type = "unit";
      expected = true;
      actual =
        let
          packagesPath = "${withInputsPath}/packages";
          packages = importer.importDirWithInputs packagesPath;
          package = pkgs.callPackage packages.test-pkg { };
          # Read the package content
          content = builtins.readFile package;
        in
        # Verify the content mentions inputs
        lib.hasInfix "Input count:" content && lib.hasInfix "inputs support" content;
    }

    # Test 5: Conflict detection - both exist independently
    {
      name = "regular and with-inputs modules can both exist";
      type = "unit";
      expected = true;
      actual =
        let
          regularModulesPath = "${conflictPath}/modules/nixos";
          withInputsModulesPath = "${conflictPath}/with-inputs/modules/nixos";

          regularModules = importer.importNixOSModules regularModulesPath;
          withInputsModules = importer.importDirWithInputs withInputsModulesPath;
        in
        # Both should import successfully and have "conflicting"
        # The checkConflicts function in default.nix will catch the conflict at merge time
        (regularModules ? conflicting) && (withInputsModules ? conflicting);
    }

    # Test 6: Regular and with-inputs can coexist when no conflicts
    {
      name = "regular and with-inputs coexist without name conflicts";
      type = "unit";
      expected = true;
      actual =
        let
          withInputsModulesPath = "${withInputsPath}/modules/nixos";

          regularModules = { }; # No regular modules
          withInputsModules = importer.importDirWithInputs withInputsModulesPath;

          # Merge should work fine - no conflicts
          merged = regularModules // withInputsModules;
        in
        merged ? test-module;
    }

    # Test 7: importDirWithInputs applies inputs to files
    {
      name = "importDirWithInputs passes inputs to imported files";
      type = "unit";
      expected = true;
      actual =
        let
          modulesPath = "${withInputsPath}/modules/nixos";
          # Files in with-inputs have signature: inputs: { pkgs, ... }: ...
          # After importDirWithInputs, they should be: { pkgs, ... }: ...
          result = importer.importDirWithInputs modulesPath;
          module = result.test-module;

          # Should be a function (the inner function after inputs was applied)
          isFunction = builtins.isFunction module;

          # When called with pkgs/config, should return module definition
          evaluated = module { inherit pkgs; config = {}; };
        in
        isFunction && builtins.isAttrs evaluated;
    }

    # Test 8: Portable configurations can be imported
    {
      name = "portable configuration can be imported";
      type = "unit";
      expected = true;
      actual =
        let
          configPath = "${portableConfigPath}/configurations/nixos";
          configs = importer.importNixOSConfigurations configPath;
        in
        # Verify we got a configuration
        configs ? test-host && configs.test-host ? config;
    }
  ];
}
