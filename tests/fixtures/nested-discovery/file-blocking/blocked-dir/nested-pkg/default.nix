{ pkgs }: pkgs.writeText "nested-pkg" "should NOT be discovered - blocked by blocked-dir.nix"
