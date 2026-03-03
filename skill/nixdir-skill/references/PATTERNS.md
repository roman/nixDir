# Common nixDir v3 Patterns

## Package Patterns

### Simple Script Package

```nix
# nix/packages/my-script.nix
{ writeShellScriptBin, jq, ... }:

writeShellScriptBin "my-script" ''
  echo "Hello from my-script"
  ${jq}/bin/jq --version
''
```

### Standard Derivation

```nix
# nix/packages/my-tool.nix
{ stdenv, lib, cmake, openssl, ... }:

stdenv.mkDerivation {
  pname = "my-tool";
  version = "1.0.0";

  src = ../../src/my-tool;

  nativeBuildInputs = [ cmake ];
  buildInputs = [ openssl ];

  meta = with lib; {
    description = "My tool";
    platforms = platforms.unix;
  };
}
```

### Package from Another Flake

```nix
# nix/with-inputs/packages/external-tool.nix
inputs:
{ system, ... }:

inputs.some-flake.packages.${system}.tool
```

### Package Wrapping Another

```nix
# nix/packages/wrapped-tool.nix
{ writeShellScriptBin, lib, git, curl, some-tool, ... }:

writeShellScriptBin "wrapped-tool" ''
  export PATH="${lib.makeBinPath [ git curl ]}:$PATH"
  exec ${some-tool}/bin/some-tool "$@"
''
```

### Platform-Specific Package

```nix
# nix/packages/linux-only.nix
{ stdenv, lib, ... }:

stdenv.mkDerivation {
  pname = "linux-tool";
  version = "1.0.0";
  src = ./src;

  meta = {
    platforms = lib.platforms.linux;  # Filtered out on non-Linux
  };
}
```

## devshells Patterns

### Basic Development Shell

```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  packages = with pkgs; [
    git
    just
    nodejs
  ];

  shellHook = ''
    echo "Development shell ready"
  '';
}
```

### Shell with Environment Variables

```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  packages = with pkgs; [ nodejs postgresql ];

  DATABASE_URL = "postgres://localhost/dev";
  NODE_ENV = "development";

  shellHook = ''
    export PATH="$PWD/node_modules/.bin:$PATH"
  '';
}
```

### Multiple Named Shells

```nix
# nix/devshells/default.nix - main shell
pkgs:
pkgs.mkShell { packages = with pkgs; [ nodejs ]; }

# nix/devshells/ci.nix - CI-specific shell
pkgs:
pkgs.mkShell { packages = with pkgs; [ nodejs chromium ]; }
```

## devenvs Patterns

### Basic devenv Shell

```nix
# nix/devenvs/default.nix
{ pkgs, ... }:

{
  packages = with pkgs; [ git just ];

  enterShell = ''
    echo "Development shell ready"
  '';
}
```

### Full-Featured devenv

```nix
# nix/devenvs/default.nix
{ pkgs, config, ... }:

{
  packages = with pkgs; [ just httpie ];

  languages.python = {
    enable = true;
    version = "3.11";
    venv = {
      enable = true;
      requirements = ./requirements.txt;
    };
  };

  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "dev"; }];
  };

  services.redis.enable = true;

  git-hooks.hooks = {
    ruff.enable = true;
    black.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  env = {
    DATABASE_URL = "postgres://localhost/dev";
    REDIS_URL = "redis://localhost:6379";
  };

  processes = {
    api.exec = "python -m uvicorn app:app --reload";
    worker.exec = "python -m celery -A tasks worker";
  };
}
```

## Module Patterns

### Basic Enable Pattern

```nix
# nix/modules/home-manager/my-feature.nix
{ pkgs, lib, config, ... }:

let
  cfg = config.programs.my-feature;
in
{
  options.programs.my-feature = {
    enable = lib.mkEnableOption "my-feature";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.my-package ];
  };
}
```

### Module with Options

```nix
# nix/modules/home-manager/my-config.nix
{ pkgs, lib, config, ... }:

let
  cfg = config.programs.my-config;
in
{
  options.programs.my-config = {
    enable = lib.mkEnableOption "my-config";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.my-default;
      description = "Package to use";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Configuration settings";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."my-config/settings.json".text =
      builtins.toJSON cfg.settings;
  };
}
```

### Module Using Flake Package

```nix
# nix/with-inputs/modules/home-manager/my-tool.nix
inputs:
{ pkgs, lib, config, ... }:

let
  cfg = config.programs.my-tool;
  defaultPkg = inputs.self.packages.${pkgs.system}.my-tool;
in
{
  options.programs.my-tool = {
    enable = lib.mkEnableOption "my-tool";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPkg;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
```

### devenv Module Pattern

```nix
# nix/modules/devenv/testing.nix
{ pkgs, lib, config, ... }:

let
  cfg = config.testing;
in
{
  options.testing = {
    enable = lib.mkEnableOption "testing utilities";

    coverage = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    packages = with pkgs; [ just ]
      ++ lib.optionals cfg.coverage [ lcov ];

    git-hooks.hooks.check-tests = {
      enable = true;
      entry = "just test";
      pass_filenames = false;
    };
  };
}
```

## Configuration Patterns

### NixOS Configuration

```nix
# nix/with-inputs/configurations/nixos/my-machine.nix
inputs:

{
  system = "x86_64-linux";
  modules = [
    ./hardware-configuration.nix
    inputs.self.nixosModules.my-module
    inputs.home-manager.nixosModules.home-manager
    ({ pkgs, ... }: {
      networking.hostName = "my-machine";
      system.stateVersion = "24.05";
    })
  ];
}
```

### Darwin Configuration

```nix
# nix/with-inputs/configurations/darwin/my-mac.nix
inputs:

{
  system = "aarch64-darwin";
  modules = [
    inputs.self.darwinModules.my-module
    ({ pkgs, ... }: {
      networking.hostName = "my-mac";
      services.nix-daemon.enable = true;
    })
  ];
}
```

## Nested Directory Patterns

### Organizational Subdirectories

```
nix/packages/
├── cli/
│   ├── tool-a.nix         → packages.tool-a
│   └── tool-b.nix         → packages.tool-b
├── gui/
│   └── app.nix            → packages.app
└── libs/
    └── utils/
        └── default.nix    → packages.utils
```

### Complex Package with Support Files

```
nix/packages/my-complex-pkg/
├── default.nix            → packages.my-complex-pkg
├── patches/
│   └── fix-build.patch    # Internal, not exported
└── scripts/
    └── wrapper.sh         # Internal, not exported
```

## flake.nix Configuration Patterns

### Minimal Setup

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
      };
    };
}
```

### With devenv

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixDir.url = "github:rskew/nixDir/v3";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nixDir.flakeModule
        inputs.devenv.flakeModule
      ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      nixDir = {
        enable = true;
        root = ./.;
        importWithInputs = true;  # All files get inputs
      };
    };
}
```

### With All Options

```nix
nixDir = {
  enable = true;
  root = ./.;
  dirName = "nix";
  importWithInputs = true;
  filterUnsupportedSystems = true;
  strictDiscovery = true;
  followSymlinks = false;
  generateAllPackage = true;
  generateFlakeOverlay = true;
  installFlakeOverlay = true;
  installOverlays = [ ];
  nixpkgsConfig = { allowUnfree = true; };
  installAllDevenvModules = true;
};
```
