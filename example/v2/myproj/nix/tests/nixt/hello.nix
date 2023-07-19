{ self, nixpkgs, ... } @ inputs: { describe, it }:

let
  inherit (nixpkgs) lib;
in
[
  # when using nixDir, there will always be a lib.getPkgs function
  (describe "lib"
    [
      (it "has a getPkgs function"
        (lib.hasAttrByPath [ "lib" "getPkgs" ] self))
    ])
]
