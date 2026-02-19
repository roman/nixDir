{ stdenv }:

stdenv.mkDerivation {
  pname = "specific-systems";
  version = "1.0.0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    echo "specific-systems" > $out/result
  '';

  meta = {
    description = "Package for specific systems only";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
