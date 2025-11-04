{ lib ? (import <nixpkgs> { }).lib }:

let
  yamlParser = import ../modules/yaml-parser.nix { inherit lib; };

  # Test framework helpers
  testCase = name: input: expected:
    let
      result = yamlParser.parseYAML input;
      passed = result == expected;
    in
    {
      inherit name passed result expected;
      message = if passed then "✓ ${name}" else "✗ ${name}\n  Expected: ${toString expected}\n  Got: ${toString result}";
    };

  # Run all tests and return summary
  runTests = tests:
    let
      results = map (t: t) tests;
      passed = lib.filter (t: t.passed) results;
      failed = lib.filter (t: !t.passed) results;
      total = lib.length results;
      passCount = lib.length passed;
      failCount = lib.length failed;
    in
    {
      inherit results passed failed total passCount failCount;
      success = failCount == 0;
      summary = ''

        Test Results
        ============
        Total:  ${toString total}
        Passed: ${toString passCount}
        Failed: ${toString failCount}

        ${lib.concatStringsSep "\n" (map (t: t.message) results)}

        ${if failCount == 0 then "✓ All tests passed!" else "✗ Some tests failed"}
      '';
    };

in
{
  # Export the test framework
  inherit testCase runTests;

  # Basic Scalar Tests
  scalars = runTests [
    (testCase "simple string"
      ''
        key: value
      ''
      { key = "value"; })

    (testCase "quoted string"
      ''
        key: "quoted value"
      ''
      { key = "quoted value"; })

    (testCase "single quoted string"
      ''
        key: 'single quoted'
      ''
      { key = "single quoted"; })

    (testCase "integer value"
      ''
        key: 42
      ''
      { key = 42; })

    (testCase "boolean true"
      ''
        key: true
      ''
      { key = true; })

    (testCase "boolean false"
      ''
        key: false
      ''
      { key = false; })

    (testCase "null value"
      ''
        key: null
      ''
      { key = null; })

    (testCase "empty value"
      ''
        key:
      ''
      { key = { }; })
  ];

  # Nested Map Tests
  nestedMaps = runTests [
    (testCase "simple nested map"
      ''
        outer:
          inner: value
      ''
      { outer = { inner = "value"; }; })

    (testCase "multiple nested levels"
      ''
        level1:
          level2:
            level3: deep
      ''
      { level1 = { level2 = { level3 = "deep"; }; }; })

    (testCase "multiple keys at same level"
      ''
        key1: value1
        key2: value2
        key3: value3
      ''
      {
        key1 = "value1";
        key2 = "value2";
        key3 = "value3";
      })

    (testCase "mixed nested and flat"
      ''
        flat: value
        nested:
          inner: data
        another: value
      ''
      {
        flat = "value";
        nested = { inner = "data"; };
        another = "value";
      })
  ];

  # Array/List Tests
  arrays = runTests [
    (testCase "simple array"
      ''
        items:
          - one
          - two
          - three
      ''
      { items = [ "one" "two" "three" ]; })

    (testCase "array with numbers"
      ''
        numbers:
          - 1
          - 2
          - 3
      ''
      { numbers = [ 1 2 3 ]; })

    (testCase "array with booleans"
      ''
        flags:
          - true
          - false
          - true
      ''
      { flags = [ true false true ]; })

    (testCase "nested array of maps"
      ''
        tasks:
          - name: task1
            value: val1
          - name: task2
            value: val2
      ''
      {
        tasks = [
          { name = "task1"; value = "val1"; }
          { name = "task2"; value = "val2"; }
        ];
      })

    (testCase "mixed array items"
      ''
        mixed:
          - string
          - 42
          - true
      ''
      { mixed = [ "string" 42 true ]; })
  ];

  # Multi-line String Tests
  multilineStrings = runTests [
    (testCase "simple multi-line string"
      ''
        description: |
          This is line one
          This is line two
      ''
      { description = "This is line one\nThis is line two"; })

    (testCase "multi-line with empty lines"
      ''
        text: |
          First line

          Third line
      ''
      { text = "First line\n\nThird line"; })

    (testCase "multi-line with indentation"
      ''
        code: |
          def hello():
            print("world")
      ''
      { code = "def hello():\n  print(\"world\")"; })
  ];

  # Comment Tests
  comments = runTests [
    (testCase "line with comment"
      ''
        # This is a comment
        key: value
      ''
      { key = "value"; })

    (testCase "multiple comments"
      ''
        # Comment 1
        key1: value1
        # Comment 2
        key2: value2
      ''
      {
        key1 = "value1";
        key2 = "value2";
      })

    (testCase "empty lines and comments"
      ''
        key1: value1

        # Comment

        key2: value2
      ''
      {
        key1 = "value1";
        key2 = "value2";
      })
  ];

  # Taskfile Structure Tests
  taskfileStructures = runTests [
    (testCase "minimal taskfile"
      ''
        version: '3'

        tasks:
          hello:
            desc: Say hello
            cmds:
              - echo "hello"
      ''
      {
        version = "3";
        tasks = {
          hello = {
            desc = "Say hello";
            cmds = [ "echo \"hello\"" ];
          };
        };
      })

    (testCase "taskfile with vars"
      ''
        version: '3'

        vars:
          PROJECT_NAME: my-project
          VERSION: 1.0.0

        tasks:
          build:
            desc: Build project
      ''
      {
        version = "3";
        vars = {
          PROJECT_NAME = "my-project";
          VERSION = "1.0.0";
        };
        tasks = {
          build = {
            desc = "Build project";
          };
        };
      })

    (testCase "taskfile with multiple commands"
      ''
        tasks:
          test:
            desc: Run tests
            cmds:
              - echo "Starting tests"
              - npm test
              - echo "Tests complete"
      ''
      {
        tasks = {
          test = {
            desc = "Run tests";
            cmds = [
              "echo \"Starting tests\""
              "npm test"
              "echo \"Tests complete\""
            ];
          };
        };
      })

    (testCase "taskfile with deps"
      ''
        tasks:
          build:
            desc: Build
            cmds:
              - make build
          test:
            desc: Test
            deps:
              - build
            cmds:
              - make test
      ''
      {
        tasks = {
          build = {
            desc = "Build";
            cmds = [ "make build" ];
          };
          test = {
            desc = "Test";
            deps = [ "build" ];
            cmds = [ "make test" ];
          };
        };
      })

    (testCase "taskfile with summary"
      ''
        tasks:
          deploy:
            desc: Deploy application
            summary: |
              Deploys the application to production.
              This includes building and uploading.
            cmds:
              - ./deploy.sh
      ''
      {
        tasks = {
          deploy = {
            desc = "Deploy application";
            summary = "Deploys the application to production.\nThis includes building and uploading.";
            cmds = [ "./deploy.sh" ];
          };
        };
      })

    (testCase "taskfile with silent flag"
      ''
        tasks:
          version:
            desc: Show version
            silent: true
            cmds:
              - echo "1.0.0"
      ''
      {
        tasks = {
          version = {
            desc = "Show version";
            silent = true;
            cmds = [ "echo \"1.0.0\"" ];
          };
        };
      })
  ];

  # Edge Case Tests
  edgeCases = runTests [
    (testCase "empty document"
      ""
      { })

    (testCase "only comments"
      ''
        # Just a comment
        # Another comment
      ''
      { })

    (testCase "key with special characters"
      ''
        build-task: value
        test_task: value2
      ''
      {
        build-task = "value";
        test_task = "value2";
      })

    (testCase "quoted key with spaces"
      ''
        "key with spaces": value
      ''
      { "key with spaces" = "value"; })

    (testCase "empty array"
      ''
        items:
      ''
      { items = { }; })

    (testCase "colon in quoted string"
      ''
        message: "Hello: World"
      ''
      { message = "Hello: World"; })

    (testCase "number-like string"
      ''
        version: '3'
        port: "8080"
      ''
      {
        version = "3";
        port = "8080";
      })
  ];

  # Complex Real-World Tests
  realWorld = runTests [
    (testCase "complete taskfile example"
      ''
        version: '3'

        vars:
          PROJECT_NAME: example-project
          BUILD_DIR: ./build

        tasks:
          build:
            desc: Build the project
            summary: |
              Builds the project by creating a build directory and
              compiling the necessary artifacts.
            cmds:
              - mkdir -p {{.BUILD_DIR}}
              - echo "Building {{.PROJECT_NAME}}..."
              - echo "Build completed successfully"

          test:
            desc: Run project tests
            deps:
              - build
            cmds:
              - echo "Running tests..."
              - echo "All tests passed!"

          clean:
            desc: Clean build artifacts
            cmds:
              - rm -rf {{.BUILD_DIR}}
              - echo "Cleaned build directory"
      ''
      {
        version = "3";
        vars = {
          PROJECT_NAME = "example-project";
          BUILD_DIR = "./build";
        };
        tasks = {
          build = {
            desc = "Build the project";
            summary = "Builds the project by creating a build directory and\ncompiling the necessary artifacts.";
            cmds = [
              "mkdir -p {{.BUILD_DIR}}"
              "echo \"Building {{.PROJECT_NAME}}...\""
              "echo \"Build completed successfully\""
            ];
          };
          test = {
            desc = "Run project tests";
            deps = [ "build" ];
            cmds = [
              "echo \"Running tests...\""
              "echo \"All tests passed!\""
            ];
          };
          clean = {
            desc = "Clean build artifacts";
            cmds = [
              "rm -rf {{.BUILD_DIR}}"
              "echo \"Cleaned build directory\""
            ];
          };
        };
      })
  ];

  # Parse actual Taskfiles from the repository
  actualTaskfiles = runTests [
    (testCase "parse root Taskfile.yml"
      (builtins.readFile ../Taskfile.yml)
      {
        version = "3";
        vars = {
          PROJECT_NAME = "taskfile-parts";
        };
        tasks = {
          format = {
            desc = "Format Nix files with nixfmt-rfc-style";
            cmds = [ "nixfmt modules/taskfile.nix flake.nix" ];
          };
          check = {
            desc = "Check flake and run nix flake check";
            cmds = [ "nix flake check" ];
          };
          show = {
            desc = "Show flake outputs";
            cmds = [ "nix flake show" ];
          };
          update = {
            desc = "Update flake inputs";
            cmds = [ "nix flake update" ];
          };
          build-example = {
            desc = "Build example hello task";
            cmds = [ "nix build .#hello" ];
          };
          test-example = {
            desc = "Test running example tasks";
            cmds = [
              "echo \"Testing hello task...\""
              "nix run .#hello"
              "echo \"Testing tasks-list...\""
              "nix run .#tasks-list"
            ];
          };
          clean = {
            desc = "Clean build artifacts";
            cmds = [
              "rm -f result"
              "rm -rf examples/*/build"
            ];
          };
        };
      })
  ];

  # Run all test suites
  all = {
    scalars = scalars.summary;
    nestedMaps = nestedMaps.summary;
    arrays = arrays.summary;
    multilineStrings = multilineStrings.summary;
    comments = comments.summary;
    taskfileStructures = taskfileStructures.summary;
    edgeCases = edgeCases.summary;
    realWorld = realWorld.summary;
    actualTaskfiles = actualTaskfiles.summary;

    # Overall summary
    overall =
      let
        allSuites = [
          scalars
          nestedMaps
          arrays
          multilineStrings
          comments
          taskfileStructures
          edgeCases
          realWorld
          actualTaskfiles
        ];
        totalTests = lib.foldl' (acc: suite: acc + suite.total) 0 allSuites;
        totalPassed = lib.foldl' (acc: suite: acc + suite.passCount) 0 allSuites;
        totalFailed = lib.foldl' (acc: suite: acc + suite.failCount) 0 allSuites;
        allPassed = totalFailed == 0;
      in
      ''

        ═══════════════════════════════════════════════════════════
        YAML Parser Test Suite - Overall Results
        ═══════════════════════════════════════════════════════════

        Test Suites: ${toString (lib.length allSuites)}
        Total Tests: ${toString totalTests}
        Passed:      ${toString totalPassed}
        Failed:      ${toString totalFailed}

        ${if allPassed then "✓ ALL TESTS PASSED!" else "✗ SOME TESTS FAILED"}

        ═══════════════════════════════════════════════════════════
      '';
  };
}
