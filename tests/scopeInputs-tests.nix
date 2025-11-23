{ pkgs, lib, inputs }:
let
  importer = import ../src/importer.nix {
    inherit pkgs lib inputs;
  };

  # Create mock inputs with system-specific attributes
  mockInputs = {
    foo = {
      packages = {
        x86_64-linux = { bar = "bar-x86_64"; baz = "baz-x86_64"; };
        aarch64-darwin = { bar = "bar-aarch64"; baz = "baz-aarch64"; };
      };
      apps = {
        x86_64-linux = { myapp = "myapp-x86_64"; };
        aarch64-darwin = { myapp = "myapp-aarch64"; };
      };
      legacyPackages = {
        x86_64-linux = { legacy = "legacy-x86_64"; };
        aarch64-darwin = { legacy = "legacy-aarch64"; };
      };
      # Non-system attribute should remain unchanged
      nixosModules = { mymodule = "unchanged"; };
    };

    bar = {
      packages = {
        x86_64-linux = { qux = "qux-x86_64"; };
      };
    };
  };

  # Scope inputs to x86_64-linux
  scopedX86 = importer.scopeInputsToSystem "x86_64-linux" mockInputs;

  # Scope inputs to aarch64-darwin
  scopedAarch64 = importer.scopeInputsToSystem "aarch64-darwin" mockInputs;
in
{
  tests = [
    {
      name = "packages scoped to x86_64-linux";
      type = "unit";
      expected = "bar-x86_64";
      actual = scopedX86.foo.packages.bar;
    }

    {
      name = "apps scoped to x86_64-linux";
      type = "unit";
      expected = "myapp-x86_64";
      actual = scopedX86.foo.apps.myapp;
    }

    {
      name = "legacyPackages scoped to x86_64-linux";
      type = "unit";
      expected = "legacy-x86_64";
      actual = scopedX86.foo.legacyPackages.legacy;
    }

    {
      name = "non-system attributes unchanged";
      type = "unit";
      expected = "unchanged";
      actual = scopedX86.foo.nixosModules.mymodule;
    }

    {
      name = "packages scoped to aarch64-darwin";
      type = "unit";
      expected = "bar-aarch64";
      actual = scopedAarch64.foo.packages.bar;
    }

    {
      name = "multiple inputs scoped independently";
      type = "unit";
      expected = "qux-x86_64";
      actual = scopedX86.bar.packages.qux;
    }

    {
      name = "scoped inputs have correct attribute structure";
      type = "unit";
      expected = true;
      actual =
        scopedX86 ? foo &&
        scopedX86.foo ? packages &&
        scopedX86.foo ? apps &&
        scopedX86.foo ? legacyPackages &&
        scopedX86.foo ? nixosModules;
    }

    {
      name = "non-system attrs survive scoping";
      type = "unit";
      expected = mockInputs.foo.nixosModules;
      actual = scopedX86.foo.nixosModules;
    }
  ];
}
