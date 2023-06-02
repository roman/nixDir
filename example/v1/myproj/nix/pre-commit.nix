_system: inputs: pkgs: {
  src = ../.;
  hooks = {
    alejandra.enable = true;
  };
}
