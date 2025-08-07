#!/bin/bash
# Error handling test for bagit.sh

echo "=== BagIt Error Handling Test ==="
echo

# Test 1: Non-existent directory
echo "Test 1: Non-existent directory"
if ! ./bagit.sh /non/existent/directory 2>&1 | grep -q "Directory does not exist"; then
    echo "FAIL: Should error on non-existent directory"
else
    echo "PASS: Correctly errors on non-existent directory"
fi
echo

# Test 2: Invalid number of processes
echo "Test 2: Invalid number of processes"
if ! ./bagit.sh --processes 0 . 2>&1 | grep -q "must be greater than 0"; then
    echo "FAIL: Should error on invalid process count"
else
    echo "PASS: Correctly errors on invalid process count"
fi
echo

# Test 3: Missing metadata value
echo "Test 3: Missing metadata value"
if ! ./bagit.sh --contact-name 2>&1 | grep -q "requires a value"; then
    echo "FAIL: Should error on missing metadata value"
else
    echo "PASS: Correctly errors on missing metadata value"
fi
echo

# Test 4: Invalid option combination
echo "Test 4: Invalid option combination"
if ! ./bagit.sh --fast . 2>&1 | grep -q "only allowed as an option for --validate"; then
    echo "FAIL: Should error on --fast without --validate"
else
    echo "PASS: Correctly errors on invalid option combination"
fi
echo

# Test 5: Corrupted bag validation
echo "Test 5: Corrupted bag validation"
TEST_DIR="error_test_bag"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
echo "test" > "$TEST_DIR/test.txt"
./bagit.sh "$TEST_DIR" >/dev/null 2>&1

# Corrupt a file
echo "corrupted" > "$TEST_DIR/data/test.txt"

if ! ./bagit.sh --validate "$TEST_DIR" 2>&1 | grep -q "validation failed"; then
    echo "FAIL: Should detect corrupted file"
else
    echo "PASS: Correctly detects corrupted file"
fi
rm -rf "$TEST_DIR"
echo

# Test 6: Missing manifest validation
echo "Test 6: Missing manifest validation"
TEST_DIR="error_test_missing"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
echo "test" > "$TEST_DIR/test.txt"
./bagit.sh "$TEST_DIR" >/dev/null 2>&1

# Remove a file
rm "$TEST_DIR/data/test.txt"

if ! ./bagit.sh --validate "$TEST_DIR" 2>&1 | grep -qE "(File missing|Payload-Oxum validation failed)"; then
    echo "FAIL: Should detect missing file"
else
    echo "PASS: Correctly detects missing file"
fi
rm -rf "$TEST_DIR"
echo

echo "=== Error Handling Test Complete ==="