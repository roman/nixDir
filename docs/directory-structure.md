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

**Platform-Specific Packages**:

By default, nixDir filters packages based on their `meta.platforms` attribute. Packages without
this attribute are available on all systems.

```nix
# nix/packages/linux-only-tool.nix
{ stdenv, lib }:

stdenv.mkDerivation {
  pname = "linux-only-tool";
  version = "1.0.0";
  src = ./src;

  meta = {
    description = "A tool that only works on Linux";
    platforms = lib.platforms.linux;  # Only available on Linux systems
  };
}
```

Common platform specifications:
- `lib.platforms.linux` - All Linux systems
- `lib.platforms.darwin` - All macOS systems
- `lib.platforms.unix` - All Unix-like systems
- `[ "x86_64-linux" "aarch64-linux" ]` - Specific systems only

Packages with `meta.broken = true` are automatically filtered out. To disable platform filtering,
set `nixDir.filterUnsupportedSystems = false` in your flake configuration.

**Important Note**: Platform filtering is automatically disabled when `generateAllPackage = true`
to avoid infinite recursion with the flake overlay. If you need platform filtering with the
"all" package, consider disabling `generateAllPackage` and creating your own aggregate package,
or manually set `filterUnsupportedSystems = false`.

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

> [!NOTE]
> DevShell names must be unique across both `devshells/` and `devenvs/` since devenv creates devShells internally.

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

> [!NOTE]
> These can be automatically imported into all devenvs using the option
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

You can define items in three ways:

### Single File at Root

```
packages/
└── hello.nix
```

**When to use**: Simple, self-contained definitions

**Output**: `packages.<system>.hello`

### Single File in Organizational Directory

```
packages/
└── utils/
    └── helper.nix
```

**When to use**: Grouping related packages without creating separate directories for each

**Output**: `packages.<system>.helper` (organizational directories don't affect the name)

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

**Output**: `packages.<system>.hello`

You can combine these patterns:

```
packages/
├── simple.nix                    # → packages.<system>.simple
├── utils/
│   ├── helper.nix                # → packages.<system>.helper
│   └── formatter/
│       └── default.nix           # → packages.<system>.formatter
└── tools/
    └── cli/
        └── default.nix           # → packages.<system>.cli
```

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

## Accessing Flake Inputs

There are two ways to give your files access to flake inputs:

### Option 1: The `importWithInputs` Configuration Option

Enable all files to receive inputs by default:

```nix
nixDir = {
  enable = true;
  root = ./.;
  importWithInputs = true;  # All files receive inputs
};
```

With this option, all files in regular directories receive `inputs` as their first parameter:

```nix
# nix/packages/my-package.nix (with importWithInputs = true)
inputs: { pkgs, ... }:
pkgs.writeShellScript "hello" ''
  echo "Using ${inputs.some-input}"
''
```

**When to use**: You're committed to nixDir and want all files in one place (simpler navigation).

**Tradeoff**: Makes all files non-portable (they require nixDir to provide inputs).

### Option 2: The `with-inputs/` Directory Pattern

Use parallel directory structure for files that need inputs:

```
nix/
├── packages/          # Portable packages
│   └── simple.nix
└── with-inputs/
    └── packages/      # Packages needing inputs
        └── complex.nix
```

Files in `with-inputs/` receive an extra `inputs` parameter:
- Regular: `{ pkgs }:`
- With-inputs: `inputs: { pkgs }:`

**When to use**: You want portable files that can work outside nixDir, or need a mix of portable and non-portable files.

**Tradeoff**: Requires maintaining parallel directory structures (more cognitive overhead).

See [With-Inputs Pattern](./with-inputs.md) for comprehensive details, examples, and choosing between these approaches.

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
    │   ├── utils/
    │   │   ├── helper.nix        # Organized in subdirectory
    │   │   └── formatter.nix
    │   └── server/
    │       ├── default.nix       # Complex package with multiple files
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
- Organizational directory names don't affect the output name

Examples:
```
packages/hello-world.nix        → packages.<system>.hello-world
packages/utils/helper.nix       → packages.<system>.helper
packages/tools/cli/default.nix  → packages.<system>.cli
```

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
