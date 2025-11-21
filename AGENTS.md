# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

taskfile-parts is a flake-parts module that automatically exposes Taskfile tasks as Nix apps and packages. The project's key innovation is **pure Nix parsing** of Taskfile.yml without Import From Derivation (IFD), enabling fast evaluation and native cross-platform support.

## Development Commands

### Testing
```bash
# Run YAML parser test suite (quick summary)
task test
# Or: nix-instantiate --eval --strict tests/yaml-parser-tests.nix -A all.overall

# Run tests with detailed output
task test-verbose
# Or: nix-instantiate --eval --strict tests/run-tests.nix -A results

# Run all checks including tests
nix flake check

# Run a specific test suite
nix-instantiate --eval --strict tests/yaml-parser-tests.nix -A scalars.summary
```

### Building and Running
```bash
# Show all flake outputs
task show
# Or: nix flake show

# List available tasks
nix run .#tasks-list

# Run a task from this project's Taskfile
nix run .#<task-name>

# Test example tasks
task test-example
```

### Code Quality
```bash
# Format Nix files with nixfmt-rfc-style
task format

# Run flake check
task check
```

### Other
```bash
# Update flake inputs
task update
```

## Architecture

### Core Components

1. **modules/taskfile.nix** - Main flake-parts module
   - Defines configuration options (enable, path, package, excludeTasks, generatePackages, shell, shellHook)
   - Parses Taskfile.yml using the pure Nix parser
   - Generates apps for each task (always)
   - Optionally generates packages (controlled by `generatePackages`)
   - Auto-injects shell hooks into devShells.default (controlled by `shellHook.enable`)
   - Creates task wrapper scripts that invoke `go-task`

2. **modules/yaml-parser.nix** - Pure Nix YAML parser
   - Parses YAML without IFD (Import From Derivation)
   - Handles Taskfile-relevant YAML subset: scalars, nested maps, arrays, multi-line strings (pipe notation)
   - Main functions: `parseYAML` (string) and `parseYAMLFile` (path)
   - Line-by-line parsing with indentation-based structure detection

3. **tests/** - Comprehensive test suite
   - Unit tests for YAML parser features (scalars, maps, arrays, multi-line strings, comments, edge cases)
   - Integration tests parsing real Taskfiles from the repository
   - Tests run purely in Nix evaluation (no builds)
   - Test suites: scalars, nestedMaps, arrays, multilineStrings, comments, taskfileStructures, edgeCases, realWorld, actualTaskfiles

4. **templates/default/** - Project initialization template
   - Used via `nix flake init -t github:tobjaw/taskfile-parts`
   - Provides minimal flake.nix with taskfile-parts integration

5. **examples/basic/** - Example project demonstrating integration

### Key Design Decisions

- **No IFD**: The YAML parser is implemented in pure Nix, avoiding Import From Derivation. This makes evaluation fast and enables cross-platform evaluation.
- **flake-parts integration**: Uses perSystem for cross-platform support
- **Task wrapping**: Each task becomes a shell script that invokes `go-task <taskname>`
- **Auto-generated outputs**: Tasks automatically become both apps and optionally packages
- **Smart defaults**: Shell hook auto-injection is enabled by default but can be disabled

### Configuration Flow

1. User enables module with `taskfile.enable = true`
2. Module reads Taskfile.yml at `taskfile.path` (default: ./Taskfile.yml)
3. YAML parser converts YAML to Nix attrset (parseTaskfile)
4. Tasks are extracted and filtered (excludeTasks)
5. Apps are generated for each task (makeTaskScript)
6. Optionally, packages are generated (if generatePackages = true)
7. Shell hook is auto-injected into devShells.default (if shellHook.enable = true)

### Shell Hook Behavior

The shell hook system has several configuration levels:
- `shellHook.enable` - Controls auto-injection into devShells.default (default: true)
- `shellHook.showTaskList` - Controls whether tasks are listed (default: true)
- `shellHook.color` - Controls colored/fancy vs plain output (default: true)
- `shellHook.template` - Custom template override (default: null, uses built-in)
- Users can manually add `config.taskfile.shellHookText` to custom shells

### Module Options

Key options in modules/taskfile.nix:
- `enable` - Enable module
- `path` - Path to Taskfile.yml
- `package` - go-task package to use
- `excludeTasks` - List of task names to hide from outputs
- `generatePackages` - Whether to create packages in addition to apps
- `shell` - Attrs to merge into auto-generated devShell (buildInputs, env, shellHook, etc.)
- `shellHook.{enable,showTaskList,color,template}` - Shell hook configuration
- `shellHookText` - Internal computed shell hook text

## Testing Notes

- **Test location**: tests/yaml-parser-tests.nix contains all test cases
- **Test structure**: Each test suite returns `{ results, summary, success }`
- **Running individual suites**: Access via `-A <suiteName>.summary`
- **Integration tests**: tests/integration-test.nix parses actual Taskfiles
- **Test output**: Colored checkmarks (✓/✗) with detailed failure info
- **CI integration**: Tests can be run in CI via nix-instantiate with exit code

## Working with the YAML Parser

The YAML parser (modules/yaml-parser.nix) is the most complex component:

### Parser Algorithm
1. Split input into lines
2. Track indentation levels to determine structure
3. Detect key-value pairs (look for `:`)
4. Detect array items (look for `- `)
5. Handle multi-line strings (pipe `|` notation)
6. Recursively parse nested structures

### Supported YAML Features
- Scalars: strings (quoted/unquoted), integers, booleans, null
- Maps: nested key-value structures
- Arrays: lists with `- ` prefix
- Multi-line strings: pipe notation (`|`, `|-`, `|+`)
- Comments: `#` prefix (ignored)

### Not Supported
- Anchors and aliases (`&`, `*`)
- Complex YAML features beyond Taskfile needs
- Flow-style collections (`[...]`, `{...}`)
- Explicit type tags (`!!str`, etc.)

### Adding Parser Features
1. Add test cases to tests/yaml-parser-tests.nix first
2. Modify parsing logic in modules/yaml-parser.nix
3. Focus on `parseLines` function for structural changes
4. Run `task test` to verify all tests pass

## Cross-Platform Support

The project supports:
- x86_64-linux
- aarch64-linux
- x86_64-darwin
- aarch64-darwin

Pure Nix parsing enables evaluation on all platforms without platform-specific builds.
