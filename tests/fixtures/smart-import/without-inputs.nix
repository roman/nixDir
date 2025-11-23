{ pkgs, config, ... }: {
  # Module that only expects module args
  hasInputs = false;
  hasPkgs = pkgs ? system;
}
