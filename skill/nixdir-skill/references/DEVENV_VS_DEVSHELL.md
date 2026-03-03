# devenv vs devShell Comparison (nixDir v3)

## Overview

| Aspect              | devshells/ (mkShell)        | devenvs/                        |
|---------------------|-----------------------------|---------------------------------|
| **Directory**       | `nix/devshells/`            | `nix/devenvs/`                  |
| **Signature**       | `pkgs: mkShell { }`         | `{ pkgs, ... }: { options }`    |
| **Purity**          | Pure by default             | Requires `--impure`             |
| **Shell entry**     | Fast                        | Slower (more setup)             |
| **Pre-commit hooks**| Manual setup                | Built-in `git-hooks.hooks`      |
| **Services**        | Not supported               | Built-in process management     |
| **Languages**       | Packages only               | `languages.*.enable` options    |

## When to Choose devshells/

Use `nix/devshells/` when you need:

1. **Simple package lists**
   ```nix
   # nix/devshells/default.nix
   pkgs:
   pkgs.mkShell {
     packages = with pkgs; [ go gopls ];
   }
   ```

2. **Pure, reproducible builds**
   - No `--impure` flag needed
   - Suitable for CI/CD environments
   - Hermetic evaluation

3. **Fast shell entry**
   - Minimal setup overhead
   - Quick to enter and exit

4. **Compatibility**
   - Works with all Nix tooling
   - No additional flake inputs needed

## When to Choose devenvs/

Use `nix/devenvs/` when you need:

1. **Pre-commit hooks**
   ```nix
   # nix/devenvs/default.nix
   { pkgs, ... }:
   {
     git-hooks.hooks = {
       nixfmt-rfc-style.enable = true;
       prettier.enable = true;
       eslint.enable = true;
     };
   }
   ```

2. **Background services**
   ```nix
   {
     services.postgres = {
       enable = true;
       initialDatabases = [{ name = "myapp"; }];
     };

     services.redis.enable = true;
   }
   ```

3. **Language toolchains**
   ```nix
   {
     languages.python = {
       enable = true;
       version = "3.11";
       venv.enable = true;
     };

     languages.javascript = {
       enable = true;
       npm.enable = true;
     };
   }
   ```

4. **Process management**
   ```nix
   {
     processes = {
       api.exec = "python api/server.py";
       worker.exec = "python worker/main.py";
     };
   }
   ```

5. **Environment setup**
   ```nix
   {
     env.DATABASE_URL = "postgres://localhost/myapp";

     enterShell = ''
       echo "Dev environment ready"
       source .env.local 2>/dev/null || true
     '';
   }
   ```

## --impure Requirement

devenv requires `--impure` because it:

- Reads environment variables at evaluation time
- Accesses paths outside Nix store for services data
- Uses IFD (Import From Derivation) for some features
- Integrates with local state (git hooks, service data)

```bash
# devenv requires --impure
nix develop --impure

# or with direnv (.envrc)
use flake . --impure
```

## Build Time Considerations

| Shell Type | Initial Build | Subsequent Entry |
|------------|---------------|------------------|
| devshells/ | Fast          | Very fast        |
| devenvs/   | Slower        | Moderate         |

Tips for devenv:
- Use binary cache when available
- Consider `cachix` for team sharing
- First build downloads many dependencies

## Conflict Detection

nixDir prevents naming conflicts between devshells and devenvs:

```
# ERROR: Cannot have both
nix/devshells/default.nix
nix/devenvs/default.nix
```

If you need both, use different names:
```
nix/devshells/simple.nix     → devShells.<system>.simple
nix/devenvs/full.nix         → devShells.<system>.full
```

## Side-by-Side Comparison

### devshells/ Version

```nix
# nix/devshells/default.nix
pkgs:

pkgs.mkShell {
  packages = with pkgs; [
    nodejs
    npm
    postgresql
  ];

  shellHook = ''
    # Manual postgres setup required
    export PGDATA=$PWD/.postgres
    if [ ! -d "$PGDATA" ]; then
      initdb
    fi
    pg_ctl start -l $PGDATA/log
    trap "pg_ctl stop" EXIT
  '';
}
```

### devenvs/ Version

```nix
# nix/devenvs/default.nix
{ pkgs, ... }:

{
  packages = with pkgs; [ nodejs ];

  languages.javascript = {
    enable = true;
    npm.enable = true;
  };

  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
  };

  git-hooks.hooks = {
    prettier.enable = true;
    eslint.enable = true;
  };
}
```

## Migration Path

### devshells/ to devenvs/

Before (devshells/):
```nix
pkgs:
pkgs.mkShell {
  packages = with pkgs; [ nodejs npm prettier ];
  shellHook = ''
    npm install
  '';
}
```

After (devenvs/):
```nix
{ pkgs, ... }:
{
  packages = with pkgs; [ nodejs npm ];

  languages.javascript.enable = true;

  git-hooks.hooks.prettier.enable = true;

  enterShell = ''
    npm install
  '';
}
```

**Key changes:**
1. Signature: `pkgs:` → `{ pkgs, ... }:`
2. Return: `pkgs.mkShell { }` → `{ options... }`
3. `shellHook` → `enterShell`
4. Manual tools → declarative options

## Decision Summary

| Need This?                    | Use This     |
|-------------------------------|--------------|
| Just packages                 | devshells/   |
| Pre-commit hooks              | devenvs/     |
| Database/services             | devenvs/     |
| Language toolchains           | devenvs/     |
| Pure builds / CI              | devshells/   |
| Fast shell entry              | devshells/   |
| Process management            | devenvs/     |
| Team onboarding ease          | devenvs/     |
| No `--impure` flag            | devshells/   |
