{ stdenv, lib }:

stdenv.mkDerivation {
  pname = "linux-tool";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    echo "#!/bin/sh" > $out/bin/linux-tool
    echo "echo 'Linux tool works!'" >> $out/bin/linux-tool
    chmod +x $out/bin/linux-tool
  '';

  meta = {
    description = "A Linux-only tool";
    platforms = lib.platforms.linux;
  };
}
