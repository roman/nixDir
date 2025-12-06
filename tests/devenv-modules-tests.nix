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
  devenvModulesPath = ./fixtures/devenv-modules-test;
in
{
  tests = [
    {
      name = "importDevenvModules imports regular devenv modules";
      type = "unit";
      expected = true;
      actual =
        let
          modules = importer.importDevenvModules "${devenvModulesPath}/modules/devenv";
        in
        modules ? test-module && builtins.isFunction modules.test-module;
    }

    {
      name = "importDevenvModulesWithInputs imports with-inputs devenv modules";
      type = "unit";
      expected = true;
      actual =
        let
          modules = importer.importDevenvModulesWithInputs "${devenvModulesPath}/with-inputs/modules/devenv";
        in
        modules ? with-inputs-module && builtins.isFunction modules.with-inputs-module;
    }

    {
      name = "devenv module with inputs receives inputs correctly";
      type = "unit";
      expected = true;
      actual =
        let
          modules = importer.importDevenvModulesWithInputs "${devenvModulesPath}/with-inputs/modules/devenv";
          # Call the module function with pkgs and minimal args
          evaluated = modules.with-inputs-module {
            inherit pkgs lib;
            config = {
              services.with-inputs-service.enable = false;
            };
          };
        in
        # Verify it has the _meta attribute showing it received inputs
        evaluated._meta.hasInputs == true && evaluated._meta.inputCount > 0;
    }

    {
      name = "devenv module without inputs can be evaluated";
      type = "unit";
      expected = true;
      actual =
        let
          modules = importer.importDevenvModules "${devenvModulesPath}/modules/devenv";
          module = modules.test-module;
        in
        # Verify it's a function (the module function expecting { config, lib, pkgs, ... })
        builtins.isFunction module;
    }

    {
      name = "devenv module has expected options structure";
      type = "unit";
      expected = true;
      actual =
        let
          modules = importer.importDevenvModules "${devenvModulesPath}/modules/devenv";
          module = modules.test-module;
          # Evaluate the module with minimal config
          evaluated = module {
            inherit pkgs lib;
            config = {
              services.test-service.enable = false;
            };
          };
        in
        # Verify it has options and config attributes (standard module structure)
        evaluated ? options && evaluated ? config;
    }
  ];
}
