{ pkgs, ... }: {
  config = {
    packages = [ pkgs.cowsay ];
    languages.go.enable = true;

    # use regular devenv functionality
    enterShell = ''
      cowsay "myproj demo"
    '';

    # define a process in-line in the devenv configuration
    processes = {
      silly-example.exec = "while true; do echo silly-example && sleep 1; done";
    };

    # or use the settings defined in the nix/modules/devenv/my-hello-service
    # directory.
    #
    # This can only work if the installDevenvModules is defined
    services.my-hello.enable = true;
  };
}
