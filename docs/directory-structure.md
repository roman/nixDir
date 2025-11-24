# Directory Structure Guide

This guide explains how to organize your Nix code using nixDir's convention-based structure.

## Overview

nixDir automatically discovers and wires up flake outputs based on where you place your
`.nix` files. Understanding this structure is key to using nixDir effectively.

## The Config Directory

By default, nixDir looks for a `nix/` directory at your flake root. You can customize this:

```nix
nixDir = {
  enable = true;
  root = ./.;
  dirName = "nix";  # Change to "_infra/nix", "config", etc.
};
```

## Complete Directory Structure

```
your-project/
├── flake.nix
└── nix/                          # Config directory (customizable)
    ├── packages/                 # Package definitions
    ├── devshells/                # Simple development shells
    ├── devenvs/                  # Devenv configurations
    ├── modules/
    │   ├── nixos/                # NixOS modules
    │   ├── darwin/               # nix-darwin modules
    │   ├── home-manager/         # home-manager modules
    │   └── devenv/               # devenv modules
    ├── configurations/
    │   ├── nixos/                # NixOS system configurations
    │   └── darwin/               # nix-darwin configurations
    └── with-inputs/              # Non-portable versions
        ├── packages/
        ├── devshells/
        ├── devenvs/
        ├── modules/
        │   ├── nixos/
        │   ├── darwin/
        │   ├── home-manager/
        │   └── devenv/
        └── configurations/
            ├── nixos/
            └── darwin/
```

## Directory Purpose and Output Mapping

### packages/

**Purpose**: Package definitions using `stdenv.mkDerivation` or similar

**Output**: `packages.<system>.<name>`

**Signature**: `{ dependency, ... }: derivation`

**Example**:
```nix
# nix/packages/my-tool.nix
{ stdenv }:

stdenv.mkDerivation {
  pname = "my-tool";
  version = "1.0.0";
  src = ./src;
}
```

**Result**: Available as `packages.x86_64-linux.my-tool` (and other systems)

### devshells/

**Purpose**: Simple development environments using `pkgs.mkShell`

**Output**: `devShells.<system>.<name>`

**Signature**: `pkgs: mkShell { ... }`

**Example**:
```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  packages = [ pkgs.git pkgs.nodejs ];
  shellHook = ''
    echo "Welcome!"
  '';
}
```

**Result**: Available via `nix develop`

**Note**: DevShell names must be unique across both `devshells/` and `devenvs/` since devenv creates devShells internally.

### devenvs/

**Purpose**: Rich development environments using [devenv](https://devenv.sh)

**Output**: `devenv.shells.<name>` (which creates `devShells.<system>.<name>`)

**Signature**: `{ pkgs, ... }: { ... }`

**Example**:
```nix
# nix/devenvs/python.nix
{ pkgs, ... }:

{
  packages = [ pkgs.git ];
  languages.python = {
    enable = true;
    version = "3.11";
  };
}
```

**Result**: Available via `nix develop .#python`

### modules/nixos/

**Purpose**: NixOS system modules

**Output**: `nixosModules.<name>`

**Signature**: `{ config, lib, pkgs, ... }: { ... }`

**Example**:
```nix
# nix/modules/nixos/my-service.nix
{ config, lib, pkgs, ... }:

{
  options.services.my-service.enable =
    lib.mkEnableOption "my service";

  config = lib.mkIf config.services.my-service.enable {
    systemd.services.my-service = {
      # service definition
    };
  };
}
```

**Usage**: Import in NixOS configuration

### modules/darwin/

**Purpose**: nix-darwin modules

**Output**: `darwinModules.<name>`

**Signature**: Same as NixOS modules

### modules/home-manager/

**Purpose**: home-manager modules

**Output**: `homeManagerModules.<name>`

**Signature**: Same as NixOS modules

### modules/devenv/

**Purpose**: Reusable devenv module definitions

**Output**: `devenvModules.<name>`

**Signature**: Standard devenv module

**Note**: These can be automatically imported into all devenvs using the option
`installAllDevenvModules`

### configurations/nixos/

**Purpose**: Complete NixOS system configurations

**Output**: `nixosConfigurations.<name>`

**Signature**: `{ system = "..."; modules = [ ... ]; }`

**Example**:
```nix
# nix/configurations/nixos/my-host.nix
{
  system = "x86_64-linux";
  modules = [
    # Your modules here
  ];
}
```

### configurations/darwin/

**Purpose**: Complete nix-darwin configurations

**Output**: `darwinConfigurations.<name>`

**Signature**: Same as NixOS configurations

## File vs Directory Naming

You can define items in two ways:

### Single File

```
packages/
└── hello.nix
```

**When to use**: Simple, self-contained definitions

### Directory with default.nix

```
packages/
└── hello/
    ├── default.nix
    ├── builder.sh
    └── patches/
        └── fix.patch
```

**When to use**: Complex definitions needing multiple files

**Both create the same output**: `packages.<system>.hello`

## File Naming Conventions

### Name Format

- Use **kebab-case**: `my-package.nix`, `my-module.nix`
- Avoid special characters except `-` and `_`
- The filename (without `.nix`) becomes the attribute name

Examples:
```
packages/hello-world.nix  → packages.<system>.hello-world
modules/nixos/my-svc.nix  → nixosModules.my-svc
devshells/python-env.nix  → devShells.<system>.python-env
```

### Reserved Names

- `default.nix` inside a directory is special (see above)
- `default` as a name is valid: `packages/default.nix` → `packages.<system>.default`

## The with-inputs/ Directory

The `with-inputs/` directory is for definitions that need access to flake inputs.

Files in `with-inputs/` receive an extra `inputs` parameter at the beginning of their
function signature. For example:
- Regular: `{ pkgs }:`
- With-inputs: `inputs: { pkgs }:`

See [With-Inputs Pattern](./with-inputs.md) for comprehensive details, examples, and use cases.

## Conflict Detection

### Same-Directory Conflicts

You **cannot** have both a file and a directory with the same name:

```
# ❌ ERROR: Conflict!
packages/
├── foo.nix
└── foo/
    └── default.nix
```

nixDir will throw an error explaining the conflict.

### Cross-Directory Conflicts

You **cannot** have the same name in both regular and `with-inputs/` directories:

```
# ❌ ERROR: Conflict!
packages/
└── hello.nix
with-inputs/packages/
└── hello.nix
```

**Solution**: Use different names or choose one location.

### Cross-Type Conflicts (devShells vs devenvs)

DevShell and devenv names must be **unique across both types**:

```
# ❌ ERROR: Conflict!
devshells/
└── default.nix
devenvs/
└── default.nix
```

This is because devenv creates devShells internally.

## Best Practices

### 1. Prefer Standard modules

Use regular directories (not `with-inputs/`) whenever possible:

```
# ✅ Good - no external dependencies needed
packages/my-tool.nix

# ⚠️  Only if you really need inputs
with-inputs/packages/my-tool.nix
```

### 2. Use Descriptive Names

Names should be clear and specific:

```
# ✅ Good
devshells/python-data-science.nix
packages/backend-api.nix

# ❌ Avoid
devshells/shell2.nix
packages/stuff.nix
```

### 3. Keep Files Focused

Each file should define one primary thing:

```
# ✅ Good
packages/
├── frontend.nix
└── backend.nix

# ❌ Avoid
packages/
└── all-services.nix  # Defines multiple packages
```

## Example Structures

### Simple Project

```
my-app/
├── flake.nix
└── nix/
    ├── packages/
    │   └── my-app.nix
    └── devshells/
        └── default.nix
```

### Medium Project

```
my-project/
├── flake.nix
└── nix/
    ├── packages/
    │   ├── cli.nix
    │   └── server/
    │       ├── default.nix
    │       └── config.yaml
    ├── devshells/
    │   ├── default.nix
    │   └── ci.nix
    └── modules/
        └── nixos/
            └── my-service.nix
```

### Complex Project

```
platform/
├── flake.nix
└── nix/
    ├── packages/
    │   ├── api/
    │   ├── frontend/
    │   └── cli/
    ├── devshells/
    │   ├── backend.nix
    │   └── frontend.nix
    ├── devenvs/
    │   └── full-stack.nix
    ├── modules/
    │   ├── nixos/
    │   │   ├── api-service.nix
    │   │   └── database.nix
    │   └── darwin/
    │       └── dev-tools.nix
    ├── configurations/
    │   ├── nixos/
    │   │   ├── production.nix
    │   │   └── staging.nix
    │   └── darwin/
    │       └── developer-machine.nix
    └── with-inputs/
        ├── packages/
        │   └── integrated-tool.nix
        └── modules/
            └── nixos/
                └── external-service.nix
```

## Troubleshooting

### Files Not Discovered

**Problem**: Your file isn't showing up in flake outputs

**Check**:
1. Is the file git-tracked? Run `git add <file>`
2. Is the file in the correct directory?
3. Does the file have a `.nix` extension?
4. Run `nix flake show` to see current outputs

### Unexpected Attribute Names

**Problem**: The output name isn't what you expected

**Solution**: Check your filename:
- `my-package.nix` → `my-package` (not `myPackage`)
- Remove the `.nix` extension from the attribute name
- Directory names don't matter, only the final file/directory name

### Import Errors

**Problem**: Getting "attribute X not found" or "function called with unexpected argument"

**Solutions**:
- Check function signature matches the directory type
- For `with-inputs/`, ensure you have the `inputs:` parameter
- For regular dirs, ensure you don't have `inputs:` parameter

## See Also

- [Getting Started](./getting-started.md) - Initial setup
- [With-Inputs Pattern](./with-inputs.md) - Using flake inputs
- [Testing](./testing.md) - Testing your setup
- [Example Project](../example/myproj) - Real-world usage
