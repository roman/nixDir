# Contributing to nixDir

Thank you for your interest in contributing to nixDir!

## How to Contribute

### 1. Check Existing Issues

Before starting work, check if there's already an [open
issue](https://github.com/roman/nixDir/issues) discussing your idea or problem.

### 2. Open an Issue First

For significant changes:
1. Open an issue describing the problem or feature
2. Discuss the approach with maintainers
3. Wait for feedback before starting implementation

For small fixes (typos, docs), feel free to open a PR directly.

### 3. Create a Pull Request

1. Fork the repository
2. Create a branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run tests: `nix flake check`
5. Commit with clear messages (see below)
6. Push and open a PR

## Development Setup

### Prerequisites

- Nix with flakes enabled
- Git
- Basic familiarity with Nix and flake-parts

### Getting Started

```bash
# Clone the repository
git clone https://github.com/roman/nixDir 
cd nixDir

# Enter development shell
nix develop

# The development shell includes:
# - nixpkgs-fmt (code formatting)
# - deadnix (dead code detection)
# - nil (Nix language server)
```

### Pre-commit Hooks

Pre-commit hooks are automatically installed when you enter the dev shell:

```bash
nix develop
# Hooks are now active and will run on git commit
```

The hooks check:
- **nixpkgs-fmt**: Code formatting
- **deadnix**: Unused code detection
- **nil**: Nix syntax validation

## Running Tests

nixDir uses [nixtest](https://gitlab.com/technofab/nixtest) for unit testing and bash scripts for integration testing.

### All Tests

```bash
# Run all test suites
nix flake check
```

### Specific Test Suites

```bash
# Run only conflict detection tests
nix run .#nixtests:run -- conflict-detection

# Run only module config tests
nix run .#nixtests:run -- module-config

# Run only integration tests
nix run .#nixtests:run -- integration

# Run only with-inputs tests
nix run .#nixtests:run -- with-inputs

# Run only devshells tests
nix run .#nixtests:run -- devshells
```

### Helper Scripts

```bash
# Run unit tests
./tests/run-unit-tests.sh

# Run integration tests
./tests/run-integration-tests.sh

# Run all tests
./tests/run-tests.sh
```

## Code Style

nixDir follows a style similar to nixpkgs with some project-specific conventions.

### Rule #1: Go with the Flow

Write code that fits with existing patterns. Don't reformat existing code unless specifically improving it.

### Nix Code Formatting

- **Indentation**: 2 spaces (enforced by nixpkgs-fmt)
- **Line length**: Aim for 80-100 characters
- **Let pre-commit hooks handle formatting**: Run `nix develop` and they'll format on commit

### Naming Conventions

#### File Names

- Use kebab-case: `my-module.nix`, `package-name.nix`

#### Attribute Names

- Functions: camelCase (`importPackages`, `checkConflicts`)
- Options: camelCase (`nixDir.enable`, `nixDir.dirName`)
- Outputs: Match file names (kebab-case)

### Code Organization

- Keep functions focused and single-purpose
- Use descriptive names
- Add comments for non-obvious logic
- Extract complex logic into lib.nix

## Testing Guidelines

### When to Add Tests

Add tests when:
- Adding new features
- Fixing bugs
- Changing existing behavior
- Adding new directory types

### Test File Organization

Tests are in `tests/` with fixtures in `tests/fixtures/`:

```
tests/
├── conflict-detection-tests.nix
├── module-config-tests.nix
├── integration-tests.nix
├── with-inputs-tests.nix
├── devshells-tests.nix
└── fixtures/
    ├── basic/
    ├── conflicts/
    └── ...
```

### Writing Tests

Tests use the nixtest format:

```nix
# tests/my-feature-test.nix
{ pkgs, lib, inputs }:

{
  testCase1 = {
    expr = /* test expression */;
    expected = /* expected result */;
  };

  testCase2 = {
    expr = /* test expression */;
    expected = /* expected result */;
  };
}
```

### Integration Tests

Integration tests use bash scripts and test the example project:

```bash
# tests/integration.sh
# Test that packages are discoverable
result=$(nix flake show ./example/myproj 2>&1)
if [[ $result == *"packages"* ]]; then
  echo "✓ Packages discovered"
else
  echo "✗ Packages not discovered"
  exit 1
fi
```

## Documentation

### When to Update Docs

Update documentation when:
- Adding new features
- Changing existing behavior
- Adding new options
- Fixing bugs that affect documented behavior

### Documentation Structure

- **README.md**: Keep concise, update if core features change
- **docs/getting-started.md**: Update for setup changes
- **docs/directory-structure.md**: Update for new directory types
- **docs/with-inputs.md**: Update for signature changes
- **docs/testing.md**: Update for test process changes

### Writing Documentation

Follow the [oss-nix-documentation](https://github.com/your-org/oss-nix-documentation) skill guidelines:

- Write for users, not developers
- Provide working examples
- Explain "why" not just "how"
- Keep examples self-contained
- Add warnings for common pitfalls

## Commit Messages

### Format

```
type: Brief description (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain the problem this solves and why this approach was chosen.

Fixes #123
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code refactoring (no behavior change)
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (deps, ci, etc.)

### Examples

```
feat: add support for darwin configurations

Adds nix-darwin configuration discovery in the configurations/darwin
directory. Follows the same pattern as NixOS configurations.

Fixes #42
```

```
fix: resolve conflict detection for nested modules

The conflict detection was incorrectly flagging nested modules
as conflicts when they were in different directories. Now checks
the full path before reporting conflicts.

Fixes #56
```

```
docs: improve with-inputs pattern explanation

Adds more examples and clarifies the signature differences between
portable and non-portable code. Includes troubleshooting section.
```

## Pull Request Process

### Before Submitting

1. ✅ Tests pass: `nix flake check`
2. ✅ Code is formatted (pre-commit hooks handle this)
3. ✅ Documentation is updated
4. ✅ Commit messages follow conventions
5. ✅ No unrelated changes included

### PR Description

Include in your PR:

- **What**: Brief description of changes
- **Why**: Problem being solved
- **How**: Approach taken
- **Testing**: How you tested the changes
- **Breaking Changes**: Any backwards-incompatible changes

### Review Process

1. **Automated Checks**: CI runs tests and linters
2. **Code Review**: Maintainers review code and approach
3. **Discussion**: Address feedback, discuss alternatives
4. **Approval**: Once approved, PR is merged

### What Reviewers Look For

- Code quality and style
- Tests for new features
- Documentation updates
- Breaking changes clearly marked
- Backward compatibility considered
- Clear commit messages

## Project Structure for Contributors

Understanding the codebase:

```
nixDir/
├── flake.nix           # Flake definition, test configuration
├── default.nix         # Main flake module (options + logic)
├── lib.nix             # Helper functions
├── src/
│   └── importer.nix    # Import logic for different types
├── tests/              # Test suite
├── example/            # Example project for testing
└── docs/               # Documentation
```

### Key Files

- **default.nix**: Core module defining options and orchestration
- **src/importer.nix**: Logic for importing packages, modules, etc.
- **lib.nix**: Utility functions like conflict detection
- **tests/**: Test suites for different features

## Getting Help

- **Questions**: Open a [discussion](https://github.com/roman/nixDir/discussions)
- **Bugs**: Open an [issue](https://github.com/roman/nixDir/issues)
- **PRs**: Ask questions in PR comments

Thank you for contributing! 🎉
