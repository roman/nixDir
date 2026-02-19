{ stdenv }:

stdenv.mkDerivation {
  pname = "all-platforms";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    echo "all-platforms" > $out/result
  '';
}
