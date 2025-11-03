{ config, lib, flake-parts-lib, ... }:
let
  inherit (lib) mkOption types mkIf mkMerge;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ config, pkgs, system, ... }: {
    options.taskfile = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable Taskfile integration.

          When enabled, this module will parse your Taskfile.yml and automatically
          generate Nix apps for each task, making them runnable via `nix run .#<task-name>`.
        '';
      };

      path = mkOption {
        type = types.path;
        default = ./Taskfile.yml;
        description = ''
          Path to the Taskfile.yml to parse and integrate.

          This should be a valid Taskfile (version 3 recommended).
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.go-task;
        defaultText = lib.literalExpression "pkgs.go-task";
        description = ''
          The go-task package to use for executing tasks.

          You can override this to use a specific version or a custom build.
        '';
      };

      excludeTasks = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "internal-task" "secret-task" ];
        description = ''
          List of task names to exclude from app and package generation.

          Use this to hide internal or sensitive tasks from the flake outputs.
        '';
      };

      generatePackages = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to generate packages in addition to apps.

          When enabled, tasks will be available as both apps and packages,
          allowing them to be built with `nix build .#task-<name>`.
        '';
      };

      yamlConverter = mkOption {
        type = types.package;
        default = pkgs.yj;
        defaultText = lib.literalExpression "pkgs.yj";
        description = ''
          Package to use for converting YAML to JSON.

          Must provide a command-line tool that can convert YAML to JSON.
          The default `yj` works with the `-yj` flags.
        '';
      };
    };
  });

  config.perSystem = { config, pkgs, system, ... }:
    let
      cfg = config.taskfile;

      # Convert Taskfile.yml to JSON using IFD
      taskfileJson = pkgs.runCommand "taskfile.json"
        {
          nativeBuildInputs = [ cfg.yamlConverter ];
        } ''
        # Convert YAML to JSON
        if ! yj -yj < ${cfg.path} > $out 2>/dev/null; then
          echo "Error: Failed to convert Taskfile at ${cfg.path} to JSON" >&2
          echo "Please ensure the Taskfile is valid YAML" >&2
          exit 1
        fi
      '';

      # Parse the JSON to get task definitions
      taskfileData = builtins.fromJSON (builtins.readFile taskfileJson);

      # Extract tasks, handling missing tasks gracefully
      allTasks = taskfileData.tasks or { };

      # Filter out excluded tasks
      filteredTasks = lib.filterAttrs
        (name: _: !(builtins.elem name cfg.excludeTasks))
        allTasks;

      # Extract task description for metadata
      getTaskDescription = taskName: taskDef:
        if builtins.isAttrs taskDef then
          taskDef.desc or taskDef.summary or "Task: ${taskName}"
        else
          "Task: ${taskName}";

      # Generate a shell script wrapper for a task
      makeTaskScript = taskName: taskDef:
        pkgs.writeShellScript "task-${taskName}" ''
          set -euo pipefail
          exec ${cfg.package}/bin/task \
            --taskfile ${cfg.path} \
            ${lib.escapeShellArg taskName} "$@"
        '';

      # Generate apps for each task
      taskApps = lib.mapAttrs
        (taskName: taskDef: {
          type = "app";
          program = toString (makeTaskScript taskName taskDef);
          meta = {
            description = getTaskDescription taskName taskDef;
          };
        })
        filteredTasks;

      # Generate packages for each task
      taskPackages = lib.mapAttrs
        (taskName: taskDef:
          pkgs.writeShellApplication {
            name = "task-${taskName}";
            runtimeInputs = [ cfg.package ];
            text = ''
              exec task --taskfile ${cfg.path} ${lib.escapeShellArg taskName} "$@"
            '';
            meta = {
              description = getTaskDescription taskName taskDef;
              longDescription = ''
                Executes the '${taskName}' task from the Taskfile.

                ${getTaskDescription taskName taskDef}
              '';
              mainProgram = "task-${taskName}";
            };
          })
        filteredTasks;

    in
    mkMerge [
      # Always generate apps when enabled
      (mkIf cfg.enable {
        apps = taskApps;
      })

      # Optionally generate packages
      (mkIf (cfg.enable && cfg.generatePackages) {
        packages = taskPackages;
      })

      # Add a convenience app to list all tasks
      (mkIf cfg.enable {
        apps.tasks-list = {
          type = "app";
          program = toString (pkgs.writeShellScript "tasks-list" ''
            exec ${cfg.package}/bin/task --taskfile ${cfg.path} --list
          '');
          meta = {
            description = "List all available tasks from the Taskfile";
          };
        };
      })
    ];
}
