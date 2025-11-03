# taskfile-parts

A [flake-parts](https://flake.parts) module that integrates [Taskfile](https://taskfile.dev) with Nix flakes, automatically exposing your tasks as Nix apps and packages.

## Features

- **Automatic App Generation**: Parse your `Taskfile.yml` and expose each task as a Nix app
- **Package Outputs**: Optionally generate packages for each task
- **Metadata Extraction**: Task descriptions are automatically extracted and added to app metadata
- **Flexible Configuration**: Exclude specific tasks, customize the go-task package, and more
- **Minimal Boilerplate**: Just enable the module and point to your Taskfile. Optionally enable devShell hook for MOTD.
- **Cross-Platform**: Works on Linux and macOS (x86_64 and aarch64)

## Quick Start

### Using the Template

The fastest way to get started:

```bash
# Initialize a new project with taskfile-parts
nix flake init -t github:tobjaw/taskfile-parts

# Update flake inputs
nix flake update

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

## Configuration

The module provides several configuration options:

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

    # YAML to JSON converter package (default: pkgs.yj)
    yamlConverter = pkgs.yj;

    # Shell hook configuration
    shellHook = {
      # Enable automatic injection into devShells.default (default: true)
      enable = true;

      # Show task list when entering shell (default: true)
      showTaskList = true;

      # Custom template for shell hook (default: null, uses built-in)
      template = null;

      # Additional commands to run after task list (default: "")
      extraCommands = "";
    };
  };
};
```

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

## How It Works

1. **YAML Parsing**: The module uses Import From Derivation (IFD) to convert your `Taskfile.yml` to JSON using the `yj` tool
2. **Task Extraction**: Task definitions are parsed from the JSON and filtered based on your configuration
3. **App Generation**: For each task, a shell script wrapper is created that calls `go-task` with the appropriate arguments
4. **Metadata**: Task descriptions (`desc` or `summary` fields) are extracted and added to the app's metadata

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

When you run `nix develop`, you'll see:
```
📋 Available Tasks
==================
task: Available tasks for this project:
* build:   Build the project
* test:    Run tests
...
```

#### Disable Shell Hook

To disable the automatic shell hook creation:

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

#### Extra Commands

Add additional information without overriding the default template:

```nix
taskfile = {
  enable = true;
  shellHook = {
    enable = true;
    extraCommands = ''
      echo ""
      echo "📦 Project Info:"
      echo "  Version: 1.0.0"
      echo "  Build output: ./dist"
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

## Performance Considerations

- The module uses Import From Derivation (IFD), which means the Taskfile is converted to JSON during evaluation
- This is typically very fast (milliseconds) with the `yj` converter
- The conversion is cached based on the content hash of your Taskfile

## Limitations

- Task dependencies are handled by Taskfile itself, not by Nix
- Variables and environment setup defined in the Taskfile are preserved
- Tasks must be defined in a valid YAML format
- The `internal` tasks (prefixed with `:`) in Taskfile are still processed unless explicitly excluded

## Development

To work on taskfile-parts itself:

```bash
# Clone the repository
git clone https://github.com/tobjaw/taskfile-parts
cd taskfile-parts

# Enter the development shell
nix develop

# Test the example
cd examples/basic
nix flake show
nix run .#hello
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Related Projects

- [Taskfile](https://taskfile.dev) - Task runner / simpler Make alternative written in Go
- [flake-parts](https://flake.parts) - Simplify Nix flakes with the module system

## Acknowledgments

- Inspired by the Nix community's work on flake-parts modules
- Built on top of the excellent Taskfile project
- Uses the `yj` YAML/JSON converter for parsing
