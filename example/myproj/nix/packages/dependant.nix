{
  hello-myproj,
  hallo-myproj,
  devenv,
  writeText,
}:

writeText "dependant.txt" ''
  This derivation can access packages defined only in this flake and
  packages defined in the devenv overlay, thanks to the nixDir configuration
  - hello-myproj: ${hello-myproj}
  - hallo-myproj: ${hallo-myproj}
  - devenv v${devenv.version}
''
