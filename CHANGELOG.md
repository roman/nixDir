# Changelog

All notable changes to this project will be documented in this file.

## [3.2.0] - 2026-02-19

### Bug Fixes

- Remove debug trace from with-inputs test
- **example:** Rename devShells to devshells
- Decouple devShells from devenv input requirement

### Documentation

- Add CLAUDE.md with test instructions
- Document .nix files in organizational subdirectories

### Features

- Add recursive nested directory discovery
- Discover .nix files at all directory levels (not just root)
- Add file blocking rule for directory traversal
- Add strictDiscovery option for ignored package detection
- Add followSymlinks option for symlink directory traversal
- Add OutputKind type system and generic importer
- Add Justfile with test targets

### Refactoring

- Rename useInputsEverywhere to importWithInputs
- Add constants module and data-driven dual-tree warnings
- Replace importer with generic importByStrategy implementation
- Replace 6 add* functions with data-driven addFlakeLevelOutput
- Separate nixDir logic from flake-parts module structure
- Use dirNames constants for path construction
- **tests:** Co-locate fixtures with test files
## [3.1.0] - 2026-01-14

### Bug Fixes

- Broken deadnix check

### Features

- Wire importWithInputs option to importer
- Add importWithInputs option with documentation and tests

### Miscellaneous

- Add flake input to allow flake check to work

### Refactoring

- Add useInputsEverywhere parameter to importer

### Testing

- Explicitly pass useInputsEverywhere=false to importer
## [3.0.0] - 2025-12-18

### Bug Fixes

- Nix flake check execution errors
- Execute pre-commit to ensure validity
- Add missing importPackagesWithInputs function
- **tests:** Use git+file: scheme to avoid socket file errors
- Change installFlakeOverlay default to false to prevent infinite recursion

### Documentation

- Add comprehensive documentation and reduce duplication

### Features

- New v3 base version
- Add overlay options to the nixDir setup
- Add nixpkgs config option
- Add with-inputs directory pattern with conflict detection
- Add platform-aware package filtering based on meta.platforms
- Add importDevenvModulesWithInputs and unit tests
- Add semantic versioning release automation

### Miscellaneous

- Add github actions to this repository
- Update flake dependencies

### Refactoring

- Create flake overlay

### Testing

- Add nixtest framework and test infrastructure
- Add comprehensive test coverage

