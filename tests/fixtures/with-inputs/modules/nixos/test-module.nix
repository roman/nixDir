inputs:
{ config, ... }:
{
  # Example module that receives flake inputs
  # This module uses inputs to demonstrate the with-inputs pattern

  options = { };

  config = {
    # Module receives inputs and can access them
    environment.systemPackages = [
      # Could reference inputs.some-flake.packages.${pkgs.system}.foo
    ];
  };

  # Export metadata for testing
  _meta = {
    hasInputs = true;
    inputCount = builtins.length (builtins.attrNames inputs);
  };
}
