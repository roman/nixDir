{ pkgs }: pkgs.writeText "too-deep" "should NOT be discovered - at depth 3, exceeds maxDepth=3"
