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

          # Additional packages available to tasks in the devShell
          shellPackages = with pkgs; [
            jq   # Example: useful for JSON processing in tasks
            git  # Example: for version control tasks
          ];

          # Shell hook is automatically injected into devShells.default by default!
          # You can customize it with additional commands:
          shellHook = {
            enable = true;  # default: true
            extraCommands = ''
              echo ""
              echo "💡 Quick start:"
              echo "  task hello    - Run the hello task"
              echo "  task --list   - List all tasks"
            '';
          };
        };

        # The devShell is now automatically created with the shell hook!
        # You can still add your own custom shell if needed:
        # devShells.default = pkgs.mkShell {
        #   buildInputs = [ /* your packages */ ];
        #   shellHook = config.taskfile.shellHookText;  # Manual injection if you prefer
        # };
      };
    };
}
