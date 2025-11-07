# Integration test for taskfile-parts module
# Tests that the module correctly parses Taskfiles and generates outputs
{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:

let
  yamlParser = import ../modules/yaml-parser.nix { inherit lib; };

  # Test various Taskfile examples
  testTaskfile = path:
    let
      parsed = yamlParser.parseYAMLFile path;
      tasks = parsed.tasks or { };
      hasTasks = tasks != { };
      taskNames = builtins.attrNames tasks;
    in
    {
      inherit parsed tasks hasTasks taskNames;
      success = hasTasks;
    };

  # Test root Taskfile
  rootTaskfile = testTaskfile ../Taskfile.yml;

  # Test example Taskfile
  exampleTaskfile = testTaskfile ../examples/basic/Taskfile.yml;

  # Test template Taskfile
  templateTaskfile = testTaskfile ../templates/default/Taskfile.yml;

  # Verify specific task structures
  verifyTaskStructure =
    taskDef:
    let
      hasValidDesc = (taskDef.desc or null) != null || (taskDef.summary or null) != null;
      hasCmds = (taskDef.cmds or null) != null || (taskDef.cmd or null) != null;
    in
    {
      inherit hasValidDesc hasCmds;
      valid = hasValidDesc || hasCmds; # At least one should be present
    };

  # Test that all tasks in root Taskfile are valid
  rootTasksValid = builtins.all
    (taskName: (verifyTaskStructure rootTaskfile.tasks.${taskName}).valid)
    rootTaskfile.taskNames;

  # Test that all tasks in example Taskfile are valid
  exampleTasksValid = builtins.all
    (taskName: (verifyTaskStructure exampleTaskfile.tasks.${taskName}).valid)
    exampleTaskfile.taskNames;

  # Overall test result
  allTestsPassed =
    rootTaskfile.success
    && exampleTaskfile.success
    && templateTaskfile.success
    && rootTasksValid
    && exampleTasksValid;

  testReport = ''

    Integration Test Results
    ════════════════════════════════════════════════════════════

    Root Taskfile:
      ✓ Parsed successfully: ${if rootTaskfile.success then "yes" else "no"}
      ✓ Tasks found: ${toString (builtins.length rootTaskfile.taskNames)}
      ✓ Task names: ${toString rootTaskfile.taskNames}
      ✓ All tasks valid: ${if rootTasksValid then "yes" else "no"}

    Example Taskfile:
      ✓ Parsed successfully: ${if exampleTaskfile.success then "yes" else "no"}
      ✓ Tasks found: ${toString (builtins.length exampleTaskfile.taskNames)}
      ✓ Task names: ${toString exampleTaskfile.taskNames}
      ✓ All tasks valid: ${if exampleTasksValid then "yes" else "no"}

    Template Taskfile:
      ✓ Parsed successfully: ${if templateTaskfile.success then "yes" else "no"}
      ✓ Tasks found: ${toString (builtins.length templateTaskfile.taskNames)}
      ✓ Task names: ${toString templateTaskfile.taskNames}

    Overall Result: ${if allTestsPassed then "✓ PASSED" else "✗ FAILED"}
    ════════════════════════════════════════════════════════════
  '';

in
{
  inherit
    rootTaskfile
    exampleTaskfile
    templateTaskfile
    rootTasksValid
    exampleTasksValid
    allTestsPassed
    testReport
    ;

  # Derivation for nix build
  report = pkgs.writeText "integration-test-report" testReport;

  # Assertion for nix flake check
  check = pkgs.runCommand "taskfile-parts-integration-test"
    {
      buildInputs = [ ];
    }
    ''
      ${if allTestsPassed then ''
        echo "Integration tests passed!"
        echo '${testReport}'
        touch $out
      '' else ''
        echo "Integration tests failed!"
        echo '${testReport}'
        exit 1
      ''}
    '';
}
