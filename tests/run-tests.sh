#!/usr/bin/env bash
# Test runner for YAML parser tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  YAML Parser Test Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo

# Function to run a test suite
run_suite() {
    local suite_name=$1
    echo -e "${YELLOW}Running ${suite_name} tests...${NC}"

    if nix-instantiate --eval --strict --json tests/yaml-parser-tests.nix -A "${suite_name}.summary" 2>/dev/null | jq -r .; then
        echo -e "${GREEN}✓ ${suite_name} completed${NC}"
        echo
        return 0
    else
        echo -e "${RED}✗ ${suite_name} failed${NC}"
        echo
        return 1
    fi
}

# Check if nix-instantiate is available
if ! command -v nix-instantiate &> /dev/null; then
    echo -e "${RED}Error: nix-instantiate not found${NC}"
    echo "This script requires Nix to be installed."
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq not found. Output may not be formatted properly.${NC}"
    echo
fi

# Change to repository root
cd "$(dirname "$0")/.."

# Run individual test suites if specified
if [ $# -gt 0 ]; then
    for suite in "$@"; do
        run_suite "$suite"
    done
else
    # Run all test suites
    echo -e "${BLUE}Running all test suites...${NC}"
    echo

    nix-instantiate --eval --strict --json tests/yaml-parser-tests.nix -A all.overall 2>/dev/null | jq -r .

    # Also show individual suite results
    echo
    echo -e "${BLUE}Individual Suite Results:${NC}"
    echo

    for suite in scalars nestedMaps arrays multilineStrings comments taskfileStructures edgeCases realWorld actualTaskfiles; do
        nix-instantiate --eval --strict --json tests/yaml-parser-tests.nix -A "all.${suite}" 2>/dev/null | jq -r . || true
    done
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Test run complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
