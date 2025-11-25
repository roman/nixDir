{ stdenv }:

stdenv.mkDerivation {
  pname = "universal-tool";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    echo "#!/bin/sh" > $out/bin/universal-tool
    echo "echo 'Universal tool works!'" >> $out/bin/universal-tool
    chmod +x $out/bin/universal-tool
  '';

  meta = {
    description = "A universal tool available on all platforms";
  };
}
