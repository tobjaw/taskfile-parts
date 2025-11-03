{
  description = "A project with Taskfile integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    taskfile-parts.url = "github:tobjaw/taskfile-parts";
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
          taskfile = {
            enable = true;
            path = ./Taskfile.yml;
            excludeTasks = [ ];

            # Customize the auto-generated devShell
            shell = {
              buildInputs = with pkgs; [
                # Add additional packages here
                jq
              ];
              env = {
                MY_VAR = "value";
              };
            };
          };

          # The devShell is automatically created with the shell hook!
          # You can override it if needed by uncommenting below:
          # devShells.default = pkgs.mkShell {
          #   buildInputs = [ config.taskfile.package ];
          #   shellHook = config.taskfile.shellHookText;
          # };
        };
    };
}
