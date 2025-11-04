# YAML Parser Test Suite

Comprehensive test suite for the pure Nix YAML parser used in taskfile-parts.

## Overview

This test suite validates that the YAML parser correctly handles the subset of YAML used by Taskfiles, including:

- **Scalars**: strings, numbers, booleans, null
- **Nested Maps**: multi-level key-value structures
- **Arrays**: lists with various item types
- **Multi-line Strings**: pipe notation (`|`)
- **Comments**: lines starting with `#`
- **Real Taskfile Structures**: complete task definitions
- **Edge Cases**: special characters, empty values, etc.

## Running Tests

### Run All Tests

```bash
# From the repository root
./tests/run-tests.sh

# Or using nix-instantiate directly
nix-instantiate --eval --strict tests/yaml-parser-tests.nix -A all.overall
```

### Run Specific Test Suite

```bash
./tests/run-tests.sh scalars
./tests/run-tests.sh taskfileStructures
./tests/run-tests.sh realWorld
```

### View Individual Suite Results

```bash
# View scalar tests
nix-instantiate --eval --strict tests/yaml-parser-tests.nix -A scalars.summary

# View nested map tests
nix-instantiate --eval --strict tests/yaml-parser-tests.nix -A nestedMaps.summary

# View array tests
nix-instantiate --eval --strict tests/yaml-parser-tests.nix -A arrays.summary
```

### Use in Nix Expressions

```nix
let
  tests = import ./tests/yaml-parser-tests.nix { };
in
{
  # Run all tests
  allTests = tests.all.overall;

  # Check if tests passed
  testsPassed = tests.scalars.success && tests.arrays.success;

  # Get detailed results
  scalarResults = tests.scalars.results;
}
```

## Test Suites

### 1. Scalars (`scalars`)
Tests basic value types:
- Simple strings (quoted and unquoted)
- Integers
- Booleans (true/false)
- Null values
- Empty values

### 2. Nested Maps (`nestedMaps`)
Tests hierarchical structures:
- Simple nested maps
- Multiple nesting levels
- Multiple keys at same level
- Mixed nested and flat structures

### 3. Arrays (`arrays`)
Tests list handling:
- Simple arrays
- Arrays with different types (numbers, booleans, strings)
- Nested arrays of maps
- Mixed array items

### 4. Multi-line Strings (`multilineStrings`)
Tests pipe notation:
- Simple multi-line strings
- Strings with empty lines
- Strings with indentation preserved

### 5. Comments (`comments`)
Tests comment handling:
- Lines with comments
- Multiple comments
- Empty lines with comments

### 6. Taskfile Structures (`taskfileStructures`)
Tests real Taskfile patterns:
- Minimal taskfile with tasks
- Taskfiles with variables
- Multiple commands per task
- Task dependencies
- Task summaries
- Silent flag

### 7. Edge Cases (`edgeCases`)
Tests unusual scenarios:
- Empty documents
- Only comments
- Keys with special characters
- Quoted keys with spaces
- Empty arrays
- Colons in quoted strings
- Number-like strings

### 8. Real World (`realWorld`)
Tests complete, realistic Taskfiles:
- Full taskfile with all features
- Multiple tasks with dependencies
- Variables and templating syntax
- Multi-line summaries

### 9. Actual Taskfiles (`actualTaskfiles`)
Tests parsing of actual Taskfiles from the repository:
- Root `Taskfile.yml`
- Example taskfiles

## Test Structure

Each test case includes:
- **Name**: Descriptive test name
- **Input**: YAML string to parse
- **Expected**: Expected Nix data structure
- **Result**: Actual parsed result
- **Status**: Pass/fail indication

## Adding New Tests

To add new tests, edit `yaml-parser-tests.nix`:

```nix
# Add to an existing suite
arrays = runTests [
  # ... existing tests ...

  (testCase "your new test"
    ''
      yaml: content
    ''
    { yaml = "content"; })
];

# Or create a new suite
myNewSuite = runTests [
  (testCase "test name"
    ''
      yaml: input
    ''
    { expected = "output"; })
];
```

Then update the `all` section to include your new suite:

```nix
all = {
  # ... existing suites ...
  myNewSuite = myNewSuite.summary;

  overall = let
    allSuites = [
      # ... existing suites ...
      myNewSuite
    ];
    # ... rest of overall logic ...
  in
  # ...
};
```

## Test Output Format

Tests produce detailed output:

```
Test Results
============
Total:  8
Passed: 8
Failed: 0

✓ simple string
✓ quoted string
✓ integer value
✓ boolean true
✓ boolean false
✓ null value
✓ empty value
✓ multi-line string

✓ All tests passed!
```

Failed tests show both expected and actual values:

```
✗ test name
  Expected: { key = "expected"; }
  Got: { key = "actual"; }
```

## Continuous Integration

You can integrate these tests into CI pipelines:

```yaml
# GitHub Actions example
- name: Run YAML parser tests
  run: |
    nix-instantiate --eval --strict tests/yaml-parser-tests.nix -A all.overall
```

The tests will exit with a non-zero code if any test fails (when using nix-instantiate in strict mode).

## Performance

The test suite is designed to be fast:
- Pure Nix evaluation (no builds required)
- All tests run in parallel during evaluation
- Typical runtime: < 1 second for all tests

## Troubleshooting

### Tests fail to run

Ensure you're in the repository root:
```bash
cd /path/to/taskfile-parts
./tests/run-tests.sh
```

### Nix evaluation errors

Check the parser syntax:
```bash
nix-instantiate --parse tests/yaml-parser-tests.nix
```

### Individual test debugging

Evaluate a specific test:
```bash
nix-instantiate --eval tests/yaml-parser-tests.nix -A scalars.results
```

## Contributing

When modifying the YAML parser:
1. Add tests for new features
2. Add tests for bug fixes
3. Ensure all existing tests pass
4. Run the full test suite before committing

## License

MIT License - see LICENSE file for details
