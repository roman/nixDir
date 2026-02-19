# nixDir

Convention-based flake structure system for Nix.

## Development

Enter the dev shell:
```bash
nix develop --impure
```

## Running Tests

```bash
just test              # Run all tests (unit + integration)
just test-unit         # Run only unit tests
just test-integration  # Run only integration tests
```

## Test Structure

Tests are co-located with their fixtures:
```
tests/
  <test-suite>/
    tests.nix
    fixtures/
      ...
```
