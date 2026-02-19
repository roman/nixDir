# This package expects inputs as the first parameter when importWithInputs = true
flakeInputs:
{ writeText, ... }:
let
  result = {
    receivedInputs = true;
    inputCount = builtins.length (builtins.attrNames flakeInputs);
    hasNixpkgs = flakeInputs ? nixpkgs;
    hasNixDir = flakeInputs ? nixDir;
  };
in
writeText "test-package-with-inputs" (builtins.toJSON result)
