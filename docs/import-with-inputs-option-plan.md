# Plan: Add `importWithInputs` Option to nixDir

## Overview

Add a new `importWithInputs` option to the flake-part module that makes the regular directory tree behave like files in the with-inputs sub-directory. This addresses the cognitive load issue where users forget files exist in with-inputs directories and only look in the regular tree.

## Goals

1. Add `importWithInputs` boolean option (defaults to `false`)
2. When enabled, pass `inputs` as first parameter to all regular tree files
3. Warn users if both with-inputs and regular trees exist when option is enabled
4. Update documentation with warnings about with-inputs cognitive load
5. Maintain backward compatibility

## IMPORTANT: Implementation Approach Change

**Decision made during initial implementation attempt:**

We will use **Option 3: Importer Flag** approach instead of conditionals at each call-site.

### Why Option 3?
- **Cleanest solution**: Single parameter controls all importer behavior
- **No repetition**: Eliminates `if cfg.importWithInputs` at every call-site
- **Centralized logic**: All selection logic lives in importer.nix where it belongs
- **Maintainable**: Easy to understand and modify

### Trade-offs accepted:
- Requires refactoring `src/importer.nix` (acceptable - not a public API)
- Requires updating existing tests (acceptable - tests use importer directly)
- More upfront work, but cleaner long-term code

### Implementation approach:
1. Modify `src/importer.nix` to accept `useInputsEverywhere` parameter
2. Importer internally selects `importXxx` or `importXxxWithInputs` based on flag
3. `default.nix` passes `cfg.importWithInputs` to importer
4. Call sites remain simple and clean

## Implementation Tasks

### 1. Add new `importWithInputs` option to module

**File**: `default.nix`

- Location: Add option definition after existing options (around line 104)
- Type: `lib.types.bool`
- Default: `false`
- Description: "When true, all files in the regular tree receive 'inputs' as first parameter (behaves like with-inputs)"

**Code pattern**:
```nix
importWithInputs = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = ''
    When enabled, all files in the regular directory tree receive 'inputs'
    as their first parameter, similar to the with-inputs pattern.

    This eliminates the need for a separate with-inputs directory while
    maintaining access to flake inputs.
  '';
};
```

### 2. Add validation for with-inputs/regular conflicts

**File**: `default.nix`

- Location: Add check in config section (around line 106-110)
- Trigger: When `importWithInputs = true`
- For each directory type, detect if both regular and with-inputs directories exist:
  - `nix/packages/` AND `nix/with-inputs/packages/`
  - `nix/modules/nixos/` AND `nix/with-inputs/modules/nixos/`
  - etc.
- Action: Emit warning suggesting unification in default tree
- Implementation: Use `lib.warn` or `builtins.trace`

**Logic pattern**:
```nix
config = lib.mkIf cfg.enable {
  # Add warnings if importWithInputs is enabled and both trees exist
  warnings = lib.optional
    (cfg.importWithInputs && regularDirExists && withInputsDirExists)
    "Both regular and with-inputs directories detected. Consider unifying in the default tree.";

  # ... rest of config
};
```

### 3. Refactor importer.nix to accept useInputsEverywhere flag

**File**: `src/importer.nix`

Changes needed:
1. Add `useInputsEverywhere ? false` parameter to function signature
2. For each import function, return the appropriate version based on flag
3. Keep internal `importXxx` and `importXxxWithInputs` implementations

**Example pattern**:
```nix
# src/importer.nix signature changes from:
{ pkgs, lib, inputs }:

# to:
{ pkgs, lib, inputs, useInputsEverywhere ? false }:

# Then each exported function:
{
  importPackages =
    if useInputsEverywhere
    then importPackagesWithInputs
    else importPackagesImpl;

  importNixOSModules =
    if useInputsEverywhere
    then importNixOSModulesWithInputs
    else importNixOSModulesImpl;

  # ... etc for all importer functions
}
```

### 4. Update default.nix to pass flag to importer

**File**: `default.nix`

- Pass `useInputsEverywhere = cfg.importWithInputs` when importing importer.nix
- Remove all conditional logic at call-sites (now handled by importer)

**Example**:
```nix
# Flake-level importer
importer = import ./src/importer.nix {
  pkgs = null;
  inherit lib inputs;
  useInputsEverywhere = cfg.importWithInputs;
};

# Per-system importer
importer = import ./src/importer.nix {
  inherit pkgs lib inputs;
  useInputsEverywhere = cfg.importWithInputs;
};

# Call sites stay simple:
regularModules =
  if builtins.pathExists nixosModulesPath
  then importer.importNixOSModules nixosModulesPath
  else { };
```

### 5. Update documentation - with-inputs.md

**File**: `docs/with-inputs.md`

Changes needed:
1. Add prominent warning section at the top about cognitive load
2. Explain the problem:
   - Users forget files are in with-inputs
   - Only check regular directories during development
   - Split mental model increases maintenance burden
3. Recommend using `importWithInputs = true` instead for new projects
4. Mark with-inputs pattern as "legacy" or "advanced use case only"
5. Add migration guide from with-inputs to importWithInputs option

**Warning example**:
```markdown
## ⚠️ Cognitive Load Warning

The with-inputs directory pattern imposes significant cognitive overhead:
- Developers often forget files exist in `nix/with-inputs/`
- Most people only look in `nix/packages/`, `nix/modules/`, etc.
- Splitting related files across two trees increases mental burden
- Makes codebase navigation more difficult

**Recommendation**: For new projects, use the `importWithInputs` option instead.
This keeps all files in standard locations while providing access to inputs.
```

### 6. Update documentation - directory-structure.md

**File**: `docs/directory-structure.md`

Changes needed:
1. Add section explaining the `importWithInputs` option
2. Show examples of both approaches side-by-side
3. Recommend importWithInputs as preferred method
4. Update "Best Practices" section

**Example addition**:
```markdown
## Access to Flake Inputs

There are two ways to access flake inputs in your files:

### Option 1: importWithInputs (Recommended)

Enable in your flake:
```nix
nixDir = {
  enable = true;
  root = ./.;
  importWithInputs = true;
};
```

All files receive inputs as first parameter:
```nix
# nix/packages/my-package.nix
inputs: { pkgs, ... }:
pkgs.writeShellScript "hello" ''
  echo "Using ${inputs.some-input}"
''
```

### Option 2: with-inputs directory (Legacy)

Place files in parallel with-inputs tree...
```

### 7. Update documentation - README.md

**File**: `README.md`

Changes needed:
1. Update features section to mention `importWithInputs` option
2. Add warning about with-inputs cognitive overhead
3. Update quick start examples to show importWithInputs usage
4. Update feature comparison table if one exists

**Feature list addition**:
```markdown
- **Simple input access**: Use `importWithInputs` option to access flake inputs
  without splitting files across multiple directory trees
```

### 8. Update example project

**File**: `example/myproj/flake.nix`

Changes needed:
1. Add commented example of `importWithInputs` option
2. Show when to use it vs with-inputs directories
3. Provide example of file structure with option enabled

**Example**:
```nix
nixDir = {
  enable = true;
  root = ./.;

  # Enable this to access flake inputs in regular directory files
  # All files will receive 'inputs' as their first parameter
  # importWithInputs = true;
};
```

### 9. Create comprehensive tests

**File**: Create `tests/import-with-inputs-option-tests.nix`

**Testing Strategy**: Use flake-level integration tests with instrumented packages

**Test fixtures needed**:
- `tests/fixtures/import-with-inputs-disabled/` - Flake with `importWithInputs = false`
- `tests/fixtures/import-with-inputs-enabled/` - Flake with `importWithInputs = true`
- `tests/fixtures/import-with-inputs-dual-trees/` - Both regular and with-inputs dirs

**Test cases**:
1. **Option defaults to false** - Check module option default value
2. **Package receives inputs when enabled** - Verify package content shows input access
3. **Module receives inputs when enabled** - Verify module metadata shows inputs
4. **Warning on dual trees** - Check warnings array contains unification message
5. **Backward compatibility** - Regular packages work when option is false
6. **Both importers coexist** - Regular and with-inputs packages both work

**Test packages should be instrumented** to prove which importer was used:
```nix
# Package that proves it received inputs
flakeInputs:
{ writeTextFile, ... }:
writeTextFile {
  name = "proof-of-inputs";
  text = ''
    IMPORTER_TYPE: with-inputs
    INPUT_COUNT: ${toString (builtins.length (builtins.attrNames flakeInputs))}
  '';
}
```

Tests then read package contents to verify behavior.

### 10. Update existing tests to use new importer signature

**Files**: All test files that use importer directly

**Changes needed**:
- Update all `import ../src/importer.nix` calls to include `useInputsEverywhere = false`
- This maintains existing test behavior (tests want explicit importer control)
- Verify all tests still pass

**Example change**:
```nix
# Before:
importer = import ../src/importer.nix {
  inherit pkgs lib inputs;
};

# After:
importer = import ../src/importer.nix {
  inherit pkgs lib inputs;
  useInputsEverywhere = false;  # Explicit default for tests
};
```

**Affected test files**:
- `tests/conflict-detection-tests.nix`
- `tests/module-config-tests.nix`
- `tests/integration-tests.nix`
- `tests/with-inputs-tests.nix`
- `tests/platform-filtering-tests.nix`
- `tests/devshells-tests.nix`
- `tests/devenv-modules-tests.nix`

## Key Design Decisions

### Backward Compatibility
- **Default `false`**: Maintains existing behavior for all current users
- **Additive change**: No breaking changes to API or behavior
- **Parallel support**: with-inputs directories continue to work even with option enabled

### Warning Strategy
- **Warning, not error**: Allows gradual migration
- **Only when option enabled**: Doesn't warn existing users who haven't enabled the feature
- **Clear guidance**: Suggests specific action (unify in default tree)

### Documentation Emphasis
- **Clear cognitive load warnings**: Help users understand the problem
- **Migration path**: Show how to move from with-inputs to importWithInputs
- **Deprecation messaging**: Mark with-inputs as legacy without breaking it

### Implementation Order (Revised for Option 3 Approach)
1. Add option definition in default.nix (task 1)
2. Add warning logic for dual trees (task 2)
3. Refactor src/importer.nix to accept useInputsEverywhere flag (task 3)
4. Update default.nix to pass flag to importer (task 4)
5. Update all existing tests to use new importer signature (task 10)
6. Create new integration tests for importWithInputs feature (task 9)
7. Run all tests to verify backward compatibility
8. Update all documentation (tasks 5-8)
9. Final verification and commit

## Technical Details

### File Locations Summary

- **Main module**: `/home/roman/Projects/nixDir/default.nix` (WILL CHANGE)
- **Import logic**: `/home/roman/Projects/nixDir/src/importer.nix` (WILL CHANGE - add useInputsEverywhere parameter)
- **Library utilities**: `/home/roman/Projects/nixDir/lib.nix` (no changes needed)
- **Documentation**: `/home/roman/Projects/nixDir/docs/` (WILL CHANGE)
- **Tests**: `/home/roman/Projects/nixDir/tests/` (WILL CHANGE - all test files)
- **Example**: `/home/roman/Projects/nixDir/example/myproj/flake.nix` (WILL CHANGE)

### Revised Architecture

With Option 3 approach:
- **importer.nix** will accept `useInputsEverywhere` parameter
- Internal functions `importXxxImpl` and `importXxxWithInputs` remain
- Exported functions use conditional to select based on flag
- **default.nix** passes single flag to importer, no conditionals at call-sites
- **Tests** must explicitly pass `useInputsEverywhere = false` to maintain control

### Warning Implementation (Unchanged)

This remains the same regardless of Option 3 approach. Create a warnings attribute that checks each directory type.

For each directory type that supports with-inputs, check:

```nix
warnings =
  let
    checkDualTree = regularPath: withInputsPath: dirType:
      lib.optional
        (cfg.importWithInputs && builtins.pathExists regularPath && builtins.pathExists withInputsPath)
        ''
          nixDir: Both '${cfg.dirName}/${dirType}' and '${cfg.dirName}/with-inputs/${dirType}' exist.
          Consider unifying them in the default '${cfg.dirName}/${dirType}' tree when using importWithInputs=true.
        '';

    allWarnings = lib.flatten [
      (checkDualTree "${path}/packages" "${path}/with-inputs/packages" "packages")
      # ... etc for all types
    ];
  in
  allWarnings;
```

## Benefits

1. **Reduced cognitive load**: All files in standard locations
2. **Easier navigation**: No need to check two directory trees
3. **Simpler mental model**: One place for each file type
4. **Backward compatible**: Existing users unaffected
5. **Migration path**: Clear path from with-inputs to importWithInputs

## Migration Story

For users currently using with-inputs:

1. Enable `importWithInputs = true` in flake
2. Move files from `nix/with-inputs/packages/` to `nix/packages/`
3. Remove empty `nix/with-inputs/` directories
4. Files now have same signature but clearer location
5. No change to file contents needed (already receive inputs)

## Future Considerations

- Could eventually deprecate with-inputs directories entirely
- Documentation could have "legacy patterns" section for with-inputs
- Migration tool to automatically move files from with-inputs to regular tree

---

## Session Management

### Current Session Status: INCOMPLETE - REVERTING CHANGES

**Work completed in this session:**
1. ✅ Added importWithInputs option to default.nix
2. ✅ Added warning logic for dual directory trees
3. ✅ Modified default.nix to use conditional importers at call-sites
4. ✅ Created test fixture files and directories

**Decision made:** Use Option 3 approach (importer flag) instead of call-site conditionals

**Next steps for fresh session:**
1. Revert all changes from this session (`git reset --hard`)
2. Return to clean `v3` branch state
3. Follow revised implementation plan with Option 3 approach
4. Start with task 1-2 (option + warnings), then task 3-4 (importer refactor)

### Commands to revert and start fresh:

```bash
# Revert all changes
git reset --hard HEAD
git clean -fd

# Verify clean state
git status

# Remove test fixture directory created
rm -rf tests/fixtures/import-with-inputs-option

# Ready to start fresh with Option 3 approach
```
