inputs: { pkgs, config, ... }: {
  # Module that expects inputs as first argument
  hasInputs = true;
  inputKeys = builtins.attrNames inputs;
  hasPkgs = pkgs ? system;
}
