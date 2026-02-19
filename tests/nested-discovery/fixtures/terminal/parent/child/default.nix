{ pkgs }: pkgs.writeText "child" "should NOT be discovered - parent is terminal"
