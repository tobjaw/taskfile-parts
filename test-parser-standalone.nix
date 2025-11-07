# Standalone test to verify YAML parser works correctly
# Run with: nix-instantiate --eval --strict test-parser-standalone.nix

let
  lib = (import <nixpkgs> { }).lib;
  yamlParser = import ./modules/yaml-parser.nix { inherit lib; };

  # Test 1: Simple key-value
  test1 = yamlParser.parseYAML "version: '3'";
  test1_expected = { version = "3"; };
  test1_passed = test1 == test1_expected;

  # Test 2: Nested structure
  test2 = yamlParser.parseYAML ''
    version: '3'
    vars:
      PROJECT_NAME: taskfile-parts
  '';
  test2_expected = {
    version = "3";
    vars = { PROJECT_NAME = "taskfile-parts"; };
  };
  test2_passed = test2 == test2_expected;

  # Test 3: Full task structure
  test3 = yamlParser.parseYAML ''
    version: '3'
    tasks:
      hello:
        desc: Say hello
        cmds:
          - echo "hello"
  '';
  test3_expected = {
    version = "3";
    tasks = {
      hello = {
        desc = "Say hello";
        cmds = [ "echo \"hello\"" ];
      };
    };
  };
  test3_passed = test3 == test3_expected;

  # Debug: Show keys of parsed results
  test1_keys = builtins.attrNames test1;
  test2_keys = builtins.attrNames test2;
  test2_vars_keys = builtins.attrNames (test2.vars or {});
  test3_keys = builtins.attrNames test3;
  test3_tasks_keys = builtins.attrNames (test3.tasks or {});

  allPassed = test1_passed && test2_passed && test3_passed;

in
{
  inherit test1 test2 test3;
  inherit test1_expected test2_expected test3_expected;
  inherit test1_passed test2_passed test3_passed;
  inherit test1_keys test2_keys test2_vars_keys test3_keys test3_tasks_keys;
  inherit allPassed;

  summary = if allPassed then "✓ All standalone tests passed!" else "✗ Some tests failed!";

  # Detailed results
  test1_result = if test1_passed then "✓ Test 1 PASSED" else "✗ Test 1 FAILED: keys are [${toString test1_keys}]";
  test2_result = if test2_passed then "✓ Test 2 PASSED" else "✗ Test 2 FAILED: keys are [${toString test2_keys}], vars keys are [${toString test2_vars_keys}]";
  test3_result = if test3_passed then "✓ Test 3 PASSED" else "✗ Test 3 FAILED: keys are [${toString test3_keys}], tasks keys are [${toString test3_tasks_keys}]";
}
