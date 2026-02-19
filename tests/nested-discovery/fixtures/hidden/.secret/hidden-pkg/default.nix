{ pkgs }: pkgs.writeText "hidden-pkg" "should not be discovered"
