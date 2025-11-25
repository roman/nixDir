{
  pkgs,
  lib,
  inputs,
}:
let
  flakeLib = import ../lib.nix {
    inherit lib;
    dirName = "nix";
  };

  importer = import ../src/importer.nix {
    inherit pkgs lib inputs;
  };

  fixturesPath = ./fixtures/platform-filtering/packages;
  testPackages = importer.importPackages fixturesPath;

  inherit (flakeLib) filterByPlatform;

  x86_64_linux = "x86_64-linux";
  aarch64_linux = "aarch64-linux";
  x86_64_darwin = "x86_64-darwin";
  aarch64_darwin = "aarch64-darwin";
in
{
  tests = [
    {
      name = "all-platforms package available on x86_64-linux";
      type = "unit";
      expected = true;
      actual =
        let
          filtered = filterByPlatform x86_64_linux testPackages;
        in
        filtered ? all-platforms;
    }

    {
      name = "all-platforms package available on aarch64-darwin";
      type = "unit";
      expected = true;
      actual =
        let
          filtered = filterByPlatform aarch64_darwin testPackages;
        in
        filtered ? all-platforms;
    }

    {
      name = "linux-only package available on x86_64-linux";
      type = "unit";
      expected = true;
      actual =
        let
          filtered = filterByPlatform x86_64_linux testPackages;
        in
        filtered ? linux-only;
    }

    {
      name = "linux-only package filtered out on x86_64-darwin";
      type = "unit";
      expected = false;
      actual =
        let
          filtered = filterByPlatform x86_64_darwin testPackages;
        in
        filtered ? linux-only;
    }

    {
      name = "darwin-only package available on x86_64-darwin";
      type = "unit";
      expected = true;
      actual =
        let
          filtered = filterByPlatform x86_64_darwin testPackages;
        in
        filtered ? darwin-only;
    }

    {
      name = "darwin-only package filtered out on aarch64-linux";
      type = "unit";
      expected = false;
      actual =
        let
          filtered = filterByPlatform aarch64_linux testPackages;
        in
        filtered ? darwin-only;
    }

    {
      name = "broken package filtered out on x86_64-linux";
      type = "unit";
      expected = false;
      actual =
        let
          filtered = filterByPlatform x86_64_linux testPackages;
        in
        filtered ? broken-package;
    }

    {
      name = "broken package filtered out on x86_64-darwin";
      type = "unit";
      expected = false;
      actual =
        let
          filtered = filterByPlatform x86_64_darwin testPackages;
        in
        filtered ? broken-package;
    }

    {
      name = "specific-systems package available on x86_64-linux";
      type = "unit";
      expected = true;
      actual =
        let
          filtered = filterByPlatform x86_64_linux testPackages;
        in
        filtered ? specific-systems;
    }

    {
      name = "specific-systems package available on aarch64-linux";
      type = "unit";
      expected = true;
      actual =
        let
          filtered = filterByPlatform aarch64_linux testPackages;
        in
        filtered ? specific-systems;
    }

    {
      name = "specific-systems package filtered out on x86_64-darwin";
      type = "unit";
      expected = false;
      actual =
        let
          filtered = filterByPlatform x86_64_darwin testPackages;
        in
        filtered ? specific-systems;
    }

    {
      name = "correct number of packages on x86_64-linux";
      type = "unit";
      expected = 3;
      actual =
        let
          filtered = filterByPlatform x86_64_linux testPackages;
        in
        builtins.length (builtins.attrNames filtered);
    }

    {
      name = "correct number of packages on x86_64-darwin";
      type = "unit";
      expected = 2;
      actual =
        let
          filtered = filterByPlatform x86_64_darwin testPackages;
        in
        builtins.length (builtins.attrNames filtered);
    }

    {
      name = "empty platforms list filters out package";
      type = "unit";
      expected = false;
      actual =
        let
          emptyPlatformsPkg = pkgs.hello.overrideAttrs (old: {
            meta = (old.meta or { }) // {
              platforms = [ ];
            };
          });
          testSet = {
            empty-platforms = emptyPlatformsPkg;
          };
          filtered = filterByPlatform x86_64_linux testSet;
        in
        filtered ? empty-platforms;
    }

    {
      name = "invalid platforms value filters out package";
      type = "unit";
      expected = false;
      actual =
        let
          invalidPlatformsPkg = pkgs.hello.overrideAttrs (old: {
            meta = (old.meta or { }) // {
              platforms = "not-a-list";
            };
          });
          testSet = {
            invalid-platforms = invalidPlatformsPkg;
          };
          filtered = filterByPlatform x86_64_linux testSet;
        in
        filtered ? invalid-platforms;
    }
  ];
}
