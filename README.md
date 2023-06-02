
# :warning: Notice 

The `main` branch is not going to get extended beyond it's current capabilities.
New functionality is going to be available in the [`/v2`
branch](https://github.com/roman/nixDir/tree/v2).

There are slight non-backward compatible differences between `main` and `v2`,
feel free to check the
[examples](https://github.com/roman/nixDir/tree/v2/example) to learn more about
how to use `nixDir`.


# nixDir

`nixDir` is a library that transforms a convention oriented directory structure
into a [nix flake](https://nixos.wiki/wiki/Flakes).

With `nixDir`, you don't run into large `flake.nix` files, and don't have to
implement the "import wiring" of multiple nix files. `nixDir` will use
[Convention over
Configuration](https://en.wikipedia.org/wiki/Convention_over_configuration) and
lets you get back to your business.

## Table Of Contents

- [Introduction](#introduction)
- [Outputs](#outputs)
  - [The `packages` output](#the-packages-output)
  - [The `lib` output](#the-lib-output)
  - [The `overlays` output](#the-overlays-output)
  - [The `nixosModules` output](#the-nixosmodules-output)
  - [The `homeManagerModules` output](#the-homemanagermodules-output)
- [Third-Party Integrations](#third-party-integrations)
  - [devenv.sh](#devenv)
  - [pre-commit-hooks](#pre-commit-hooks)
- [FAQ](#faq)

<!-- markdown-toc end -->

## Introduction

The `nixDir` library traverses a configured nix directory to build the flakes
outputs dynamically.

The behavior is easier to explain with an example; assume you have a `myproj`
directory with the following `flake.nix`:

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

With this setup, if there is no `nix` subdirectory in the `myproj`, our flake
will have no outputs.

```bash
$ nix flake show
git+file:///home/myuser/tmp/myproj?ref=refs%2fheads%2fmaster&rev=b9748c5fcb913af50bedaa8e75757b7120a6a0ba
```

If we want to introduce a new package `hello` to our project, we can add a new
file in the `myproj/nix/packages/hello.nix` file.

Once we version this new file into the repository, the `nix flake show` output
will have the new package available:

``` bash
$ nix flake show
git+file:///home/roman/myproj?ref=refs%2fheads%2fmaster&rev=<sha>
└───packages
    ├───aarch64-darwin
    │   └───hello: package 'hello'
    └───x86_64-linux
        └───hello: package 'hello'
```

`nixDir` adds the package automatically, and it does it with the `systems` that
we specified in the `nixDir` invocation in the `flake.nix` file.

Following are the various conventions that you can use with `nixDir`

## Outputs

> :information_source: The examples bellow assume the configured `nixDir` is
> called `nix`

### The `packages` output

To add new packages, add an entry in your `nix/packages` directory. The entry
may be a nix file, or a directory with a `default.nix`. The name of the
file/directory will be the name of the exported package. For example:

``` nix
# nix/packages/hello.nix

# packages receive the system, the flake inputs, and an attribute set with
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

Your package file must receive three arguments. The first argument is the
current `system` platform, the second argument are the flake's `inputs`, and the
third argument is an attribute set with all the required dependencies for the
package (e.g. `callPackage`
[convention](https://nixos.org/guides/nix-pills/callpackage-design-pattern.html)).

> :warning: Packages could either be a nix file or a directory, nixDir will fail
> if it finds both a directory and a file with the same name.

#### Remove packages from a particular `system` platform

In some situations, you may not be able to build a package for a certain
platform. `nixDir` will help you remove a package for a specific `system`
platform if the [package metadata's platforms
attribute](https://ryantm.github.io/nixpkgs/stdenv/meta/) indicates the package
is not supported by such `system`.

If a package doesn't configure the platform's metadata, `nixDir` will include
the package in every specified `system` platform by default.

### The `lib` output

To add a `lib` export to your flake, include a `nix/lib.nix` inside your.For
example:

``` nix
# nix/lib.nix 

inputs: {
  sayHello = str: builtins.trace "sayHello says: ${str}" null;
}
```

The `lib.nix` file must export a function that receives the flake inputs as
parameters.

> :information_source: Given that library functions should be system agnostic,
> the `nix/lib.nix` file does not receive the `system` argument.

### The `overlays` output

To create `overlays`, `nixDir` looks for the `nix/overlays.nix` file. This file
must receive the flake `inputs` as a parameter and return an attribute set with
every named overlay. Following is an example:

``` nix
# nix/overlays.nix

{
  self,
  nixpkgs,
  my-flake-dependency1,
  my-flake-dependency2,
  ...
}: 

let
  default = final: prev: 
    self.packages.${prev.system};
  
  develop = 
    nixpkgs.lib.composeManyExtensions [
        my-flake-dependency1.overlays.default 
        my-flake-dependency2.overlays.default
      ];
in
{
  inherit default develop; 
}
```

In the example above, we are creating two overlays, the one named `default`
includes all the packages this flake exports into the nixpkgs import. The one
named `develop` includes the overlays of some of our flake inputs.

### Using overlays in the `nixpkgs` import

There is an optional functionality to inject your flake overlays and use custom
packages across your flake. Following is an example:

``` nix
{
  # inputs = {};
  outputs = { nixDir, ... } @ inputs:
    nixDir.lib.buildFlake {
      inherit inputs;
      systems = ["x86_64-linux"];
      root = ./.;
      # We want the packages injected by the develop overlay
      # available in our flake code.
      injectOverlays = ["develop"];
    };
}
```

In the example above, the `develop` overlay (which was defined on your
`nix/overlays.nix` file and includes the overlays of some of your flake inputs)
will be included in every `nixpkgs` import used within your flake exports.

> :information_source: Given that flake overlays should be system agnostic, the
> `nix/overlays.nix` file does not receive the `system` argument.

### The `nixosModules` output

TODO

### The `homeManagerModules` output

TODO

## Third-Party Integrations

### [devenv.sh](https://devenv.sh/)
<span id="devenv"></span>

`nixDir` can run `devenv` profiles (using nix flakes porcelain) automatically.

To add a new `devenv`, add an entry in the `nix/devenvs/` folder. Following is
an example, of a very basic devenv profile.

``` nix
# nix/devenvs/my-devenv.nix

system: inputs: { config, pkgs, ... }:

{
   languages.go.enable = true;
   packages = [ inputs.self.packages.${system}.my-dance-music ];
   enterShell = ''
     echo "everybody dance now!"
   '';
}
```

In the same way we have it with other `nixDir` components, your `devenv` profile
must add two extra parameters, the first one being the current `system` and the
second one being all the inputs of your `nix flake`.

If you invoke `nix flake show`, you'll notice there is a new entry in the
`devShells` outputs called `my-devenv` (the name of the file containing the
`devenv` profile)

To run your `devenv` profile, run the `nix develop` command using the name of
the `devenv` profile.

``` bash
nix develop .#my-devenv
```

> :warning: `devenv` modules and `devShells` work on the devShells namespace,
> nixDir will fail if there is an entry on both `devenvs` and `devShells`
> directories with the same name.

#### A note on loading time

As it stands today, the `devenv` project requires many uncached dependencies
that will take some time to build. To skip long build times, we recommend
[adding their cachix](https://app.cachix.org/cache/devenv) setup, or to include
it on your flake:

``` nix
{
  description = "myproj is here to make the world a better place";
  
  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  # inputs = {};
  # outputs = {};
}
```

We do not recommend overriding `devenv` flake dependencies to skip cache misses.

### [pre-commit-hooks](https://github.com/cachix/pre-commit-hooks.nix#seamless-integration-of-pre-commit-git-hooks-with-nix)
<span id="pre-commit-hooks"></span>

`nixDir` is able to integrate a single `pre-commit-hooks.nix` to `devShells`
entries. This is an optional functionality; to enable it, you must have a
`nix/pre-commit.nix` file _and_ enable the `injectPreCommit` option (defaults to
`true`) in the `nixDir.lib.buildFlake` call. Following is an example of a pre-commit configuration.

``` nix
# nix/pre-commit.nix

system: inputs: pkgs:

{
  # root of the project
  src = ../.; 
  hooks = {
    nixfmt.enable = true;
  };
}
```

The file must receive three arguments, the current `system` platform, the flake
`inputs` and an attribute-set with the `nixpkgs` pkgs.

> :information_source: As opposed to other `nixDir` components, the
> `nix/pre-commit.nix` receives _all_ packages rather than relying on the
> `callPackage`
> [convention](https://nixos.org/guides/nix-pills/callpackage-design-pattern.html)

#### Accessing the pre-commit hook explicitly

Another side-effect that occurs when using the `nix/pre-commit.nix` is that
`nixDir` appends a `preCommitRunHook` attribute to the flake's `lib`. This
attribute contains the pre-commit script, and it may be used as a value in other
places (like a docker image). Following is an example on how to add the script
in a docker image package:

``` nix
# nix/packages/devenv-img.nix

system: {self, ...}: {
  lib,
  dockerTools,
  buildEnv,
  bashInteractive
}: let

dockerTools.buildImage {
  tag = "latest";
  name = "devenv-img";
  copyToRoot = buildEnv {
    name = "devenv-img";
    paths = [
      bashInteractive
    ];
    pathsToLink = ["/bin"];
  };
  config = {
    WorkingDir = "/tmp";
    Env = [
      # Inject pre-commit script to your container environment
      "PRE_COMMIT_HOOK=${self.lib.preCommitRunHook.${system}}"
    ];
  };
}
```


## FAQ

### Should I use this lib?

If you are maintaining a project with nix flakes that has a big `flake.nix` file
(>500 LOC) or that involves several nix files, you may benefit from this
library.

