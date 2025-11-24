# nixDir

_Convention-based directory structure for Nix flakes._

nixDir is a flake-parts module that automatically discovers and wires up flake outputs based
on directory conventions. Stop writing boilerplate in `flake.nix` and start organizing your
Nix code in intuitive directories.

## Why Directory Conventions?

Managing flake outputs manually becomes tedious as projects grow. nixDir lets you organize
packages, modules, and configurations in well-named directories, and automatically generates
the corresponding flake outputs.

It's like Rails' "convention over configuration" for Nix flakes - structure your code
predictably, and it "just works".

## Features

- **Zero-boilerplate outputs**: Place files in `nix/packages/`, `nix/modules/`, etc. and
  they automatically become flake outputs
- **Portable and non-portable patterns**: Use `with-inputs/` for modules that need flake
  inputs, regular directories for portable resources
- **Cross-platform support**: NixOS, nix-darwin, home-manager and devenv modules
- **Development environments**: Automatic discovery of devShells and devenv configurations
- **Type safety**: Built on flake-parts' module system

## Getting Started

```nix
# flake.nix
{
  outputs = inputs:
    inputs.flake-parts.mkFlake { inherit inputs; } {
      systems = [ "..." ];
      imports = [ inputs.nixDir.flakeModule ];
      nixDir = { 
        enable = true; 
      	root = ./.; 
      };
    };
}
```

Create `nix/packages/hello.nix`, run `nix build .#hello` - done!

See [Getting Started Guide](./docs/getting-started.md) for complete setup.

## Documentation

See the [docs/](./docs) directory for comprehensive guides:

- **[Getting Started](./docs/getting-started.md)** - Installation and first steps
- **[Directory Structure](./docs/directory-structure.md)** - How to organize your code
- **[With-Inputs Pattern](./docs/with-inputs.md)** - Using flake inputs in outputs
- **[Testing](./docs/testing.md)** - Running the test suite

## Examples

See the [example/](./example) directory for a complete working project demonstrating nixDir
features.

## Configuration Options

Key options:
- `enable` / `root` - Required
- `dirName` - Config directory name (default: `"nix"`)
- `installFlakeOverlay` - Make packages available in `pkgs` across all your outputs

See [example flake.nix](./example/myproj/flake.nix) for all options.

## Directory Structure Overview

| Directory | Output |
|-----------|--------|
| `nix/packages/` | `packages.<system>.<name>` |
| `nix/devshells/` | `devShells.<system>.<name>` |
| `nix/devenvs/` | `devenv.shells.<name>` |
| `nix/modules/nixos/` | `nixosModules.<name>` |
| `nix/modules/darwin/` | `darwinModules.<name>` |
| `nix/configurations/nixos/` | `nixosConfigurations.<name>` |
| `nix/with-inputs/*/` | Non-portable versions |

See [Directory Structure](./docs/directory-structure.md) for complete details.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

MIT
