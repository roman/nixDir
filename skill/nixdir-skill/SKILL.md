---
name: nixdir-skill
description: >
  Guide for maintaining nixDir-based Nix flakes (v3). Use when adding packages,
  modules, devShells, devenvs, or configurations to projects using nixDir.
triggers:
  keywords:
    - nixDir
    - nix packages
    - flake structure
    - devenv
    - devShell
    - nix module
    - flake-parts
  file_patterns:
    - "**/flake.nix"
    - "**/devenv.nix"
    - "nix/**/*.nix"
---

# nixDir v3 Skill

nixDir is a convention-based flake structure system built as a flake-parts module.
Files are auto-discovered based on directory location and naming conventions.

## Quick Reference

| Directory                      | Flake Output                    | Strategy      | Signature                       |
|--------------------------------|---------------------------------|---------------|---------------------------------|
| `nix/packages/`                | `packages.<system>.<name>`      | callPackage   | `{ pkgs, lib, ... }: drv`       |
| `nix/devshells/`               | `devShells.<system>.<name>`     | passPkgs      | `pkgs: mkShell { }`             |
| `nix/devenvs/`                 | `devShells.<system>.<name>`     | plain         | `{ pkgs, ... }: { options }`    |
| `nix/modules/nixos/`           | `nixosModules.<name>`           | plain         | `{ config, ... }: { }`          |
| `nix/modules/darwin/`          | `darwinModules.<name>`          | plain         | `{ config, ... }: { }`          |
| `nix/modules/home-manager/`    | `homeManagerModules.<name>`     | plain         | `{ config, ... }: { }`          |
| `nix/modules/devenv/`          | `devenvModules.<name>`          | plain         | `{ config, ... }: { }`          |
| `nix/configurations/nixos/`    | `nixosConfigurations.<name>`    | plain         | `{ system, modules }`           |
| `nix/configurations/darwin/`   | `darwinConfigurations.<name>`   | plain         | `{ system, modules }`           |

## Prerequisites

nixDir is a **flake-parts module**. Configure in `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixDir.url = "github:rskew/nixDir/v3";
  };

  outputs = { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nixDir.flakeModule ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      nixDir = {
        enable = true;
        root = ./.;
        # Optional: all files receive inputs as first parameter
        # importWithInputs = true;
      };
    };
}
```

## Configuration Options

| Option | Default | Purpose |
|--------|---------|---------|
| `enable` | - | Enable nixDir discovery |
| `root` | - | Flake root directory (required) |
| `dirName` | `"nix"` | Config directory name |
| `importWithInputs` | `false` | All files receive inputs as first param |
| `filterUnsupportedSystems` | `true` | Filter packages by `meta.platforms` |
| `strictDiscovery` | `false` | Error when dirs with default.nix ignored |
| `followSymlinks` | `false` | Follow symlinks during discovery |

## Directory Conventions

### Naming Rules

- **Filenames**: Use kebab-case (e.g., `my-package.nix`)
- **Attribute names**: Derived from filename without `.nix` extension
- **Nested directories**: Organizational subdirs supported (names flattened)
- **Conflict**: Cannot have both `foo.nix` and `foo/default.nix`

### File Discovery

- Files must be git-tracked to be discovered
- `.nix` files discovered at all levels (up to maxDepth=3)
- `default.nix` in directory uses directory name as attribute
- Directories starting with `.` are skipped

## Input Access Patterns

### Standard Pattern (no inputs needed)

Most files don't need flake inputs. Use standard signatures:

```nix
# nix/packages/hello.nix (callPackage strategy)
{ pkgs, lib, stdenv, writeShellScriptBin, ... }:
writeShellScriptBin "hello" ''
  echo "Hello, world!"
''
```

### With Flake Inputs

Two options for accessing flake inputs:

**Option 1: `importWithInputs = true` (recommended)**

Configure in `flake.nix`:
```nix
nixDir = {
  enable = true;
  root = ./.;
  importWithInputs = true;
};
```

Then all files receive inputs as first parameter:
```nix
# nix/packages/my-tool.nix
inputs:                    # First argument: all flake inputs
{ pkgs, lib, ... }:        # Second argument: callPackage args
inputs.some-flake.packages.${pkgs.system}.tool
```

**Option 2: `with-inputs/` subdirectory**

Place files in parallel `nix/with-inputs/` tree:
```
nix/with-inputs/packages/my-tool.nix
```

Same signature as above. Use when only some files need inputs.

## File Signatures by Strategy

### callPackage (packages)

```nix
# nix/packages/my-pkg.nix
{ stdenv, lib, fetchFromGitHub, ... }:

stdenv.mkDerivation {
  pname = "my-pkg";
  version = "1.0.0";
  src = fetchFromGitHub { ... };
}
```

With inputs:
```nix
inputs: { stdenv, lib, ... }:
stdenv.mkDerivation { ... }
```

### passPkgs (devshells)

```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  packages = with pkgs; [ nodejs npm ];
}
```

With inputs:
```nix
inputs: pkgs:
pkgs.mkShell { ... }
```

### plain (modules, devenvs, configurations)

```nix
# nix/modules/home-manager/my-module.nix
{ pkgs, lib, config, ... }:

let cfg = config.programs.my-module;
in {
  options.programs.my-module = {
    enable = lib.mkEnableOption "my-module";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.something ];
  };
}
```

With inputs:
```nix
inputs: { pkgs, lib, config, ... }:
{ options = { }; config = { }; }
```

## devenv vs devShell Decision

### When to Use devShell (nix/devshells/)

- Simple package lists only
- Pure builds required (no `--impure`)
- Fast shell entry needed

```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  packages = with pkgs; [ nodejs npm ];
}
```

### When to Use devenv (nix/devenvs/)

- Pre-commit hooks needed (`git-hooks.hooks`)
- Background services (postgres, redis)
- Language toolchains (`languages.python.enable`)
- Process management

```nix
# nix/devenvs/default.nix
{ pkgs, ... }:

{
  packages = with pkgs; [ nodejs ];

  languages.javascript.enable = true;

  git-hooks.hooks = {
    nixfmt-rfc-style.enable = true;
    prettier.enable = true;
  };

  services.postgres.enable = true;
}
```

### Decision Matrix

| Need                   | devshells/ | devenvs/ |
|------------------------|------------|----------|
| Simple package list    | ✅         | ✅       |
| Pre-commit hooks       | ❌         | ✅       |
| Background services    | ❌         | ✅       |
| Language toolchains    | ❌         | ✅       |
| Pure builds / no flag  | ✅         | ❌       |
| Fast shell entry       | ✅         | ❌       |

## --impure Requirements

devenv requires `--impure`:

```bash
# devenv shells require --impure
nix develop --impure

# devShells are pure by default
nix develop .#my-shell
```

## Common Tasks

### Add a Package

```nix
# nix/packages/my-tool.nix
{ stdenv, lib, ... }:

stdenv.mkDerivation {
  pname = "my-tool";
  version = "1.0.0";
  src = ./src;
  meta.platforms = lib.platforms.unix;
}
```

### Add a Home-Manager Module

```nix
# nix/modules/home-manager/my-module.nix
{ pkgs, lib, config, ... }:

let cfg = config.programs.my-module;
in {
  options.programs.my-module = {
    enable = lib.mkEnableOption "my-module";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.some-package ];
  };
}
```

### Add a NixOS Module

```nix
# nix/modules/nixos/my-service.nix
{ pkgs, lib, config, ... }:

let cfg = config.services.my-service;
in {
  options.services.my-service = {
    enable = lib.mkEnableOption "my-service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.my-service = {
      wantedBy = [ "multi-user.target" ];
      script = "${pkgs.my-service}/bin/my-service --port ${toString cfg.port}";
    };
  };
}
```

### Add a nix-darwin Module

```nix
# nix/modules/darwin/my-config.nix
{ pkgs, lib, config, ... }:

let cfg = config.my-config;
in {
  options.my-config = {
    enable = lib.mkEnableOption "my-config";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.my-tool ];
    system.defaults.dock.autohide = true;
  };
}
```

### Add a devenv Module

```nix
# nix/modules/devenv/my-feature.nix
{ pkgs, lib, config, ... }:

let cfg = config.my-feature;
in {
  options.my-feature = {
    enable = lib.mkEnableOption "my-feature";
  };
  config = lib.mkIf cfg.enable {
    packages = [ pkgs.some-tool ];
    git-hooks.hooks.my-hook.enable = true;
  };
}
```

### Platform-Specific Package

```nix
# nix/packages/linux-only.nix
{ stdenv, lib, ... }:

stdenv.mkDerivation {
  pname = "linux-tool";
  version = "1.0.0";
  src = ./src;
  meta.platforms = lib.platforms.linux;  # Only on Linux
}
```

## Testing Changes

```bash
# Build a package
nix build .#my-package

# Enter a devShell
nix develop .#my-shell

# Enter a devenv (requires --impure)
nix develop --impure

# Check flake outputs
nix flake show

# Evaluate without building
nix eval .#packages.x86_64-linux.my-package.name
```

## Troubleshooting

### File not discovered

1. Ensure file is git-tracked: `git add path/to/file.nix`
2. Check for naming conflicts (both `foo.nix` and `foo/default.nix`)
3. Check nesting depth (max 3 levels by default)
4. Enable `strictDiscovery = true` to see ignored directories

### Wrong file signature

Match strategy to directory:
- `packages/` → `{ pkgs, ... }: drv`
- `devshells/` → `pkgs: mkShell {}`
- `devenvs/` → `{ pkgs, ... }: { options }`
- `modules/` → `{ config, lib, pkgs, ... }: { options; config; }`

### devenv issues

1. Always use `--impure` flag
2. Ensure devenv input is in flake.nix
3. Check devenv module imports

## Resources

For detailed information, see reference files:
- `references/CONVENTIONS.md` - Full directory mapping and naming
- `references/SIGNATURES.md` - Complete file signatures by strategy
- `references/DEVENV_VS_DEVSHELL.md` - Detailed comparison
- `references/PATTERNS.md` - Common patterns and examples
