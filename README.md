# nixDir

`nixDir` is a library that transforms a directory structure into a [nix
flake](https://nixos.wiki/wiki/Flakes).

With `nixDir`, you don't run into large `flake.nix` files, and don't have to
implement the "import wiring" of multiple nix files. `nixDir` will discover all
the files and directories that follow a predefined convention and let you do
your business quickly.

## Introduction

When using `nix flake` commands and your `flake.nix` file uses `nixDir`, the
library will traverse a specified directory (a nix directory) to fill the flakes
outputs.

The behavior is easier to explain with an example, assume you have a `myproj`
directory with the following `flake.nix`

``` nix
{
  description = "myproj is here to make the world a better place";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixDir = {
      url = "github:roman/nixDir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixDir, ...} @ inputs: nixDir.lib.buildFlake {
    systems = [ "x86_64-linux" "aarch64-darwin" ];
    root = ./.;
    dirName = "nix"; # (default)
    inputs = inputs;
  };
}
```

With the setup from the example above, if there is no `nix` subdirectory in the
`myproj`, our flake will have no outputs.

```bash
$ nix flake show
git+file:///home/myuser/tmp/myproj?ref=refs%2fheads%2fmaster&rev=b9748c5fcb913af50bedaa8e75757b7120a6a0ba
```

Now, say we want to introduce a new package `hello` that our project needs as a
(vital) dependency; instead of doing the same old dance of adding
[`flake-utils`](https://github.com/numtide/flake-utils) and updating our
`flake.nix`, we can instead add a new file in the
`myproj/nix/packages/hello.nix` file.

``` nix
# packages receive the system, the flake inputs, and a attribute set with
# required nixpkgs packages.
system: inputs: { hello, writeShellScriptBin, makeWrapper, symlinkJoin }:

# We are going to do an essential wrapping of the hello package, following steps
# from: https://nixos.wiki/wiki/Nix_Cookbook#Wrapping_packages
symlinkJoin {
  name = "hello";
  paths = [ hello ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/hello --add-flags "-t"
  '';
}
```

Once we version this new file and check the `nix flake show` output: 

``` bash
$ nix flake show
git+file:///home/rgonzalez/tmp/myproj?ref=refs%2fheads%2fmaster&rev=b8b27cb3dda9fa5d1e2a5329cf26fce24fa05955
└───packages
    ├───aarch64-darwin
    │   └───hello: package 'hello'
    └───x86_64-linux
        └───hello: package 'hello'
```

`nixDir` adds a package automatically, and it does it with the `systems` that we
specified in the `nixDir` invocation in the `flake.nix` file.

We could also add a directory `myproj/nix/packages/hello` with a `default.nix`
to get the same result, if our package requires more files.

## Available conventions

* When `nix/lib.nix` is available, `nixDir` expects the file to export a
  function that receives the flake inputs and returns an attribute set of
  utility functions.

* When `nix/overlays.nix` is available, `nixDir` expects the file to export a
  function that receives the flake inputs and returns an attribute set of
  overlay functions. Note when a `package` or `devShell` file receives the
  attribute set of `nixpkgs`, it will include these overlays, _except_ the one
  named `default`.
  
* When a `nix/devShells/<name>.nix` is available, `nixDir` expects the file to
  export a function that receives the current system, flake inputs and nixpkgs
  attrset and returns a
  [`mkShell`](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell)
  invocation.
  
* When `nix/pre-commit.nix` is available, `nixDir` expects the file to export a
  function that receives the current system, flake inputs and nixpkgs attrset
  and returns a
  [pre-commit-hoos.nix](https://github.com/cachix/pre-commit-hooks.nix)
  configuration.

  - When `nixDir.lib.buildFlake` is called with with the `injectPreCommit`
    parameter (defaults to `true`), the pre-commit hook is going to get injected
    automatically in every entry of the `devShells` folder.

    Another side-effect is that `self.lib.preCommitRunHook.$system` will to
    contain the appropiate shell hook.


## FAQ

### Should I use this lib?

If you are maintaining a project with nix flakes that has a big `flake.nix` file
(>500 LOC) or that involves several nix files, you may benefit from this
library.

