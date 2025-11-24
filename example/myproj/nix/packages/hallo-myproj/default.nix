{
  hello,
  makeWrapper,
  symlinkJoin,
}:
# We are going to do an essential wrapping of the hello package, following steps
# from: https://nixos.wiki/wiki/Nix_Cookbook#Wrapping_packages
symlinkJoin {
  name = "hallo-myproj";
  paths = [ hello ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/hello --add-flags "-g hallo, welt"
    mv $out/bin/hello $out/bin/hallo
  '';
}
