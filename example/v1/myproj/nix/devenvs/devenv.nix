_system: _inputs: { pkgs
                  , config
                  , ...
                  }: {
  config = {
    packages = [ pkgs.hello ];
    languages.go.enable = true;
    processes = {
      silly-example.exec = "while true; do echo hello && sleep 1; done";
    };
    enterShell = ''
      echo "enterShell worked"
    '';
  };
}
