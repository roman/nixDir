{ stdenv, lib }:

stdenv.mkDerivation {
  pname = "linux-only";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    echo "linux-only" > $out/result
  '';

  meta = {
    description = "A Linux-only package";
    platforms = lib.platforms.linux;
  };
}
