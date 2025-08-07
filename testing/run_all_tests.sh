#!/opt/homebrew/bin/bash
#
# run_all_tests.sh - Run all bagit-bash test suites
#

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test files in order of execution
readonly TEST_SUITES=(
    "test_framework.sh"
    "test_cases.sh" 
    "comparison_test.sh"
    "error_test.sh"
)

# Counters
total_suites=0
passed_suites=0
failed_suites=0

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  BagIt-Bash Testing Framework  ${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Check if we're in the right directory
if [[ ! -f "test_framework.sh" ]]; then
    echo -e "${RED}Error: Please run this script from the testing directory${NC}"
    exit 1
fi

# Check if bagit.sh exists
if [[ ! -f "../bagit.sh" ]]; then
    echo -e "${RED}Error: bagit.sh not found in parent directory${NC}"
    exit 1
fi

# Run each test suite
for suite in "${TEST_SUITES[@]}"; do
    if [[ ! -f "$suite" ]]; then
        echo -e "${YELLOW}Warning: Test suite $suite not found, skipping${NC}"
        continue
    fi
    
    ((total_suites++))
    
    echo -e "${BLUE}Running: $suite${NC}"
    echo "----------------------------------------"
    
    if bash "$suite"; then
        echo -e "${GREEN}✓ $suite passed${NC}"
        ((passed_suites++))
    else
        echo -e "${RED}✗ $suite failed${NC}"
        ((failed_suites++))
    fi
    
    echo
done

# Print summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}           SUMMARY               ${NC}"
echo -e "${BLUE}================================${NC}"
echo "Total test suites: $total_suites"
echo -e "Passed: ${GREEN}$passed_suites${NC}"
if [[ $failed_suites -gt 0 ]]; then
    echo -e "Failed: ${RED}$failed_suites${NC}"
else
    echo -e "Failed: $failed_suites"
fi

echo

if [[ $failed_suites -eq 0 ]]; then
    echo -e "${GREEN}🎉 All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some test suites failed${NC}"
    exit 1
fi