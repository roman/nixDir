# lib.nix receives the flake inputs as a parameter
inputs: {
  sayHello = str: builtins.trace "sayHello says: ${str}" null;
}
