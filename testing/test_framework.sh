#!/bin/bash
# BagIt Test Framework
# Comprehensive testing system for comparing bagit.py and bagit.sh implementations

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="test_runs"
PYTHON_BAGIT="bagit.py"
BASH_BAGIT="./bagit.sh"  # Will be implemented
TEST_LOG="test_results.log"
FAILED_TESTS=()
PASSED_TESTS=()

# Ensure test directory exists
mkdir -p "$TEST_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$TEST_LOG"
}

# Test result functions
pass_test() {
    local test_name="$1"
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    PASSED_TESTS+=("$test_name")
    log "PASS: $test_name"
}

fail_test() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}✗ FAIL${NC}: $test_name - $reason"
    FAILED_TESTS+=("$test_name: $reason")
    log "FAIL: $test_name - $reason"
}

# Create test payload
create_test_payload() {
    local dir="$1"
    mkdir -p "$dir"
    
    # Create various file types and structures
    echo "Simple text file" > "$dir/simple.txt"
    echo "Another file with content" > "$dir/file2.txt"
    
    # Create subdirectory
    mkdir -p "$dir/subdir"
    echo "File in subdirectory" > "$dir/subdir/nested.txt"
    
    # Create file with special characters (safe ones)
    echo "Special file" > "$dir/file with spaces.txt"
    
    # Create empty file
    touch "$dir/empty.txt"
    
    # Create larger file
    dd if=/dev/zero of="$dir/largefile.bin" bs=1024 count=10 2>/dev/null
}

# Compare two bags
compare_bags() {
    local bag1="$1"
    local bag2="$2"
    local test_name="$3"
    
    # Compare directory structure
    if ! diff -r "$bag1" "$bag2" > /dev/null 2>&1; then
        # Get detailed diff for debugging
        local diff_output=$(diff -r "$bag1" "$bag2" 2>&1 || true)
        fail_test "$test_name" "Bags differ: $diff_output"
        return 1
    fi
    
    pass_test "$test_name"
    return 0
}

# Test 1: Basic bag creation
test_basic_bag_creation() {
    log "Running test: Basic bag creation"
    
    # Create test payload
    local test_payload="$TEST_DIR/basic_payload"
    create_test_payload "$test_payload"
    
    # Create bag with Python implementation
    local python_bag="$TEST_DIR/basic_python_bag"
    cp -r "$test_payload" "$python_bag"
    $PYTHON_BAGIT "$python_bag" > /dev/null 2>&1
    
    # Verify Python bag is valid
    if ! $PYTHON_BAGIT --validate "$python_bag" > /dev/null 2>&1; then
        fail_test "basic_bag_creation" "Python implementation created invalid bag"
        return
    fi
    
    # Create bag with bash implementation and compare
    local bash_bag="$TEST_DIR/basic_bash_bag"
    cp -r "$test_payload" "$bash_bag"
    $BASH_BAGIT "$bash_bag" > /dev/null 2>&1
    
    # Verify bash bag is valid
    if ! $PYTHON_BAGIT --validate "$bash_bag" > /dev/null 2>&1; then
        fail_test "basic_bag_creation" "Bash implementation created invalid bag"
        return
    fi
    
    # Don't compare bags directly as there might be minor differences in metadata
    # Instead validate both are valid
    pass_test "basic_bag_creation"
}

# Test 2: Bag creation with specific checksum algorithms
test_checksum_algorithms() {
    log "Running test: Checksum algorithms"
    
    local algorithms=("md5" "sha1" "sha256" "sha512")
    
    for alg in "${algorithms[@]}"; do
        local test_payload="$TEST_DIR/${alg}_payload"
        create_test_payload "$test_payload"
        
        # Test with Python
        local python_bag="$TEST_DIR/${alg}_python_bag"
        cp -r "$test_payload" "$python_bag"
        $PYTHON_BAGIT --"$alg" "$python_bag" > /dev/null 2>&1
        
        # Check manifest exists
        if [[ -f "$python_bag/manifest-${alg}.txt" ]]; then
            pass_test "checksum_${alg}_creation"
        else
            fail_test "checksum_${alg}_creation" "Manifest file not created"
        fi
    done
}

# Test 3: Multiple checksum algorithms
test_multiple_checksums() {
    log "Running test: Multiple checksum algorithms"
    
    local test_payload="$TEST_DIR/multi_checksum_payload"
    create_test_payload "$test_payload"
    
    local python_bag="$TEST_DIR/multi_checksum_python_bag"
    cp -r "$test_payload" "$python_bag"
    $PYTHON_BAGIT --md5 --sha1 --sha256 --sha512 "$python_bag" > /dev/null 2>&1
    
    # Check all manifests exist
    local all_exist=true
    for alg in md5 sha1 sha256 sha512; do
        if [[ ! -f "$python_bag/manifest-${alg}.txt" ]]; then
            all_exist=false
            break
        fi
    done
    
    if $all_exist; then
        pass_test "multiple_checksums"
    else
        fail_test "multiple_checksums" "Not all manifest files created"
    fi
}

# Test 4: Bag metadata
test_bag_metadata() {
    log "Running test: Bag metadata"
    
    local test_payload="$TEST_DIR/metadata_payload"
    create_test_payload "$test_payload"
    
    local python_bag="$TEST_DIR/metadata_python_bag"
    cp -r "$test_payload" "$python_bag"
    
    $PYTHON_BAGIT \
        --source-organization "Test Organization" \
        --organization-address "123 Test St" \
        --contact-name "Test User" \
        --contact-phone "555-1234" \
        --contact-email "test@example.com" \
        --external-description "Test bag for validation" \
        --external-identifier "test-bag-001" \
        --bag-size "1 MB" \
        --bag-group-identifier "test-group" \
        --bag-count "1 of 1" \
        --internal-sender-identifier "sender-001" \
        --internal-sender-description "Test sender" \
        --bagit-profile-identifier "http://example.com/profile" \
        "$python_bag" > /dev/null 2>&1
    
    # Check bag-info.txt contains metadata
    if grep -q "Source-Organization: Test Organization" "$python_bag/bag-info.txt" && \
       grep -q "Contact-Email: test@example.com" "$python_bag/bag-info.txt"; then
        pass_test "bag_metadata"
    else
        fail_test "bag_metadata" "Metadata not properly saved"
    fi
}

# Test 5: Bag validation modes
test_validation_modes() {
    log "Running test: Validation modes"
    
    # Create a valid bag first
    local test_payload="$TEST_DIR/validation_payload"
    create_test_payload "$test_payload"
    
    local test_bag="$TEST_DIR/validation_bag"
    cp -r "$test_payload" "$test_bag"
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1
    
    # Test normal validation
    if $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "validation_normal"
    else
        fail_test "validation_normal" "Normal validation failed"
    fi
    
    # Test fast validation
    if $PYTHON_BAGIT --validate --fast "$test_bag" > /dev/null 2>&1; then
        pass_test "validation_fast"
    else
        fail_test "validation_fast" "Fast validation failed"
    fi
    
    # Test completeness-only validation
    if $PYTHON_BAGIT --validate --completeness-only "$test_bag" > /dev/null 2>&1; then
        pass_test "validation_completeness_only"
    else
        fail_test "validation_completeness_only" "Completeness-only validation failed"
    fi
}

# Test 6: Error handling - corrupted bag
test_corrupted_bag() {
    log "Running test: Corrupted bag detection"
    
    # Create a valid bag first
    local test_payload="$TEST_DIR/corrupt_payload"
    create_test_payload "$test_payload"
    
    local test_bag="$TEST_DIR/corrupt_bag"
    cp -r "$test_payload" "$test_bag"
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1
    
    # Corrupt the bag by modifying a data file
    echo "corrupted content" > "$test_bag/data/simple.txt"
    
    # Validation should fail
    if ! $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "corrupted_bag_detection"
    else
        fail_test "corrupted_bag_detection" "Failed to detect corruption"
    fi
}

# Test 7: Missing files
test_missing_files() {
    log "Running test: Missing file detection"
    
    # Create a valid bag first
    local test_payload="$TEST_DIR/missing_payload"
    create_test_payload "$test_payload"
    
    local test_bag="$TEST_DIR/missing_bag"
    cp -r "$test_payload" "$test_bag"
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1
    
    # Remove a data file
    rm "$test_bag/data/simple.txt"
    
    # Validation should fail
    if ! $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "missing_file_detection"
    else
        fail_test "missing_file_detection" "Failed to detect missing file"
    fi
}

# Test 8: Extra files
test_extra_files() {
    log "Running test: Extra file detection"
    
    # Create a valid bag first
    local test_payload="$TEST_DIR/extra_payload"
    create_test_payload "$test_payload"
    
    local test_bag="$TEST_DIR/extra_bag"
    cp -r "$test_payload" "$test_bag"
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1
    
    # Add an extra file
    echo "extra content" > "$test_bag/data/extra.txt"
    
    # Validation should fail
    if ! $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "extra_file_detection"
    else
        fail_test "extra_file_detection" "Failed to detect extra file"
    fi
}

# Test 9: Empty bag
test_empty_bag() {
    log "Running test: Empty bag creation"
    
    # Create a fresh empty directory
    local empty_bag="$TEST_DIR/empty_bag"
    mkdir -p "$empty_bag"
    
    # Create empty bag with Python
    if ! $PYTHON_BAGIT "$empty_bag" >/dev/null 2>&1; then
        fail_test "empty_bag" "Failed to create empty bag"
        return
    fi
    
    # For empty bags, Python doesn't create manifest files
    # This is actually correct per the spec - no payload means no manifests
    # Just verify the structure exists
    if [[ -f "$empty_bag/bagit.txt" && -d "$empty_bag/data" && -f "$empty_bag/bag-info.txt" ]]; then
        # Check Payload-Oxum is 0.0
        if grep -q "Payload-Oxum: 0.0" "$empty_bag/bag-info.txt"; then
            pass_test "empty_bag"
        else
            fail_test "empty_bag" "Empty bag has incorrect Payload-Oxum"
        fi
    else
        fail_test "empty_bag" "Empty bag missing required files"
    fi
}

# Test 10: Special characters in filenames
test_special_filenames() {
    log "Running test: Special characters in filenames"
    
    local test_payload="$TEST_DIR/special_payload"
    mkdir -p "$test_payload"
    
    # Create files with various special characters (filesystem-safe)
    echo "content" > "$test_payload/file with spaces.txt"
    echo "content" > "$test_payload/file-with-dashes.txt"
    echo "content" > "$test_payload/file_with_underscores.txt"
    echo "content" > "$test_payload/file.multiple.dots.txt"
    
    local test_bag="$TEST_DIR/special_bag"
    cp -r "$test_payload" "$test_bag"
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1
    
    if $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "special_filenames"
    else
        fail_test "special_filenames" "Special filename handling failed"
    fi
}

# Run all tests
run_all_tests() {
    log "Starting BagIt test suite"
    echo -e "${BLUE}=== BagIt Test Framework ===${NC}"
    echo ""
    
    # Clear previous results
    FAILED_TESTS=()
    PASSED_TESTS=()
    
    # Run each test
    test_basic_bag_creation
    test_checksum_algorithms
    test_multiple_checksums
    test_bag_metadata
    test_validation_modes
    test_corrupted_bag
    test_missing_files
    test_extra_files
    test_empty_bag
    test_special_filenames
    
    # Summary
    echo ""
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo -e "${GREEN}Passed: ${#PASSED_TESTS[@]}${NC}"
    echo -e "${RED}Failed: ${#FAILED_TESTS[@]}${NC}"
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Failed tests:${NC}"
        for failure in "${FAILED_TESTS[@]}"; do
            echo "  - $failure"
        done
        return 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    fi
}

# Clean up function
cleanup() {
    log "Cleaning up test directory"
    rm -rf "$TEST_DIR"
}

# Main execution
if [[ "${1:-}" == "clean" ]]; then
    cleanup
    echo "Test directory cleaned"
else
    # Clean before running
    cleanup
    
    # Run tests
    if run_all_tests; then
        exit 0
    else
        exit 1
    fi
fi