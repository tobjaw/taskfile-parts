# taskfile-parts

A [flake-parts](https://flake.parts) module that automatically exposes [Taskfile](https://taskfile.dev) tasks as Nix apps and packages.

```
> nix develop .#
╭──────────────────────╮
│  📋 Available Tasks  │
╰──────────────────────╯

task: Available tasks for this project:
* build:   Build the project
* test:    Run tests
...

Run with: task <task-name> or nix run .#<task-name>
```

## Features

  * **Pure Nix Parsing:** Parses `Taskfile.yml` without Import From Derivation (IFD). Fast evaluation and native cross-platform support.
  * **Auto-Generated Apps:** Every task becomes a runnable app (e.g., `nix run .#build`).
  * **Smart DevShell:** `nix develop` automatically displays a formatted list of available tasks.

## Quick Start

### Using the Template

The fastest way to get started:

```bash
# Initialize a new project with taskfile-parts
nix flake init -t github:tobjaw/taskfile-parts

# List available tasks
nix run .#tasks-list

# Run a task
nix run .#hello
```

### Manual Integration

Add taskfile-parts to your existing flake:

```nix
{
  description = "My project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    taskfile-parts.url = "github:tobjaw/taskfile-parts";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      imports = [
        inputs.taskfile-parts.flakeModules.default
      ];

      perSystem = { config, pkgs, ... }: {
        taskfile = {
          enable = true;
          path = ./Taskfile.yml;
        };
      };
    };
}
```

See [./examples](examples) for extended configuration examples.

## Usage

Once configured, your tasks are available as Nix apps:

```bash
# List all available tasks
nix run .#tasks-list

# Run a specific task
nix run .#build

# Run a task with arguments
nix run .#test -- --verbose

# Show all flake outputs (including tasks)
nix flake show
```

If `generatePackages` is enabled (disabled by default), you can also build tasks:

```bash
# Build a task as a package
nix build .#task-build

# Install a task to your profile
nix profile install .#task-deploy
```

## Configuration

```nix
perSystem = { config, pkgs, ... }: {
  taskfile = {
    # Whether to enable Taskfile integration (default: false)
    enable = true;

    # Path to your Taskfile.yml (default: ./Taskfile.yml)
    path = ./Taskfile.yml;

    # The go-task package to use (default: pkgs.go-task)
    package = pkgs.go-task;

    # List of task names to exclude from generation (default: [])
    excludeTasks = [ "internal-task" "secret-task" ];

    # Whether to generate packages in addition to apps (default: true)
    generatePackages = true;

    # Customize the auto-generated devShell (default: {})
    shell = {
      buildInputs = [ pkgs.jq pkgs.git ];
      env = {
        DATABASE_URL = "postgres://localhost/mydb";
      };
    };

    # Shell hook configuration
    shellHook = {
      # Enable automatic injection into devShells.default (default: true)
      enable = true;

      # Show task list when entering shell (default: true)
      showTaskList = true;

      # Use colors, Unicode, and emojis for fancy formatting (default: true)
      color = true;

      # Custom template for shell hook (default: null, uses built-in)
      template = null;
    };
  };
};
```

## Example Taskfile

Here's an example `Taskfile.yml` that works well with this module:

```yaml
version: '3'

vars:
  PROJECT_NAME: my-project

tasks:
  build:
    desc: Build the project
    cmds:
      - echo "Building {{.PROJECT_NAME}}..."
      - mkdir -p build
      - go build -o build/app

  test:
    desc: Run project tests
    deps:
      - build
    cmds:
      - go test ./...

  clean:
    desc: Clean build artifacts
    cmds:
      - rm -rf build/

  deploy:
    desc: Deploy the application
    deps:
      - test
    cmds:
      - echo "Deploying {{.PROJECT_NAME}}..."
```

## Advanced Usage

### Customizing the Development Shell

When the auto-generated devShell is enabled, you can customize it using the `shell` option. This allows you to add packages, set environment variables, and configure any other `mkShell` attributes:

```nix
perSystem = { config, pkgs, ... }: {
  taskfile = {
    enable = true;
    path = ./Taskfile.yml;

    # Customize the devShell
    shell = {
      # Add packages to the shell environment
      buildInputs = with pkgs; [
        jq        # For JSON processing
        git       # For version control tasks
        nodejs    # For npm/node tasks
        docker    # For container tasks
      ];

      # Set environment variables
      env = {
        DATABASE_URL = "postgres://localhost/mydb";
        API_KEY = "dev-key";
        NODE_ENV = "development";
      };

      # Add custom initialization
      shellHook = ''
        echo "Project initialized!"
        export PATH="$PWD/bin:$PATH"
      '';
    };
  };
};
```

The `go-task` package is always included automatically in `buildInputs`, so you only need to specify additional dependencies your tasks need.

**Note**: If you specify a `shellHook` in `taskfile.shell`, it will prepended before the taskfile shell hook (which displays available tasks).

### Shell Hook Integration

When you enable `taskfile-parts`, a development shell is automatically created with a shell hook that displays available tasks when you enter the shell. This happens automatically - no manual setup required!

#### Automatic Shell Hook (Default Behavior)

Simply enable the module and you get a dev shell with task listing:

```nix
perSystem = { config, pkgs, ... }: {
  taskfile = {
    enable = true;
    path = ./Taskfile.yml;
  };

  # That's it! devShells.default is automatically created with the shell hook
};
```

When you run `nix develop`, you'll see a colorful display:
```
╭──────────────────────╮
│  📋 Available Tasks  │
╰──────────────────────╯

task: Available tasks for this project:
* build:   Build the project
* test:    Run tests
...

Run with: task <task-name> or nix run .#<task-name>
```

The output uses colors and fancy formatting by default.

#### Disable Colors

To use plain text formatting without colors or emojis (useful for terminals that don't support ANSI colors or Unicode well):

```nix
taskfile = {
  enable = true;
  shellHook.color = false;  # Use plain text formatting
};
```

This will display a simpler format without colors, Unicode box-drawing characters, or emojis:
```
Available Tasks
===============
task: Available tasks for this project:
* build:   Build the project
* test:    Run tests
...

Run tasks with: task <task-name> OR nix run .#<task-name>
```

#### Disable Shell Hook

To disable the automatic shell hook creation entirely:

```nix
taskfile = {
  enable = true;
  shellHook.enable = false;  # Disables auto-injection
};
```

#### Custom Shell with Manual Hook Integration

If you want to define your own shell but still include the task listing:

```nix
perSystem = { config, pkgs, ... }: {
  taskfile = {
    enable = true;
    path = ./Taskfile.yml;
    shellHook.enable = false;  # Disable auto-injection
  };

  devShells.default = pkgs.mkShell {
    buildInputs = [ pkgs.go-task pkgs.jq ];
    shellHook = ''
      echo "Welcome to my project!"
      echo ""
    '' + config.taskfile.shellHookText;
  };
};
```

Or disable just the task list but keep custom commands:

```nix
taskfile = {
  enable = true;
  shellHook.showTaskList = false;
};
```

#### Custom Template

Customize the entire shell hook output:

```nix
taskfile = {
  enable = true;
  shellHook = {
    enable = true;
    template = ''
      echo "🎯 Available Tasks:"
      ${config.taskfile.package}/bin/task --taskfile ${config.taskfile.path} --list --silent
      echo ""
      echo "Type 'task <name>' to run a task"
    '';
  };
};
```


### Excluding Tasks

You can exclude specific tasks from being exposed as apps:

```nix
taskfile = {
  enable = true;
  excludeTasks = [ "internal" "private" ];
};
```

### Custom go-task Version

Use a specific version of go-task:

```nix
taskfile = {
  enable = true;
  package = pkgs.go-task.overrideAttrs (old: {
    version = "3.30.0";
  });
};
```

### Multiple Taskfiles

You can configure multiple perSystem instances for different Taskfiles, though typically you'd use Taskfile's built-in `includes` feature instead:

```yaml
version: '3'

includes:
  frontend:
    taskfile: ./frontend/Taskfile.yml
    dir: ./frontend
  backend:
    taskfile: ./backend/Taskfile.yml
    dir: ./backend
```

## Compatibility

- **Taskfile Version**: Recommended to use Taskfile v3 schema
- **Nix**: Requires Nix with flakes enabled
- **Platforms**: Linux (x86_64, aarch64) and macOS (x86_64, aarch64)

## Limitations

- Task dependencies are handled by Taskfile itself, not by Nix
- Variables and environment setup defined in the Taskfile are preserved
- The `internal` tasks (prefixed with `:`) in Taskfile are still processed unless explicitly excluded

## Development

To work on taskfile-parts itself:

```bash
# Clone the repository
git clone https://github.com/tobjaw/taskfile-parts
cd taskfile-parts

# Enter the development shell
nix develop

# Run the test suite
task test           # Quick test summary
task test-verbose   # Detailed test output
nix flake check     # Run all checks including tests

# Test the example
cd examples/basic
nix flake show
nix run .#hello
```

### Testing

The project includes a comprehensive test suite for the YAML parser:

- **Unit Tests**: Tests for all YAML features (scalars, maps, arrays, multi-line strings, etc.)
- **Integration Tests**: Tests parsing of actual Taskfiles from the repository
- **Edge Cases**: Tests for unusual scenarios and special characters

See [tests/README.md](tests/README.md) for detailed testing documentation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
