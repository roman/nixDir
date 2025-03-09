_inputs: {
  system = "aarch64-darwin";
  modules = [
    ({ pkgs, ... }: {
      system.stateVersion = 6;
      environment.systemPackages = [ pkgs.cowsay ];
    })
  ];
}
