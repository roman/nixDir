# nixDir v3 File Signatures

File signatures organized by import strategy. Each shows with and without inputs.

## Strategy: callPackage (packages)

Used for `nix/packages/`. Files receive dependencies via callPackage.

**Without inputs:**
```nix
# nix/packages/my-package.nix
{ stdenv, lib, fetchFromGitHub, makeWrapper, ... }:

stdenv.mkDerivation {
  pname = "my-package";
  version = "1.0.0";
  src = fetchFromGitHub { ... };

  nativeBuildInputs = [ makeWrapper ];

  meta = with lib; {
    description = "My package";
    platforms = platforms.unix;
  };
}
```

**With inputs** (via `with-inputs/` or `importWithInputs=true`):
```nix
# nix/with-inputs/packages/my-package.nix
inputs:                              # First arg: flake inputs
{ stdenv, lib, ... }:                # Second arg: callPackage deps

let
  inherit (inputs) some-flake;
  dep = some-flake.packages.${stdenv.system}.tool;
in
stdenv.mkDerivation {
  pname = "my-package";
  buildInputs = [ dep ];
}
```

## Strategy: passPkgs (devshells)

Used for `nix/devshells/`. Files receive entire pkgs set.

**Without inputs:**
```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  packages = with pkgs; [
    nodejs
    npm
    typescript
  ];

  shellHook = ''
    echo "Development shell ready"
  '';
}
```

**With inputs:**
```nix
# nix/with-inputs/devshells/default.nix
inputs:                              # First arg: flake inputs
pkgs:                                # Second arg: pkgs set

pkgs.mkShell {
  packages = [
    pkgs.git
    inputs.some-tool.packages.${pkgs.system}.default
  ];
}
```

## Strategy: plain (modules)

Used for all module types. Standard NixOS module signature.

### NixOS Modules

**Without inputs:**
```nix
# nix/modules/nixos/my-service.nix
{ pkgs, lib, config, ... }:

let
  cfg = config.services.my-service;
in
{
  options.services.my-service = {
    enable = lib.mkEnableOption "my-service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
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

**With inputs:**
```nix
inputs: { pkgs, lib, config, ... }:
{ options = { }; config = { }; }
```

### Darwin Modules

Same signature as NixOS modules:

```nix
# nix/modules/darwin/my-config.nix
{ pkgs, lib, config, ... }:

{
  options = { };
  config = { };
}
```

### Home-Manager Modules

```nix
# nix/modules/home-manager/my-program.nix
{ pkgs, lib, config, ... }:

let
  cfg = config.programs.my-program;
in
{
  options.programs.my-program = {
    enable = lib.mkEnableOption "my-program";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.my-program;
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

    xdg.configFile."my-program/config.json".text =
      builtins.toJSON cfg.settings;
  };
}
```

### devenv Modules

```nix
# nix/modules/devenv/my-feature.nix
{ pkgs, lib, config, ... }:

let
  cfg = config.my-feature;
in
{
  options.my-feature = {
    enable = lib.mkEnableOption "my-feature";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ pkgs.some-tool ] ++ cfg.extraPackages;

    git-hooks.hooks = {
      some-hook.enable = true;
    };
  };
}
```

## Strategy: plain (devenvs)

Used for `nix/devenvs/`. devenv shell configuration.

**Without inputs:**
```nix
# nix/devenvs/default.nix
{ pkgs, lib, config, ... }:

{
  packages = with pkgs; [ just httpie ];

  languages.python = {
    enable = true;
    version = "3.11";
  };

  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "dev"; }];
  };

  git-hooks.hooks = {
    black.enable = true;
    ruff.enable = true;
  };

  env = {
    DATABASE_URL = "postgres://localhost/dev";
  };

  enterShell = ''
    echo "Dev environment ready"
  '';
}
```

**With inputs:**
```nix
inputs: { pkgs, lib, config, ... }:
{
  packages = [ inputs.some-flake.packages.${pkgs.system}.tool ];
}
```

## Strategy: plain (configurations)

Used for system configurations. Returns attrset with system and modules.

### NixOS Configuration

```nix
# nix/configurations/nixos/my-machine.nix
{ system = "x86_64-linux";
  modules = [
    ./hardware-configuration.nix
    ({ pkgs, ... }: {
      networking.hostName = "my-machine";
    })
  ];
}
```

**With inputs** (common pattern):
```nix
# nix/with-inputs/configurations/nixos/my-machine.nix
inputs:

{
  system = "x86_64-linux";
  modules = [
    inputs.self.nixosModules.my-module
    inputs.home-manager.nixosModules.home-manager
    ({ pkgs, ... }: {
      networking.hostName = "my-machine";
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
    })
  ];
}
```

## Summary Table

| Directory | Strategy | Base Signature |
|-----------|----------|----------------|
| packages/ | callPackage | `{ dep, ... }: derivation` |
| devshells/ | passPkgs | `pkgs: mkShell { }` |
| devenvs/ | plain | `{ pkgs, config, ... }: { }` |
| modules/nixos/ | plain | `{ config, lib, pkgs, ... }: { }` |
| modules/darwin/ | plain | `{ config, lib, pkgs, ... }: { }` |
| modules/home-manager/ | plain | `{ config, lib, pkgs, ... }: { }` |
| modules/devenv/ | plain | `{ config, lib, pkgs, ... }: { }` |
| configurations/nixos/ | plain | `{ system, modules }` |
| configurations/darwin/ | plain | `{ system, modules }` |

**With inputs**: Prepend `inputs:` as first parameter to any signature above.
