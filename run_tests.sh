#!/bin/bash

# Full test suite runner for Reactive Trading Simulator

echo "=============================================="
echo "  Reactive Trading Simulator - Test Runner"
echo "=============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run tests and check result
run_test() {
    echo -e "${BLUE}Running $1...${NC}"
    eval $2
    
    if [ $? -eq 0 ]
    then
        echo -e "${GREEN}✓ $1 tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $1 tests failed${NC}"
        return 1
    fi
    echo ""
}

# Track failures
FAILURES=0

# Build the project
echo "Building project..."
dune build
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed. Aborting tests.${NC}"
    exit 1
fi
echo -e "${GREEN}Build successful.${NC}"
echo ""

# All Tests
echo -e "${BLUE}Running all tests...${NC}"
dune runtest
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${RED}✗ Some tests failed${NC}"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# If you've implemented the additional tests:
# Uncomment these as you implement them

# Stress Tests (when implemented)
# echo -e "${BLUE}Running stress tests...${NC}"
# dune runtest test/test_stress.ml
# if [ $? -eq 0 ]; then
#     echo -e "${GREEN}✓ Stress tests passed${NC}"
# else
#     echo -e "${RED}✗ Stress tests failed${NC}"
#     FAILURES=$((FAILURES + 1))
# fi
# echo ""

# Scenario Tests (when implemented)
# echo -e "${BLUE}Running scenario tests...${NC}"
# dune runtest test/test_scenarios.ml
# if [ $? -eq 0 ]; then
#     echo -e "${GREEN}✓ Scenario tests passed${NC}"
# else
#     echo -e "${RED}✗ Scenario tests failed${NC}"
#     FAILURES=$((FAILURES + 1))
# fi
# echo ""

# Benchmark Tests (when core_bench is installed)
# if command -v core_bench &> /dev/null; then
#     echo -e "${BLUE}Running benchmarks...${NC}"
#     dune exec bench/bench_order_book.exe
# else
#     echo -e "${BLUE}Skipping benchmarks (core_bench not installed)${NC}"
# fi

# Main Simulation Run (short test)
echo -e "${BLUE}Running main simulation (5 ticks)...${NC}"
dune exec bin/main.exe -- --ticks 5
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Simulation ran successfully${NC}"
else
    echo -e "${RED}✗ Simulation failed${NC}"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Results summary
echo "=============================================="
echo "              Test Summary"
echo "=============================================="
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILURES test groups failed.${NC}"
    exit 1
fi
