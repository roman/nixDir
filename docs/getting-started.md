# Getting Started with nixDir

This guide will help you start using nixDir in your Nix flake projects.

## Prerequisites

- Nix with flakes enabled
- Basic familiarity with Nix flakes
- A project you want to add nixDir to (or start a new one)

## Installation

### New Project

Starting a new project? Create a basic flake structure:

```bash
mkdir my-project
cd my-project
git init
```

### Add nixDir to Your Flake

Edit your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixDir.url = "github:roman/nixDir/v3";
  };

  outputs = { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports = [ inputs.nixDir.flakeModule ];

      nixDir = {
        enable = true;
        root = ./.;
      };
    };
}
```

> **Warning**
> Remember to run `git add flake.nix nix` before building. Nix flakes only see git-tracked files.

## Your First Package

Let's create a simple package to see nixDir in action.

### 1. Create the Directory Structure

```bash
mkdir -p nix/packages
```

### 2. Create a Package

Create `nix/packages/hello.nix`:

```nix
{ stdenv, writeTextFile }:

stdenv.mkDerivation {
  pname = "hello-nixdir";
  version = "1.0.0";

  src = writeTextFile {
    name = "hello.sh";
    text = ''
      #!/bin/sh
      echo "Hello from nixDir!"
    '';
    executable = true;
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/hello-nixdir
  '';
}
```

### 3. Build It

```bash
# Add files to git (required for flakes!)
git add nix/packages/hello.nix flake.nix

# Build the package
nix build .#hello

# Run it
./result/bin/hello-nixdir
```

Expected output:
```
Hello from nixDir!
```

That's it! nixDir automatically:
- Found `nix/packages/hello.nix`
- Created the output `packages.<system>.hello`
- Made it available to `nix build`

## Understanding What Happened

nixDir follows these conventions:

| File Location | Becomes |
|--------------|---------|
| `nix/packages/NAME.nix` | `packages.<system>.NAME` |
| `nix/packages/NAME/default.nix` | `packages.<system>.NAME` |

nixDir automatically:
1. Scanned the `nix/packages/` directory
2. Found your `hello.nix` file
3. Imported it with `pkgs.callPackage`
4. Exposed it as a flake output

## Next Steps

### Create a Development Shell

Create `nix/devshells/default.nix`:

```nix
pkgs:

pkgs.mkShell {
  packages = [
    pkgs.hello
    pkgs.cowsay
  ];

  shellHook = ''
    echo "Welcome to your nixDir development environment!"
  '';
}
```

Use it:

```bash
git add nix/devshells/default.nix
nix develop
# You're now in a shell with hello and cowsay available
```

### Create a NixOS Module

Create `nix/modules/nixos/my-service.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  options.services.my-service = {
    enable = lib.mkEnableOption "my service";
  };

  config = lib.mkIf config.services.my-service.enable {
    environment.systemPackages = [ pkgs.hello ];
  };
}
```

This automatically becomes available as `nixosModules.my-service` in your flake outputs!

## Configuration Options

The minimal configuration requires only `enable` and `root`. For all available options and
their descriptions, see the [example project's flake.nix](../example/myproj/flake.nix) which
demonstrates every configuration option with comments.

## Common Patterns

### Organizing Complex Packages

For packages with multiple files, use a directory with `default.nix`. See [Directory
Structure](./directory-structure.md#file-vs-directory-naming) for details.

### Using with-inputs for Non-Portable Code

When you need to access other flake inputs in your packages or modules, you can use the
`with-inputs/` directory pattern. Files in `with-inputs/` receive an extra `inputs`
parameter.

See [With-Inputs Pattern](./with-inputs.md) for complete details and examples.

## Troubleshooting

### Files Not Being Discovered

**Problem**: Your package/module isn't showing up in flake outputs

**Solutions**:
1. Make sure files are git-tracked: `git add <file>` or `git add -N <file>`
2. Verify file has `.nix` extension
3. Check the file is in the correct directory
4. Run `nix flake show` to see current outputs

### Conflict Errors

**Problem**: Error about conflicting entries

**Solution**: You can't have the same name in both regular and `with-inputs/` directories:

```
# ❌ Not allowed
nix/packages/foo.nix
nix/with-inputs/packages/foo.nix

# ✅ Pick one location per package
nix/packages/foo.nix
nix/with-inputs/packages/bar.nix
```

### Build Fails with "attribute not found"

**Problem**: Package dependencies aren't available

**Solution**: Make sure your package function signature matches what `callPackage` provides:

```nix
# ✅ Good - only request what you need
{ stdenv }:

# ❌ Bad - requesting non-existent attribute
{ myCustomThing }:  # myCustomThing doesn't exist in nixpkgs
```

## What's Next?

- Read [Directory Structure](./directory-structure.md) for comprehensive conventions
- Explore [With-Inputs Pattern](./with-inputs.md) for advanced usage
- Check out the [example project](../example/myproj/) for real-world patterns
- Learn about [Testing](./testing.md) your nixDir-based projects

## Getting Help

- [GitHub Issues](https://github.com/roman/nixDir/issues)
- [GitHub Discussions](https://github.com/roman/nixDir/discussions)
