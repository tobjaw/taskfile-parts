{
  description = "Example project using taskfile-parts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    # In a real project, this would point to the taskfile-parts repository
    # For this example, we use a relative path to the parent directory
    taskfile-parts = {
      url = "path:../..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        inputs.taskfile-parts.flakeModules.default
      ];

      perSystem =
        { config, pkgs, ... }:
        {
          # Configure the taskfile module
          taskfile = {
            enable = true;
            path = ./Taskfile.yml;
            package = pkgs.go-task;
            excludeTasks = [ "internal" ]; # Exclude the internal task
            generatePackages = true;

            # Customize the auto-generated devShell
            shell = {
              buildInputs = with pkgs; [
                jq # Example: useful for JSON processing in tasks
                git # Example: for version control tasks
              ];
              env = {
                # Example: set environment variables
                # PROJECT_ENV = "development";
              };
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
