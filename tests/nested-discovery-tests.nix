{
  pkgs,
  lib,
  inputs,
}:
let
  mkImporter =
    {
      maxDepth ? 3,
    }:
    import ../src/importer.nix {
      inherit
        pkgs
        lib
        inputs
        maxDepth
        ;
      useInputsEverywhere = false;
    };

  importer = mkImporter { };

  flatPath = ./fixtures/nested-discovery/flat;
  depth1Path = ./fixtures/nested-discovery/depth-1;
  depth2Path = ./fixtures/nested-discovery/depth-2;
  depth3Path = ./fixtures/nested-discovery/depth-3;
  hiddenPath = ./fixtures/nested-discovery/hidden;
  terminalPath = ./fixtures/nested-discovery/terminal;
  fileBlockingPath = ./fixtures/nested-discovery/file-blocking;
in
{
  tests = [
    {
      name = "flat structure: discovers directory with default.nix";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages flatPath;
        in
        result ? pkg-a;
    }

    {
      name = "flat structure: discovers .nix file";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages flatPath;
        in
        result ? pkg-b;
    }

    {
      name = "depth-1: discovers nested package";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages depth1Path;
        in
        result ? cli;
    }

    {
      name = "depth-2: discovers deeply nested package";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages depth2Path;
        in
        result ? nested-pkg;
    }

    {
      name = "depth-2: discovers package at depth 2 (within maxDepth=3)";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages depth3Path;
        in
        result ? deep-pkg;
    }

    {
      name = "depth-3: does NOT discover package at depth 3 (exceeds maxDepth=3)";
      type = "unit";
      expected = false;
      actual =
        let
          result = importer.importPackages depth3Path;
        in
        result ? too-deep;
    }

    {
      name = "hidden: skips directories starting with dot";
      type = "unit";
      expected = false;
      actual =
        let
          result = importer.importPackages hiddenPath;
        in
        result ? hidden-pkg;
    }

    {
      name = "hidden: discovers visible packages alongside hidden dirs";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages hiddenPath;
        in
        result ? visible-pkg;
    }

    {
      name = "terminal: discovers parent with default.nix";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages terminalPath;
        in
        result ? parent;
    }

    {
      name = "terminal: does NOT recurse into leaf directories";
      type = "unit";
      expected = false;
      actual =
        let
          result = importer.importPackages terminalPath;
        in
        result ? child;
    }

    {
      name = "custom maxDepth: respects maxDepth=1 limit";
      type = "unit";
      expected = false;
      actual =
        let
          shallowImporter = mkImporter { maxDepth = 1; };
          result = shallowImporter.importPackages depth2Path;
        in
        result ? nested-pkg;
    }

    {
      name = "file-blocking: foo.nix blocks foo/ traversal";
      type = "unit";
      expected = false;
      actual =
        let
          result = importer.importPackages fileBlockingPath;
        in
        result ? nested-pkg;
    }

    {
      name = "file-blocking: discovers the blocking .nix file itself";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages fileBlockingPath;
        in
        result ? blocked-dir;
    }

    {
      name = "file-blocking: discovers unblocked directories";
      type = "unit";
      expected = true;
      actual =
        let
          result = importer.importPackages fileBlockingPath;
        in
        result ? unblocked;
    }
  ];
}
