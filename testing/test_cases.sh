#!/bin/bash
# Advanced BagIt Test Cases
# Additional test scenarios for comprehensive bagit.py/bagit.sh comparison

set -euo pipefail

# Source the main test framework
source ./test_framework.sh

# Test 11: Multiprocessing
test_multiprocessing() {
    log "Running test: Multiprocessing"
    
    local test_payload="$TEST_DIR/multiproc_payload"
    mkdir -p "$test_payload"
    
    # Create many files to test multiprocessing
    for i in {1..20}; do
        dd if=/dev/zero of="$test_payload/file$i.dat" bs=1024 count=100 2>/dev/null
    done
    
    # Test with single process
    local single_bag="$TEST_DIR/single_proc_bag"
    cp -r "$test_payload" "$single_bag"
    time_start=$(date +%s.%N)
    $PYTHON_BAGIT --processes 1 "$single_bag" > /dev/null 2>&1
    time_single=$(echo "$(date +%s.%N) - $time_start" | bc)
    
    # Test with multiple processes
    local multi_bag="$TEST_DIR/multi_proc_bag"
    cp -r "$test_payload" "$multi_bag"
    time_start=$(date +%s.%N)
    $PYTHON_BAGIT --processes 4 "$multi_bag" > /dev/null 2>&1
    time_multi=$(echo "$(date +%s.%N) - $time_start" | bc)
    
    # Both should be valid
    if $PYTHON_BAGIT --validate "$single_bag" > /dev/null 2>&1 && \
       $PYTHON_BAGIT --validate "$multi_bag" > /dev/null 2>&1; then
        pass_test "multiprocessing"
        log "Single process time: ${time_single}s, Multi process time: ${time_multi}s"
    else
        fail_test "multiprocessing" "Multiprocessing validation failed"
    fi
}

# Test 12: Payload-Oxum edge cases
test_payload_oxum() {
    log "Running test: Payload-Oxum edge cases"
    
    # Test with exact byte boundaries
    local test_payload="$TEST_DIR/oxum_payload"
    mkdir -p "$test_payload"
    
    # Create files with specific sizes
    echo -n "1234567890" > "$test_payload/10bytes.txt"  # Exactly 10 bytes
    dd if=/dev/zero of="$test_payload/1024bytes.bin" bs=1024 count=1 2>/dev/null
    
    local test_bag="$TEST_DIR/oxum_bag"
    cp -r "$test_payload" "$test_bag"
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1
    
    # Check Payload-Oxum is correct
    local oxum=$(grep "Payload-Oxum:" "$test_bag/bag-info.txt" | cut -d' ' -f2)
    local expected_bytes=$((10 + 1024))
    local expected_files=2
    
    if [[ "$oxum" == "${expected_bytes}.${expected_files}" ]]; then
        pass_test "payload_oxum_calculation"
    else
        fail_test "payload_oxum_calculation" "Expected ${expected_bytes}.${expected_files} but got $oxum"
    fi
}

# Test 13: Unicode filenames
test_unicode_filenames() {
    log "Running test: Unicode filenames"
    
    local test_payload="$TEST_DIR/unicode_payload"
    mkdir -p "$test_payload"
    
    # Create files with unicode names
    echo "content" > "$test_payload/café.txt"
    echo "content" > "$test_payload/файл.txt"
    echo "content" > "$test_payload/文件.txt"
    echo "content" > "$test_payload/αρχείο.txt"
    
    local test_bag="$TEST_DIR/unicode_bag"
    cp -r "$test_payload" "$test_bag"
    
    if $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1 && \
       $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "unicode_filenames"
    else
        fail_test "unicode_filenames" "Unicode filename handling failed"
    fi
}

# Test 14: Very long filenames and deep directories
test_long_paths() {
    log "Running test: Long paths"
    
    local test_payload="$TEST_DIR/longpath_payload"
    mkdir -p "$test_payload"
    
    # Create deep directory structure
    local deep_path="$test_payload"
    for i in {1..10}; do
        deep_path="$deep_path/level$i"
        mkdir -p "$deep_path"
    done
    echo "deep content" > "$deep_path/file.txt"
    
    # Create file with long name (but within filesystem limits)
    local long_name="very_long_filename_that_tests_the_handling_of_extended_filenames_in_bagit_implementation"
    echo "content" > "$test_payload/${long_name}.txt"
    
    local test_bag="$TEST_DIR/longpath_bag"
    cp -r "$test_payload" "$test_bag"
    
    if $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1 && \
       $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "long_paths"
    else
        fail_test "long_paths" "Long path handling failed"
    fi
}

# Test 15: Line ending handling (CR, LF, CRLF)
test_line_endings() {
    log "Running test: Line ending handling"
    
    local test_payload="$TEST_DIR/lineending_payload"
    mkdir -p "$test_payload"
    
    # Create files with different line endings
    printf "line1\nline2\nline3" > "$test_payload/unix_lf.txt"
    printf "line1\rline2\rline3" > "$test_payload/mac_cr.txt"
    printf "line1\r\nline2\r\nline3" > "$test_payload/windows_crlf.txt"
    
    local test_bag="$TEST_DIR/lineending_bag"
    cp -r "$test_payload" "$test_bag"
    
    if $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1 && \
       $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "line_endings"
    else
        fail_test "line_endings" "Line ending handling failed"
    fi
}

# Test 16: Bag-in-bag (nested bags)
test_nested_bags() {
    log "Running test: Nested bags"
    
    # Create inner bag
    local inner_payload="$TEST_DIR/inner_payload"
    mkdir -p "$inner_payload"
    echo "inner content" > "$inner_payload/inner.txt"
    
    local inner_bag="$TEST_DIR/inner_bag"
    cp -r "$inner_payload" "$inner_bag"
    $PYTHON_BAGIT "$inner_bag" > /dev/null 2>&1
    
    # Create outer bag containing inner bag
    local outer_payload="$TEST_DIR/outer_payload"
    mkdir -p "$outer_payload"
    cp -r "$inner_bag" "$outer_payload/"
    echo "outer content" > "$outer_payload/outer.txt"
    
    local outer_bag="$TEST_DIR/outer_bag"
    cp -r "$outer_payload" "$outer_bag"
    
    if $PYTHON_BAGIT "$outer_bag" > /dev/null 2>&1 && \
       $PYTHON_BAGIT --validate "$outer_bag" > /dev/null 2>&1; then
        pass_test "nested_bags"
    else
        fail_test "nested_bags" "Nested bag handling failed"
    fi
}

# Test 17: Symlinks (should be followed)
test_symlinks() {
    log "Running test: Symlink handling"
    
    local test_payload="$TEST_DIR/symlink_payload"
    mkdir -p "$test_payload/subdir"
    echo "target content" > "$test_payload/target.txt"
    echo "subdir content" > "$test_payload/subdir/file.txt"
    
    # Create symlinks
    ln -s target.txt "$test_payload/link.txt"
    ln -s subdir "$test_payload/linkdir"
    
    local test_bag="$TEST_DIR/symlink_bag"
    cp -r "$test_payload" "$test_bag"
    
    # Note: bagit.py follows symlinks and includes their content
    if $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1; then
        pass_test "symlinks"
    else
        fail_test "symlinks" "Symlink handling failed"
    fi
}

# Test 18: Hidden files
test_hidden_files() {
    log "Running test: Hidden files"
    
    local test_payload="$TEST_DIR/hidden_payload"
    mkdir -p "$test_payload"
    echo "visible" > "$test_payload/visible.txt"
    echo "hidden" > "$test_payload/.hidden.txt"
    mkdir -p "$test_payload/.hidden_dir"
    echo "hidden dir content" > "$test_payload/.hidden_dir/file.txt"
    
    local test_bag="$TEST_DIR/hidden_bag"
    cp -r "$test_payload" "$test_bag"
    
    if $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1 && \
       $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        # Check if hidden files are in manifest
        if grep -q "\.hidden\.txt" "$test_bag/manifest-sha256.txt"; then
            pass_test "hidden_files"
        else
            fail_test "hidden_files" "Hidden files not included in manifest"
        fi
    else
        fail_test "hidden_files" "Hidden file handling failed"
    fi
}

# Test 19: Binary files
test_binary_files() {
    log "Running test: Binary files"
    
    local test_payload="$TEST_DIR/binary_payload"
    mkdir -p "$test_payload"
    
    # Create various binary files
    dd if=/dev/urandom of="$test_payload/random.bin" bs=1024 count=5 2>/dev/null
    # Create a file with null bytes
    printf '\x00\x01\x02\x03\xff\xfe\xfd' > "$test_payload/binary.dat"
    
    local test_bag="$TEST_DIR/binary_bag"
    cp -r "$test_payload" "$test_bag"
    
    if $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1 && \
       $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "binary_files"
    else
        fail_test "binary_files" "Binary file handling failed"
    fi
}

# Test 20: Concurrent bag operations (should fail)
test_concurrent_bagging() {
    log "Running test: Concurrent bagging protection"
    
    local test_payload="$TEST_DIR/concurrent_payload"
    create_test_payload "$test_payload"
    
    local test_bag="$TEST_DIR/concurrent_bag"
    cp -r "$test_payload" "$test_bag"
    
    # Start first bagging process in background
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1 &
    local pid1=$!
    
    # Try to bag the same directory concurrently (should fail or handle gracefully)
    sleep 0.1  # Small delay to ensure first process started
    $PYTHON_BAGIT "$test_bag" > /dev/null 2>&1 &
    local pid2=$!
    
    # Wait for both to complete
    wait $pid1
    local result1=$?
    wait $pid2
    local result2=$?
    
    # At least one should succeed, and the bag should be valid
    if [[ $result1 -eq 0 || $result2 -eq 0 ]] && \
       $PYTHON_BAGIT --validate "$test_bag" > /dev/null 2>&1; then
        pass_test "concurrent_bagging"
    else
        fail_test "concurrent_bagging" "Concurrent bagging handling failed"
    fi
}

# Run additional tests
run_advanced_tests() {
    echo ""
    echo -e "${BLUE}=== Advanced Test Cases ===${NC}"
    echo ""
    
    test_multiprocessing
    test_payload_oxum
    test_unicode_filenames
    test_long_paths
    test_line_endings
    test_nested_bags
    test_symlinks
    test_hidden_files
    test_binary_files
    test_concurrent_bagging
}

# If run directly, execute advanced tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up test environment
    TEST_DIR="test_runs"
    PYTHON_BAGIT="bagit.py"
    TEST_LOG="test_results_advanced.log"
    FAILED_TESTS=()
    PASSED_TESTS=()
    
    mkdir -p "$TEST_DIR"
    
    run_advanced_tests
    
    # Summary
    echo ""
    echo -e "${BLUE}=== Advanced Test Summary ===${NC}"
    echo -e "${GREEN}Passed: ${#PASSED_TESTS[@]}${NC}"
    echo -e "${RED}Failed: ${#FAILED_TESTS[@]}${NC}"
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        echo ""
        echo -e "${RED}Failed tests:${NC}"
        for failure in "${FAILED_TESTS[@]}"; do
            echo "  - $failure"
        done
    fi
fi