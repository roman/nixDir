# With-Inputs Directory Pattern

## Overview

There are two ways to access flake inputs in your nixDir files:

1. **The `with-inputs/` directory pattern** - Separate directories for files that need inputs
2. **The `importWithInputs` option** - All files receive inputs by default

Both approaches provide access to flake inputs. Choose based on your portability requirements.

## Choosing the Right Approach

### Use `with-inputs/` directories when:
- You want **portable modules/packages** that can be used outside nixDir
- You need a mix of portable and non-portable files
- You're sharing modules with projects that don't use nixDir
- Portability is more important than convenience

### Use `importWithInputs = true` option when:
- You're committed to using nixDir for this project
- You want simpler navigation (all files in one place)
- You don't need files to be portable outside nixDir
- Convenience is more important than portability

**Tradeoff**: `importWithInputs = true` makes all your files non-portable (they require inputs as first parameter), but eliminates the cognitive load of maintaining parallel directory structures. If you're fully committed to nixDir, this is often a reasonable tradeoff.

## The `importWithInputs` Option

Enable in your flake configuration:

```nix
nixDir = {
  enable = true;
  root = ./.;
  importWithInputs = true;  # All files receive inputs as first parameter
};
```

With this option, all files in the regular directories receive `inputs`:

```nix
# nix/packages/my-package.nix (with importWithInputs = true)
inputs: { pkgs, ... }:
pkgs.writeShellScript "hello" ''
  echo "Using ${inputs.some-input}"
''
```

All files in `nix/packages/`, `nix/modules/`, etc. will have the same signature as if they
were in `with-inputs/` directories. This simplifies your directory structure at the cost of
making files non-portable.

If you enable `importWithInputs = true` and still have `with-inputs/` directories, nixDir
will warn you to consider consolidating (but both will continue to work).

## The `with-inputs/` Directory Pattern

The `with-inputs/` directory pattern allows you to write non-portable modules and packages
that need access to flake inputs. This is useful when you need to reference dependencies
from other flakes (or your own) in your modules or packages.

One could use `specialArgs` when building modules or `overlays` when building packages to
accomplish this goal, however, if your flake is imported from a parent flake (a caller flake
that is including the current flake as an input), as an author you don't have direct control
on which overlays or specialArgs are included on the caller flake. This approach ensures
dependencies that this flake know get resolved easily.

## Directory Structure

The `with-inputs/` directory mirrors the regular structure. See [Directory Structure
Guide](./directory-structure.md) for the complete layout.

**Pattern**: Any directory type can have a `with-inputs/` version:
- `nix/packages/` → portable packages
- `nix/with-inputs/packages/` → packages that need flake inputs
- Same for `modules/`, `devshells/`, `devenvs/`, `configurations/`

## Usage

### Modules

#### Portable Module (Standard Pattern)

```nix
# nix/modules/nixos/my-module.nix
{ pkgs, config, lib, ... }: {
  options = { ... };
  config = { ... };
}
```

#### Non-Portable Module (With Inputs)

```nix
# nix/with-inputs/modules/nixos/my-module.nix
inputs: { pkgs, config, lib, ... }: {
# ^^^^^
  options = { ... };
  config = {
    # Can access inputs here
    environment.systemPackages = [
      inputs.some-flake.packages.${pkgs.system}.foo
    ];
  };
}
```

### Packages

#### Portable Package (Standard Pattern)

```nix
# nix/packages/my-package.nix
{ stdenv }:

stdenv.mkDerivation {
  pname = "my-package";
  version = "1.0.0";
  src = ./.;
}
```

#### Non-Portable Package (With Inputs)

```nix
# nix/with-inputs/packages/my-package.nix
inputs: { system, stdenv, ... }:

stdenv.mkDerivation {
  pname = "my-package";
  version = "1.0.0";
  src = ./.;
  buildInputs = [
    inputs.some-flake.packages.${system}.tool
  ];
}
```

### Configurations

#### Portable Configuration (Standard Pattern)

```nix
# nix/configurations/nixos/my-host.nix
{
  system = "x86_64-linux";
  modules = [
    # Can only use modules from this flake or nixpkgs
    ./my-module.nix
  ];
}
```

```nix
# nix/configurations/darwin/my-mac.nix
{
  system = "aarch64-darwin";
  modules = [
    ./my-module.nix
  ];
}
```

#### Non-Portable Configuration (With Inputs)

```nix
# nix/with-inputs/configurations/nixos/my-host.nix
inputs: {
  system = "x86_64-linux";
  modules = [
    inputs.some-flake.nixosModules.default
    ./hardware-configuration.nix
  ];
}
```

```nix
# nix/with-inputs/configurations/darwin/my-mac.nix
inputs: {
  system = "aarch64-darwin";
  modules = [
    inputs.some-flake.darwinModules.default
  ];
}
```

### DevShells

DevShells provide simple development environments using `pkgs.mkShell`.

#### DevShell (Portable Pattern)

```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  buildInputs = [ pkgs.hello pkgs.cowsay ];
  shellHook = ''
    echo "Welcome to my dev shell!"
  '';
}
```

#### DevShell (With Inputs)

```nix
# nix/with-inputs/devshells/my-shell.nix
inputs: pkgs:

pkgs.mkShell {
  buildInputs = [
    pkgs.hello
    inputs.some-flake.packages.${pkgs.system}.custom-tool
  ];
  shellHook = ''
    echo "Dev shell with custom tool from flake input"
  '';
}
```

### DevEnvs

DevEnvs use the devenv framework for richer development environments.

#### DevEnv (Portable Pattern)

```nix
# nix/devenvs/default.nix
{ pkgs, ... }:

{
  packages = [ pkgs.git pkgs.nodejs ];

  languages.python = {
    enable = true;
    version = "3.11";
  };
}
```

#### DevEnv (With Inputs)

```nix
# nix/with-inputs/devenvs/my-env.nix
inputs: { pkgs, ... }:

{
  packages = [
    pkgs.git
    inputs.some-flake.packages.${pkgs.system}.custom-devtool
  ];

  languages.rust.enable = true;
}
```

> ![IMPORTANT] DevShell and DevEnv names must be unique across both types since devenv
> creates devShells internally. You cannot have a devShell named "default" and a devenv
> named "default" - nixDir will detect this conflict and throw an error.

## Conflict Detection

nixDir validates that the same name does not appear in both the regular directory and the
`with-inputs/` directory. This prevents confusion and ensures clarity about which version is
being used.

### Example of Invalid Structure (Will Throw Error)

```
nix/
├── modules/
│   └── nixos/
│       └── my-module.nix       ❌ Conflict!
└── with-inputs/
    └── modules/
        └── nixos/
            └── my-module.nix   ❌ Conflict!
```

**Error Message:**
```
nixDir found conflicting modules/nixos entries in both regular and with-inputs directories:
my-module

Each entry should exist in either the regular directory OR the with-inputs directory, not both.

Regular: nix/modules/nixos/
With-inputs: nix/with-inputs/modules/nixos/

Please move or rename the conflicting entries.
```

### Valid Structure
```
nix/
├── modules/
│   └── nixos/
│       └── portable-module.nix     ✅ No conflict
└── with-inputs/
    └── modules/
        └── nixos/
            └── non-portable-module.nix   ✅ No conflict
```

## Best Practices

1. **Prefer Portable**: Use the regular directories (`packages/`, `modules/`) whenever
   possible. Only use `with-inputs/` when you truly need access to flake inputs.

2. **Documentation**: Add comments in your with-inputs files explaining why inputs are
   needed.

3. **Testing**: Test both portable and with-inputs versions to ensure they work correctly in
   different contexts.

## Technical Details

### File Signatures

| Type | Regular (Portable) | With-Inputs (Non-Portable) |
|------|---------|-------------|
| NixOS Module | `{ pkgs, config, ... }: {...}` | `inputs: { pkgs, config, ... }: {...}` |
| Package | `{ dep1, dep2, ... }: derivation` | `inputs: { dep1, dep2, ... }: derivation` |
| Configuration | `{ system, modules, ... }` | `inputs: { system, modules, ... }` |
| DevShell | `pkgs: mkShell {...}` | `inputs: pkgs: mkShell {...}` |
| DevEnv | `{ pkgs, ... }: {...}` | `inputs: { pkgs, ... }: {...}` |


## FAQ

**Q: Can I use both regular and with-inputs directories?**
A: Yes! You can have portable modules in the regular directory and non-portable ones in
`with-inputs/`. Just ensure no name conflicts.

**Q: What if I need inputs in a package?**
A: Put the package in `with-inputs/packages/` with signature `inputs: { stdenv, ... }:
derivation`.

**Q: Do configurations work in regular directories?**
A: Yes! Configurations can be in either `configurations/nixos/` (portable) or
`with-inputs/configurations/nixos/` (with inputs access). The portable version is just an
attrset `{ system, modules, ... }` and the with-inputs version has signature
`inputs: { system, modules, ... }`.

**Q: What happens if I have conflicting names?**
A: nixDir will throw a helpful error message listing all conflicts and asking you to rename
or move the files.

**Q: How do I access inputs in a with-inputs file?**
A: Your file receives `inputs` as the first parameter. Use it like
`inputs.some-flake.packages.${pkgs.system}.foo`.

**Q: What's the difference between devShells and devEnvs?**
A: DevShells use `pkgs.mkShell` for simple development environments. DevEnvs use the devenv
framework for richer features like language support, services, and pre-commit hooks. DevShells
are simpler and more portable, while devenvs provide more functionality.

**Q: Can I have both a devShell and a devenv with the same name?**
A: No! Since devenv creates devShells internally, names must be unique across both devShells
and devenvs. nixDir will detect this conflict and throw an error.

**Q: Do devShells in regular vs with-inputs directories have different signatures?**
A: Yes! Regular devShells use `pkgs: mkShell {...}` (portable), while with-inputs devShells use
`inputs: pkgs: mkShell {...}` (non-portable). This follows the same pattern as other file types.

**Q: Do devenvs in with-inputs receive inputs?**
A: Yes! Regular devenvs use `{ pkgs, ... }: {...}` while with-inputs devenvs use
`inputs: { pkgs, ... }: {...}`. This allows you to access flake inputs in your devenv
configuration.
