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
├── devshells/            # Dev shells (mkShell with inputs and pkgs)
├── devenvs/              # Devenv shells (devenv configuration)
├── modules/
│   ├── nixos/            # Portable NixOS modules
│   ├── darwin/           # Portable nix-darwin modules
│   ├── home-manager/     # Portable home-manager modules
│   └── devenv/           # Portable devenv modules
├── configurations/
│   ├── nixos/            # Portable NixOS configurations
│   └── darwin/           # Portable nix-darwin configurations
└── with-inputs/          # Non-portable versions that receive flake inputs
    ├── packages/         # Packages that need inputs
    ├── devshells/        # Dev shells that need inputs
    ├── devenvs/          # Devenv shells (standard devenv config)
    ├── modules/
    │   ├── nixos/        # NixOS modules that need inputs
    │   ├── darwin/       # nix-darwin modules that need inputs
    │   ├── home-manager/ # home-manager modules that need inputs
    │   └── devenv/       # Devenv modules (standard devenv modules)
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

### DevShells

DevShells provide simple development environments using `pkgs.mkShell`. All devShells (both regular and with-inputs) receive `inputs` and `pkgs` arguments.

#### DevShell (Standard Pattern)

```nix
# nix/devshells/default.nix
inputs: pkgs:

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

DevEnvs use the devenv framework for richer development environments. DevEnvs in both regular and with-inputs directories use the same signature.

#### DevEnv (Standard Pattern)

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

#### DevEnv (With Inputs - Same Directory)

```nix
# nix/with-inputs/devenvs/my-env.nix
{ pkgs, ... }:

{
  packages = [ pkgs.git ];

  languages.rust.enable = true;
}
```

**Note:** DevEnvs in `with-inputs/devenvs/` use the same signature as regular devenvs (`{ pkgs, ... }: {...}`). The `with-inputs` directory simply provides organizational separation for devenvs that are specific to this flake's context, without actually passing `inputs` to the files.

**Important:** DevShell and DevEnv names must be unique across both types since devenv creates devShells internally. You cannot have a devShell named "default" and a devenv named "default" - nixDir will detect this conflict and throw an error.

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
| DevShell | `inputs: pkgs: mkShell {...}` | `inputs: pkgs: mkShell {...}` |
| DevEnv | `{ pkgs, ... }: {...}` | `{ pkgs, ... }: {...}` |

**Note:** DevShells always receive both `inputs` and `pkgs` (in both regular and with-inputs directories). DevEnvs use the standard devenv module signature in both locations.


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

**Q: What's the difference between devShells and devEnvs?**
A: DevShells use `pkgs.mkShell` for simple development environments. DevEnvs use the devenv
framework for richer features like language support, services, and pre-commit hooks. DevShells
are simpler and more portable, while devEnvs provide more functionality.

**Q: Can I have both a devShell and devEnv with the same name?**
A: No! Since devenv creates devShells internally, names must be unique across both devShells
and devenvs. nixDir will detect this conflict and throw an error.

**Q: Do devShells in regular vs with-inputs directories have different signatures?**
A: No, devShells always use the same signature `inputs: pkgs: mkShell {...}` in both locations.
The `with-inputs/` directory is just for organization when you want to use flake inputs in your
shell.

**Q: Why don't devenvs in with-inputs receive inputs?**
A: DevEnvs use the standard devenv module signature `{ pkgs, ... }: {...}` regardless of
location. The `with-inputs/devenvs/` directory is for organizational purposes to separate
project-specific devenvs from portable ones.
