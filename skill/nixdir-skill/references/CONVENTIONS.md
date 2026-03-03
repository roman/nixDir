# nixDir v3 Conventions

## Directory to Output Mapping

| Directory Path                 | Flake Output Attribute          | Strategy    | Per-System |
|--------------------------------|---------------------------------|-------------|------------|
| `nix/packages/`                | `packages.<system>.<name>`      | callPackage | Yes        |
| `nix/devshells/`               | `devShells.<system>.<name>`     | passPkgs    | Yes        |
| `nix/devenvs/`                 | `devShells.<system>.<name>`     | plain       | Yes        |
| `nix/modules/nixos/`           | `nixosModules.<name>`           | plain       | No         |
| `nix/modules/darwin/`          | `darwinModules.<name>`          | plain       | No         |
| `nix/modules/home-manager/`    | `homeManagerModules.<name>`     | plain       | No         |
| `nix/modules/devenv/`          | `devenvModules.<name>`          | plain       | No         |
| `nix/configurations/nixos/`    | `nixosConfigurations.<name>`    | plain       | No         |
| `nix/configurations/darwin/`   | `darwinConfigurations.<name>`   | plain       | No         |

**Per-System** outputs are computed for each system in the `systems` list.
**Flake-level** outputs are computed once, independent of system.

## Import Strategies

| Strategy    | How it works                        | Use case          |
|-------------|-------------------------------------|-------------------|
| callPackage | `pkgs.callPackage file {}`          | packages          |
| passPkgs    | `import file pkgs`                  | devshells         |
| plain       | `import file`                       | modules, configs  |

## Naming Rules

### File Names

- Use kebab-case: `my-package.nix`, `my-module.nix`
- Extension must be `.nix`
- Attribute name = filename without extension

### Directory Names

- Use kebab-case for consistency
- `default.nix` in directory uses directory name as attribute
- Organizational subdirectories are supported (flattened in output)

### Conflicts

Cannot have both in same directory:
- `foo.nix` AND `foo/default.nix`

Cannot have same name in both trees:
- `packages/hello.nix` AND `with-inputs/packages/hello.nix`

Cannot have same name across shell types:
- `devshells/default.nix` AND `devenvs/default.nix`

## Git Tracking Requirement

Files must be git-tracked to be discovered:

```bash
# Add new file to git
git add nix/packages/my-new-package.nix

# Then it becomes available
nix build .#my-new-package
```

## Nested Directory Discovery

`.nix` files are discovered recursively up to `maxDepth=3`:

```
nix/packages/
├── simple.nix                    → "simple"
├── tools/
│   ├── cli-tool.nix              → "cli-tool"
│   └── gui-tool/
│       └── default.nix           → "gui-tool"
└── libs/
    └── helpers/
        └── utils.nix             → "utils" (depth 3)
```

**Important**: Directory names are organizational only. Attribute names come
from the file/directory containing default.nix.

### Discovery Rules

- **Max depth**: 3 levels by default
- **File blocking**: `foo.nix` blocks traversal into `foo/` directory
- **Hidden directories**: Skipped (starting with `.`)
- **Symlinks**: Skipped unless `followSymlinks = true`
- **Leaf directories**: Directories with `default.nix` stop recursion

### Strict Discovery Mode

Enable `strictDiscovery = true` to error when directories are ignored:

```nix
nixDir = {
  enable = true;
  root = ./.;
  strictDiscovery = true;  # Error if dirs with default.nix ignored
};
```

Reports which directories were ignored and why (depth-exceeded, blocked).

## with-inputs/ Subdirectory

Files needing flake inputs can be placed in `nix/with-inputs/`:

```
nix/
├── packages/
│   └── simple.nix                    # No inputs needed
└── with-inputs/
    └── packages/
        └── needs-inputs.nix          # Gets inputs as first arg
```

The structure under `with-inputs/` mirrors the regular structure.

**Alternative**: Use `importWithInputs = true` in nixDir config to make
ALL files receive inputs as first parameter.

## Module Organization Pattern

Recommended structure for complex modules:

```
nix/modules/home-manager/
├── feature-a.nix                 # Simple feature
├── feature-b.nix
└── feature-c/
    ├── default.nix               # Complex feature entry point
    └── helpers.nix               # Internal helpers (not exported)
```

Only `default.nix` files and `.nix` files in the immediate directory
become flake outputs. Files inside directories with `default.nix` are
internal to that module.

## Configuration Options Reference

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `enable` | bool | - | Enable nixDir |
| `root` | path | - | Flake root (required) |
| `dirName` | str | `"nix"` | Config directory |
| `importWithInputs` | bool | `false` | All files get inputs |
| `filterUnsupportedSystems` | bool | `true` | Filter by meta.platforms |
| `strictDiscovery` | bool | `false` | Error on ignored dirs |
| `followSymlinks` | bool | `false` | Follow symlinks |
| `generateAllPackage` | bool | `false` | Create "all" package |
| `generateFlakeOverlay` | bool | `false` | Generate overlay |
| `installFlakeOverlay` | bool | `false` | Install overlay in pkgs |
| `installOverlays` | list | `[]` | Extra overlays |
| `nixpkgsConfig` | attrs | `{}` | Nixpkgs config |
| `installAllDevenvModules` | bool | `false` | Auto-install devenv modules |
