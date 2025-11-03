{
  description = "A flake-parts module for integrating Taskfile with Nix flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # For dogfooding: limit to darwin systems to avoid IFD cross-compilation issues
      # Users of this module won't have this limitation - they can specify any systems they support
      # The IFD issue only affects flake evaluation, not the module itself when used by others
      systems = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Export the taskfile module for use in other flakes
      flake = {
        flakeModules.default = ./modules/taskfile.nix;
        flakeModules.taskfile = ./modules/taskfile.nix;

        # Provide a template for easy project initialization
        templates = {
          default = {
            path = ./templates/default;
            description = "Basic flake with Taskfile integration";
            welcomeText = ''
              # Taskfile Flake Template

              This template provides a basic flake.nix with Taskfile integration.

              ## Next Steps

              1. Edit your Taskfile.yml to define your tasks
              2. Run `nix flake show` to see available tasks
              3. Run `nix run .#<task-name>` to execute a task

              For more information, see: https://github.com/tobjaw/taskfile-parts
            '';
          };
        };
      };

      # Example usage for testing and demonstration
      imports = [
        ./modules/taskfile.nix
      ];

      perSystem =
        { config, pkgs, ... }:
        {
          # Enable the taskfile module for this flake's testing
          taskfile = {
            enable = true;
            path = ./Taskfile.yml;
            package = pkgs.go-task;
            excludeTasks = [ ];
          };

          # Development shell with go-task and nix tooling
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              go-task
              nixfmt-rfc-style
              nil # Nix LSP
            ];

            shellHook = ''
              echo "🎯 Taskfile-parts development environment"
              echo ""
              echo "Available commands:"
              echo "  task --list     - List all tasks in Taskfile.yml"
              echo "  nix flake show  - Show all exposed apps and packages"
              echo ""
            '';
          };
        };
    };
}
