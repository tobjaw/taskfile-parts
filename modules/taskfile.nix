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

      shellPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        example = lib.literalExpression "[ pkgs.jq pkgs.git pkgs.nodejs ]";
        description = ''
          Additional packages to include in the auto-generated devShell environment.

          These packages will be available to tasks when they run in the devShell.
          This is useful for ensuring your tasks have access to required tools
          without needing to define a custom devShell.

          Note: The go-task package (config.taskfile.package) is always included.
        '';
      };

      shellHook = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether to automatically inject a shell hook into devShells.default.

            When enabled, the shell hook will be automatically added to your default dev shell,
            displaying available tasks when you enter the shell.

            Set to false to disable automatic injection (you can still manually add
            config.taskfile.shellHookText to your custom shells).
          '';
        };

        showTaskList = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether to display the task list in the shell hook.

            When enabled, entering the dev shell will automatically run `task --list`
            to show all available tasks.
          '';
        };

        template = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = lib.literalExpression ''
            '''
              echo "🎯 My Custom Tasks"
              ''${config.taskfile.package}/bin/task --taskfile ''${config.taskfile.path} --list --silent
            '''
          '';
          description = ''
            Custom shell hook template to run when entering the dev shell.

            When set to null (default), uses the built-in template that displays
            available tasks with nice formatting.

            When set to a string, that string will be used as the shell hook content.
            You can reference the task command and Taskfile path via:
            - config.taskfile.package: The go-task package
            - config.taskfile.path: Path to the Taskfile

            Set this to an empty string to disable output entirely while keeping
            the hook enabled (useful for conditional logic).
          '';
        };

        extraCommands = mkOption {
          type = types.lines;
          default = "";
          example = ''
            echo "Current project: $PWD"
            echo "Build artifacts: ./dist"
          '';
          description = ''
            Additional shell commands to run after the task list.

            Use this to add project-specific information or setup without
            overriding the entire template.
          '';
        };
      };

      shellHookText = mkOption {
        type = types.str;
        internal = true;
        description = ''
          The generated shell hook text that can be added to devShells.

          This is computed based on the shellHook configuration options above.
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

      # Provide shell hook as a passthru attribute for users to add to their devShells
      (mkIf cfg.enable {
        taskfile.shellHookText =
          let
            # Use custom template if provided, otherwise use default
            defaultTemplate = ''
              echo "📋 Available Tasks"
              echo "=================="
              ${cfg.package}/bin/task --taskfile ${cfg.path} --list
              echo ""
              echo "Run tasks with: task <task-name>"
              echo "Or via Nix apps: nix run .#<task-name>"
            '';

            template = if cfg.shellHook.template != null
                       then cfg.shellHook.template
                       else defaultTemplate;

            taskListHook = lib.optionalString cfg.shellHook.showTaskList template;
            extraHook = lib.optionalString (cfg.shellHook.extraCommands != "") cfg.shellHook.extraCommands;
            combinedHook = taskListHook + (lib.optionalString (taskListHook != "" && extraHook != "") "\n") + extraHook;
          in
          combinedHook;
      })

      # Auto-inject shell hook into devShells.default if enabled
      # Uses lib.mkDefault so user definitions take precedence
      (mkIf (cfg.enable && cfg.shellHook.enable) {
        devShells.default = lib.mkDefault (pkgs.mkShell {
          buildInputs = [ cfg.package ] ++ cfg.shellPackages;
          shellHook = cfg.shellHookText;
        });
      })
    ];
}
