# Simple test runner that can be used with nix eval
# Usage: nix eval --file tests/run-tests.nix

let
  tests = import ./yaml-parser-tests.nix { };

  # Pretty print the overall results
  printResults = ''
    ${tests.all.overall}

    Individual Test Suite Results:
    ─────────────────────────────────────────────────────────

    ${tests.all.scalars}

    ${tests.all.nestedMaps}

    ${tests.all.arrays}

    ${tests.all.multilineStrings}

    ${tests.all.comments}

    ${tests.all.taskfileStructures}

    ${tests.all.edgeCases}

    ${tests.all.realWorld}

    ${tests.all.actualTaskfiles}
  '';

  # Determine success/failure
  allSuites = [
    tests.scalars
    tests.nestedMaps
    tests.arrays
    tests.multilineStrings
    tests.comments
    tests.taskfileStructures
    tests.edgeCases
    tests.realWorld
    tests.actualTaskfiles
  ];

  allPassed = builtins.all (suite: suite.success) allSuites;

in
{
  # Main output
  results = printResults;

  # Success indicator (for scripts)
  success = allPassed;

  # Individual suites for detailed inspection
  inherit (tests) scalars nestedMaps arrays multilineStrings comments
    taskfileStructures edgeCases realWorld actualTaskfiles;

  # All results combined
  all = tests.all;
}
