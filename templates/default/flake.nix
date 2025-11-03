{
  description = "A project with Taskfile integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    taskfile-parts.url = "github:yourorg/taskfile-parts";  # Update to actual repo URL
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
          excludeTasks = [ ];
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go-task
          ];
        };
      };
    };
}
