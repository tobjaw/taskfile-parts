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
      # Support all common platforms - no IFD means cross-platform evaluation works!
      systems = [
        "x86_64-linux"
        "aarch64-linux"
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
        { config, pkgs, system, ... }:
        {
          # Enable the taskfile module for this flake's testing
          taskfile = {
            enable = true;
            path = ./Taskfile.yml;
            package = pkgs.go-task;
            excludeTasks = [ ];
          };

          # Add checks for testing
          checks = {
            # Integration tests - verify parser works with real Taskfiles
            integration-tests = (import ./tests/integration-test.nix { inherit pkgs; }).check;

            # YAML parser unit tests - verify all test cases pass
            yaml-parser-tests = pkgs.runCommand "yaml-parser-tests"
              {
                buildInputs = [ pkgs.nix ];
              }
              ''
                # Run the test suite
                ${pkgs.nix}/bin/nix-instantiate --eval --strict ${./tests/yaml-parser-tests.nix} -A all.overall > $out 2>&1

                # Check if any tests failed
                if grep -q "✗" $out; then
                  cat $out
                  echo ""
                  echo "Tests failed!"
                  exit 1
                fi

                echo "All tests passed!"
              '';
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
              echo "  task test       - Run YAML parser test suite"
              echo "  nix flake show  - Show all exposed apps and packages"
              echo "  nix flake check - Run all tests"
              echo ""
            '';
          };
        };
    };
}
