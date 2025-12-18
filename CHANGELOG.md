# Changelog

All notable changes to this project will be documented in this file.

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

