{ stdenv }:

stdenv.mkDerivation {
  pname = "broken-package";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    echo "broken" > $out/result
  '';

  meta = {
    description = "A broken package";
    broken = true;
  };
}
