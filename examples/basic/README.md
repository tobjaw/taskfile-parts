# Basic Example

This example demonstrates how to use taskfile-parts in a simple project.

## What's Included

- `flake.nix` - A minimal flake configuration using taskfile-parts
- `Taskfile.yml` - An example Taskfile with various tasks demonstrating different features

## Usage

### List all available tasks

```bash
nix run .#tasks-list
```

Or use the task command directly:

```bash
task --list
```

### Run individual tasks

```bash
# Run the hello task
nix run .#hello

# Run the build task
nix run .#build

# Run tests (which depends on build)
nix run .#test

# Run all checks
nix run .#check
```

### Build tasks as packages

```bash
# Build the hello task as a package
nix build .#task-hello

# Run the built package
./result/bin/task-hello
```

### View all available outputs

```bash
nix flake show
```

## Development

Enter the development shell to get access to task and other tools:

```bash
nix develop
```

When you enter the shell, you'll see a colorful display of available tasks with a fancy border and colored text. This helps you quickly see what tasks are available to run.

Then you can use task directly:

```bash
task hello
task build
task test
```

## Task Features Demonstrated

- **Simple tasks**: `hello`, `version`
- **Tasks with dependencies**: `test` (depends on `build`), `deploy` (depends on `check` and `build`)
- **Tasks with variables**: Using `{{.GREETING}}`, `{{.PROJECT_NAME}}`, etc.
- **Multi-dependency tasks**: `check` (depends on both `lint` and `test`)
- **Silent tasks**: `version` (doesn't echo commands)
- **Tasks with summaries**: `build` and `dev` have extended descriptions

## Excluding Tasks

Notice that the `internal` task is excluded in the flake configuration:

```nix
taskfile = {
  excludeTasks = [ "internal" ];
};
```

This means it won't appear in `nix flake show` and can't be run via `nix run`, but is still available when using task directly.
