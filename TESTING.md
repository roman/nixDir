# Testing nixDir

## Running Tests

Run all tests:

```bash
nix run .#nixtests:run
```

Or use the helper script:

```bash
./tests/run-tests.sh
```

## Test Framework

nixDir uses [nixtest](https://gitlab.com/technofab/nixtest) for testing.

## Test Organization

Test files are located in `tests/` with fixtures in `tests/fixtures/`.
Each test file is self-documenting - read the individual test files to understand what they test.
