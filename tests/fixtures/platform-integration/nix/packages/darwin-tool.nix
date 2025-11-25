{ stdenv, lib }:

stdenv.mkDerivation {
  pname = "darwin-tool";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    echo "#!/bin/sh" > $out/bin/darwin-tool
    echo "echo 'Darwin tool works!'" >> $out/bin/darwin-tool
    chmod +x $out/bin/darwin-tool
  '';

  meta = {
    description = "A macOS-only tool";
    platforms = lib.platforms.darwin;
  };
}
