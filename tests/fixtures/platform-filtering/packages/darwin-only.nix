{ stdenv, lib }:

stdenv.mkDerivation {
  pname = "darwin-only";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    echo "darwin-only" > $out/result
  '';

  meta = {
    description = "A macOS-only package";
    platforms = lib.platforms.darwin;
  };
}
