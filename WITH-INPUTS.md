# With-Inputs Directory Pattern

## Overview

The `with-inputs/` directory pattern allows you to write non-portable modules and packages
that need access to flake inputs. This is useful when you need to reference dependencies
from other flakes (or your own) in your modules or packages. 

One could use `specialArgs` when building modules or `overlays` when building packages to
accomplish this goal, however, if your flake is imported from a parent flake (a caller flake
that is including the current flake as an input), as an author you don't have direct control
on which overlays are included or specialArgs. This approach ensures dependencies that this
flake know get resolved easily.

## Directory Structure

```
nix/
├── packages/              # Portable packages (standard callPackage signature)
├── modules/
│   ├── nixos/            # Portable NixOS modules
│   ├── darwin/           # Portable nix-darwin modules
│   └── home-manager/     # Portable home-manager modules
├── configurations/
│   ├── nixos/            # Portable NixOS configurations
│   └── darwin/           # Portable nix-darwin configurations
└── with-inputs/          # Non-portable versions that receive flake inputs
    ├── packages/         # Packages that need inputs
    ├── modules/
    │   ├── nixos/        # NixOS modules that need inputs
    │   ├── darwin/       # nix-darwin modules that need inputs
    │   └── home-manager/ # home-manager modules that need inputs
    └── configurations/
        ├── nixos/        # NixOS configurations that need inputs
        └── darwin/       # nix-darwin configurations that need inputs
```

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
{ pkgs, stdenv, ... }:

stdenv.mkDerivation {
  pname = "my-package";
  version = "1.0.0";
  src = ./.;
}
```

#### Non-Portable Package (With Inputs)

```nix
# nix/with-inputs/packages/my-package.nix
inputs: { pkgs, stdenv, ... }:

stdenv.mkDerivation {
  pname = "my-package";
  version = "1.0.0";
  src = ./.;
  buildInputs = [
    inputs.some-flake.packages.${pkgs.system}.tool
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

| Type | Regular | With-Inputs |
|------|---------|-------------|
| NixOS Module | `{ pkgs, config, ... }: {...}` | `inputs: { pkgs, config, ... }: {...}` |
| Package | `{ dep1, dep2, ... }: derivation` | `inputs: { dep1, dep2, ... }: derivation` |
| Configuration | `{ system, modules, ... }` | `inputs: { system, modules, ... }` |


## FAQ

**Q: Can I use both regular and with-inputs directories?**
A: Yes! You can have portable modules in the regular directory and non-portable ones in
`with-inputs/`. Just ensure no name conflicts.

**Q: What if I need inputs in a package?**
A: Put the package in `with-inputs/packages/` with signature `inputs: { pkgs, ... }:
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
