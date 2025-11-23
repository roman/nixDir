{ pkgs, lib, inputs }:
let
  examplePath = ../example/myproj;
in
{
  tests = [
    {
      name = "example project flake.nix exists";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/flake.nix";
    }

    {
      name = "example has packages directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/packages";
    }

    {
      name = "example has devShells directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/devShells";
    }

    {
      name = "example has configurations directory";
      type = "unit";
      expected = true;
      actual = builtins.pathExists "${examplePath}/nix/configurations";
    }

    {
      name = "example packages can be evaluated";
      type = "script";
      script = ''
        cd ${examplePath}
        if nix eval .#packages.${pkgs.system} --json >/dev/null 2>&1; then
          echo "PASS: Example packages evaluate successfully"
          exit 0
        else
          echo "FAIL: Example packages failed to evaluate"
          exit 1
        fi
      '';
    }

    {
      name = "example devShells can be evaluated";
      type = "script";
      script = ''
        cd ${examplePath}
        if nix eval .#devShells.${pkgs.system} --json >/dev/null 2>&1; then
          echo "PASS: Example devShells evaluate successfully"
          exit 0
        else
          echo "FAIL: Example devShells failed to evaluate"
          exit 1
        fi
      '';
    }

    {
      name = "example hello-myproj package builds";
      type = "script";
      script = ''
        PATH=${pkgs.nix}/bin:$PATH
        cd ${examplePath}

        if nix build .#hello-myproj --no-link 2>&1 | grep -q "error:"; then
          echo "FAIL: hello-myproj package failed to build"
          exit 1
        else
          echo "PASS: hello-myproj package builds successfully"
          exit 0
        fi
      '';
    }

    {
      name = "example overlay is generated";
      type = "script";
      script = ''
        cd ${examplePath}
        if nix eval .#overlays.default --json >/dev/null 2>&1; then
          echo "PASS: Overlay is generated"
          exit 0
        else
          echo "FAIL: Overlay not generated"
          exit 1
        fi
      '';
    }

    {
      name = "example lib is available";
      type = "script";
      script = ''
        cd ${examplePath}
        if nix eval .#lib --json >/dev/null 2>&1; then
          echo "PASS: lib is available"
          exit 0
        else
          echo "FAIL: lib not available"
          exit 1
        fi
      '';
    }
  ];
}
