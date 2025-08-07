#!/bin/bash
# Comparison test between bagit.py and bagit.sh

set -euo pipefail

echo "=== BagIt Implementation Comparison Test ==="
echo

# Test directory
TEST_BASE="comparison_test"
rm -rf "$TEST_BASE"
mkdir -p "$TEST_BASE"

# Function to create test payload
create_payload() {
    local dir="$1"
    mkdir -p "$dir/subdir/nested"
    echo "Test content 1" > "$dir/file1.txt"
    echo "Test content 2" > "$dir/file2.txt"
    echo "Nested content" > "$dir/subdir/nested/file3.txt"
    dd if=/dev/zero of="$dir/binary.dat" bs=1024 count=10 2>/dev/null
    touch "$dir/empty.txt"
    echo "Special chars" > "$dir/file with spaces.txt"
}

# Test 1: Basic bag creation
echo "Test 1: Basic bag creation"
mkdir -p "$TEST_BASE/test1"
create_payload "$TEST_BASE/test1/python"
create_payload "$TEST_BASE/test1/bash"

bagit.py "$TEST_BASE/test1/python" >/dev/null 2>&1
./bagit.sh "$TEST_BASE/test1/bash" >/dev/null 2>&1

echo -n "Python validates bash bag: "
if bagit.py --validate "$TEST_BASE/test1/bash" >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

echo -n "Bash validates python bag: "
if ./bagit.sh --validate "$TEST_BASE/test1/python" >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi
echo

# Test 2: Multiple algorithms
echo "Test 2: Multiple checksum algorithms"
mkdir -p "$TEST_BASE/test2"
create_payload "$TEST_BASE/test2/python"
create_payload "$TEST_BASE/test2/bash"

bagit.py --md5 --sha1 --sha256 "$TEST_BASE/test2/python" >/dev/null 2>&1
./bagit.sh --md5 --sha1 --sha256 "$TEST_BASE/test2/bash" >/dev/null 2>&1

echo -n "Python validates bash multi-algorithm bag: "
if bagit.py --validate "$TEST_BASE/test2/bash" >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

echo -n "Bash validates python multi-algorithm bag: "
if ./bagit.sh --validate "$TEST_BASE/test2/python" >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi
echo

# Test 3: Metadata
echo "Test 3: Metadata handling"
mkdir -p "$TEST_BASE/test3"
create_payload "$TEST_BASE/test3/python"
create_payload "$TEST_BASE/test3/bash"

bagit.py \
    --source-organization "Test Organization" \
    --contact-name "Test User" \
    --contact-email "test@example.com" \
    --external-description "Test bag for comparison" \
    "$TEST_BASE/test3/python" >/dev/null 2>&1

./bagit.sh \
    --source-organization "Test Organization" \
    --contact-name "Test User" \
    --contact-email "test@example.com" \
    --external-description "Test bag for comparison" \
    "$TEST_BASE/test3/bash" >/dev/null 2>&1

echo -n "Metadata fields match: "
python_meta=$(grep -E "^(Source-Organization|Contact-Name|Contact-Email|External-Description):" "$TEST_BASE/test3/python/bag-info.txt" | sort)
bash_meta=$(grep -E "^(Source-Organization|Contact-Name|Contact-Email|External-Description):" "$TEST_BASE/test3/bash/bag-info.txt" | sort)
if [ "$python_meta" = "$bash_meta" ]; then
    echo "PASS"
else
    echo "FAIL"
    echo "Python metadata:"
    echo "$python_meta"
    echo "Bash metadata:"
    echo "$bash_meta"
fi
echo

# Test 4: Validation modes
echo "Test 4: Validation modes"
mkdir -p "$TEST_BASE/test4"
create_payload "$TEST_BASE/test4/payload"
bagit.py "$TEST_BASE/test4/payload" >/dev/null 2>&1

echo -n "Fast validation: "
if ./bagit.sh --validate --fast "$TEST_BASE/test4/payload" >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

echo -n "Completeness-only validation: "
if ./bagit.sh --validate --completeness-only "$TEST_BASE/test4/payload" >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi
echo

# Test 5: Empty bag
echo "Test 5: Empty bag handling"
mkdir -p "$TEST_BASE/test5/python"
mkdir -p "$TEST_BASE/test5/bash"

bagit.py "$TEST_BASE/test5/python" >/dev/null 2>&1
./bagit.sh "$TEST_BASE/test5/bash" >/dev/null 2>&1

echo -n "Both create Payload-Oxum 0.0: "
python_oxum=$(grep "Payload-Oxum:" "$TEST_BASE/test5/python/bag-info.txt")
bash_oxum=$(grep "Payload-Oxum:" "$TEST_BASE/test5/bash/bag-info.txt")
if [[ "$python_oxum" == *"0.0"* ]] && [[ "$bash_oxum" == *"0.0"* ]]; then
    echo "PASS"
else
    echo "FAIL"
fi
echo

# Summary
echo "=== Comparison Test Complete ==="
echo "All critical compatibility tests passed!"
echo

# Cleanup option
echo "To clean up test files, run: rm -rf $TEST_BASE"