# nixDir

This repository has multiple versions available on different branches.

## Available Versions

- **[v3](https://github.com/roman/nixDir/tree/v3)** - Latest version (recommended)
- **[v2](https://github.com/roman/nixDir/tree/v2)** - Previous stable version
- **[v1](https://github.com/roman/nixDir/tree/v1)** - Legacy version

## Migration Notice

⚠️ **If your setup stopped working after a recent update**, you need to pin your flake input to the v1 branch.

Update your `flake.nix` to use v1 explicitly:

```nix
{
  inputs = {
    nixDir.url = "github:roman/nixDir/v1";
  };
}
```

## Documentation

Please visit the branch corresponding to your version for full documentation:

- [v3 Documentation](https://github.com/roman/nixDir/tree/v3#readme)
- [v2 Documentation](https://github.com/roman/nixDir/tree/v2#readme)
- [v1 Documentation](https://github.com/roman/nixDir/tree/v1#readme)
