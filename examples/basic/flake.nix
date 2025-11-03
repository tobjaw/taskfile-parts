{
  description = "Example project using taskfile-parts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # In a real project, this would point to the taskfile-parts repository
    # For this example, we use a relative path to the parent directory
    taskfile-parts.url = "path:../..";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      imports = [
        inputs.taskfile-parts.flakeModules.default
      ];

      perSystem = { config, pkgs, ... }: {
        # Configure the taskfile module
        taskfile = {
          enable = true;
          path = ./Taskfile.yml;
          package = pkgs.go-task;
          excludeTasks = [ "internal" ];  # Exclude the internal task
          generatePackages = true;
        };

        # Optional: Add a development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go-task
          ];

          shellHook = ''
            echo "📋 Example Taskfile Project"
            echo ""
            echo "Available commands:"
            echo "  nix run .#tasks-list    - List all tasks"
            echo "  nix run .#hello         - Run the hello task"
            echo "  nix run .#build         - Run the build task"
            echo "  nix run .#test          - Run tests"
            echo ""
            echo "Or use task directly:"
            echo "  task --list"
            echo "  task hello"
            echo ""
          '';
        };
      };
    };
}
