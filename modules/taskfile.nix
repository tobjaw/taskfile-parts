{
  config,
  lib,
  flake-parts-lib,
  inputs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    mkIf
    mkMerge
    ;

  # Import the Nix-native YAML parser
  yamlParser = import ./yaml-parser.nix { inherit lib; };

  # Parse Taskfile using pure Nix (no IFD)
  # This is much faster and doesn't require building derivations during evaluation
  parseTaskfile = taskfilePath: yamlParser.parseYAMLFile taskfilePath;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
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
          example = [
            "internal-task"
            "secret-task"
          ];
          description = ''
            List of task names to exclude from app and package generation.

            Use this to hide internal or sensitive tasks from the flake outputs.
          '';
        };

        generatePackages = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to generate packages in addition to apps.

            When enabled, tasks will be available as both apps and packages,
            allowing them to be built with `nix build .#task-<name>`.
          '';
        };

        shell = mkOption {
          type = types.submodule {
            freeformType = types.attrs;
            options = {
              buildInputs = mkOption {
                type = types.listOf types.unspecified;
                default = [ ];
                description = "Packages to add to the devShell. Merged (concatenated) across modules.";
              };
              env = mkOption {
                type = types.attrsOf types.str;
                default = { };
                description = "Environment variables to set in the devShell. Merged across modules.";
              };
            };
          };
          default = { };
          example = lib.literalExpression ''
            {
              buildInputs = [ pkgs.nodejs pkgs.jq ];
              env = {
                MY_VAR = "value";
                DATABASE_URL = "postgres://localhost/mydb";
              };
              shellHook = '''
                echo "Custom initialization"
              ''';
            }
          '';
          description = ''
            Attribute set to merge into the auto-generated devShell.

            This allows full customization of the devShell, including:
            - Adding packages via buildInputs
            - Setting environment variables via env
            - Adding custom shellHooks
            - Any other mkShell attributes

            The attributes specified here are merged with the default shell configuration.
            The taskfile.package (go-task) is always included automatically in buildInputs.

            `buildInputs` and `env` are declared options, so multiple modules (e.g. several
            flake-parts imports) contributing to `taskfile.shell.buildInputs` are concatenated
            rather than overwriting each other. Any other key is a freeform passthrough to
            `pkgs.mkShell` and follows normal last-definition-wins semantics.

            Note: If you specify a shellHook here, it will be prepended before the
            taskfile shell hook (if enabled via taskfile.shellHook.enable).
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

          color = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to use colors and fancy formatting in the shell hook.

              When enabled (default), the shell hook will display with ANSI colors,
              bold text, Unicode box-drawing characters, and emojis for a visually appealing output.

              Set to false to use simple, plain text formatting without colors, Unicode, or emojis.
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
    }
  );

  config.perSystem =
    {
      config,
      inputs',
      pkgs,
      system,
      ...
    }@perSystemArgs:
    let
      cfg = config.taskfile;

      # Parse the Taskfile using pure Nix (no IFD!)
      taskfileData = if cfg.enable then parseTaskfile cfg.path else { };

      # Extract tasks from the Taskfile
      allTasks = taskfileData.tasks or { };

      # Filter out excluded tasks
      filteredTasks = lib.filterAttrs (name: _: !(builtins.elem name cfg.excludeTasks)) allTasks;

      # Extract task description for metadata
      getTaskDescription =
        taskName: taskDef:
        if builtins.isAttrs taskDef then
          taskDef.desc or taskDef.summary or "Task: ${taskName}"
        else
          "Task: ${taskName}";

      # Generate a shell script wrapper for a task
      makeTaskScript =
        taskName: taskDef:
        pkgs.writeShellScript "task-${taskName}" ''
          set -euo pipefail
          exec ${cfg.package}/bin/task \
            ${lib.escapeShellArg taskName} "$@"
        '';

      # Generate apps for each task
      taskApps = lib.mapAttrs (taskName: taskDef: {
        type = "app";
        program = toString (makeTaskScript taskName taskDef);
        meta = {
          description = getTaskDescription taskName taskDef;
        };
      }) filteredTasks;

      # Generate packages for each task
      taskPackages = lib.mapAttrs (
        taskName: taskDef:
        pkgs.writeShellApplication {
          name = "task-${taskName}";
          runtimeInputs = [ cfg.package ];
          text = ''
            exec task ${lib.escapeShellArg taskName} "$@"
          '';
          meta = {
            description = getTaskDescription taskName taskDef;
            longDescription = ''
              Executes the '${taskName}' task from the Taskfile.

              ${getTaskDescription taskName taskDef}
            '';
            mainProgram = "task-${taskName}";
          };
        }
      ) filteredTasks;

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
          program = toString (
            pkgs.writeShellScript "tasks-list" ''
              exec ${cfg.package}/bin/task --list
            ''
          );
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
            defaultTemplateColored = ''
              # ANSI color codes
              BOLD="\033[1m"
              CYAN="\033[36m"
              BLUE="\033[34m"
              GREEN="\033[32m"
              YELLOW="\033[33m"
              MAGENTA="\033[35m"
              RESET="\033[0m"
              DIM="\033[2m"

              echo -e "''${BOLD}''${CYAN}╭──────────────────────╮''${RESET}"
              echo -e "''${BOLD}''${CYAN}│''${RESET}  ''${BOLD}''${MAGENTA}📋 Available Tasks''${RESET}  ''${BOLD}''${CYAN}│''${RESET}"
              echo -e "''${BOLD}''${CYAN}╰──────────────────────╯''${RESET}"
              ${cfg.package}/bin/task --taskfile ${cfg.path} --list | tail -n +2
              echo ""
              echo -e "''${DIM}Run with:''${RESET} ''${GREEN}task <task-name>''${RESET} ''${DIM}or''${RESET} ''${BLUE}nix run .#<task-name>''${RESET}"
              echo ""
            '';

            defaultTemplatePlain = ''
              echo "Available Tasks"
              echo "==============="
              ${cfg.package}/bin/task --taskfile ${cfg.path} --list | tail -n +2
              echo ""
              echo "Run tasks with: task <task-name> OR nix run .#<task-name>"
            '';

            defaultTemplate = if cfg.shellHook.color then defaultTemplateColored else defaultTemplatePlain;

            template = if cfg.shellHook.template != null then cfg.shellHook.template else defaultTemplate;
          in
          lib.optionalString cfg.shellHook.showTaskList template;
      })

      # Auto-inject shell hook into devShells.default if enabled
      # Uses lib.mkDefault so user definitions take precedence
      (mkIf (cfg.enable && cfg.shellHook.enable) {
        devShells.default = lib.mkDefault (
          pkgs.mkShell (
            lib.recursiveUpdate cfg.shell {
              # Merge buildInputs: always include go-task, then add any from cfg.shell
              buildInputs = [ cfg.package ] ++ (cfg.shell.buildInputs or [ ]);
              # Prepend custom shellHook before taskfile shellHook
              shellHook =
                lib.optionalString (cfg.shell ? shellHook) "${cfg.shell.shellHook}\n" + cfg.shellHookText;
            }
          )
        );
      })
    ];
}
