# Testing Framework for bagit-bash

This directory contains the comprehensive testing framework for the bagit-bash implementation, ensuring it maintains feature parity with the Python bagit.py reference implementation.

## Test Files Overview

### Core Testing Framework

#### `test_framework.sh`
The primary test suite containing 15 core functionality tests:

**Basic Operations:**
- `test_basic_bag_creation` - Creates a simple bag with default settings
- `test_bag_validation` - Validates a correctly created bag
- `test_empty_bag` - Tests handling of empty directories

**Checksum Algorithm Tests:**
- `test_md5_algorithm` - MD5 checksum generation and validation
- `test_sha1_algorithm` - SHA-1 checksum generation and validation
- `test_sha256_algorithm` - SHA-256 checksum generation and validation
- `test_sha512_algorithm` - SHA-512 checksum generation and validation
- `test_multiple_checksums` - Multiple algorithms in one bag

**Metadata Tests:**
- `test_metadata_fields` - All standard BagIt metadata fields
- `test_special_characters` - Handling of special characters in metadata

**Validation Modes:**
- `test_fast_validation` - Payload-Oxum only validation
- `test_completeness_validation` - File presence without checksum verification

**Error Detection:**
- `test_corrupted_file_detection` - Detects modified files
- `test_missing_file_detection` - Detects missing payload files
- `test_extra_file_detection` - Detects unexpected files in bag

#### `test_cases.sh`
Advanced edge case testing with 10 additional tests:

**Performance & Concurrency:**
- `test_multiprocessing` - Tests --processes option
- `test_concurrent_operations` - Multiple simultaneous operations

**File Type Handling:**
- `test_unicode_filenames` - Non-ASCII characters in filenames
- `test_binary_files` - Binary file handling
- `test_symlinks` - Symbolic link handling
- `test_hidden_files` - Dot files and hidden directories

**Path & Structure Tests:**
- `test_long_paths` - Very long file paths
- `test_nested_directories` - Deep directory structures
- `test_line_endings` - Different line ending formats

**Complex Scenarios:**
- `test_nested_bags` - Bags within bags

### Cross-Validation Testing

#### `comparison_test.sh`
Ensures identical behavior between Python bagit.py and Bash bagit.sh:

**Cross-Implementation Tests:**
- Creates bags with Python, validates with Bash
- Creates bags with Bash, validates with Python
- Compares output formats and metadata generation
- Verifies identical error handling

#### `error_test.sh`
Comprehensive error condition testing:

**Error Scenarios:**
- Invalid directory paths
- Permission denied scenarios
- Corrupted manifest files
- Invalid metadata formats
- Missing required files

## Running Tests

### Prerequisites
- Bash 4.0 or later
- Python bagit.py installed (for cross-validation)
- Standard Unix tools (find, sort, awk, etc.)

### Individual Test Suites

```bash
# Run core functionality tests
cd testing
./test_framework.sh

# Run advanced edge case tests  
./test_cases.sh

# Run cross-validation tests
./comparison_test.sh

# Run error handling tests
./error_test.sh
```

### Run All Tests
```bash
# From the testing directory
for test in test_framework.sh test_cases.sh comparison_test.sh error_test.sh; do
    echo "Running $test..."
    ./"$test"
done
```

## Test Structure

Each test script follows this structure:

### Test Function Pattern
```bash
test_function_name() {
    local test_name="Descriptive Test Name"
    local test_dir="test_${RANDOM}"
    
    # Setup
    mkdir -p "$test_dir/payload"
    echo "test content" > "$test_dir/payload/file.txt"
    
    # Execute test
    ../bagit.sh [options] "$test_dir"
    
    # Validate results
    if [[ expected_condition ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "reason"
    fi
    
    # Cleanup
    rm -rf "$test_dir"
}
```

### Test Utilities
- `pass_test()` - Mark test as passed
- `fail_test()` - Mark test as failed with reason
- `run_tests()` - Execute all test functions
- `setup_test_env()` - Prepare test environment
- `cleanup_test_env()` - Clean up after tests

## Expected Behavior

### Success Criteria
- All tests should pass (exit code 0)
- No differences between Python and Bash implementations
- Proper error messages for failure conditions
- Correct file formats and metadata generation

### Test Output Format
```
Running Test Suite: Core Functionality Tests
✓ Basic bag creation
✓ Bag validation  
✓ Empty bag handling
...

Results: 15/15 tests passed
```

## Test Data

Tests create temporary directories with various structures:
- Simple files with text content
- Binary files (images, archives)
- Unicode filenames
- Nested directory structures
- Special characters in paths and content

## Validation Reports

Test results are logged to:
- `test_results.log` - Detailed execution log
- Console output - Summary and failures
- Individual test artifacts in temp directories (cleaned automatically)

## Adding New Tests

To add a new test:

1. Create test function following the naming pattern `test_*`
2. Add function name to the `TESTS` array
3. Follow the standard test structure
4. Include both success and failure cases
5. Update this documentation

### Example New Test
```bash
test_new_feature() {
    local test_name="New Feature Test"
    local test_dir="test_${RANDOM}"
    
    mkdir -p "$test_dir"
    echo "content" > "$test_dir/file.txt"
    
    if ../bagit.sh --new-option "$test_dir"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "New feature failed"
    fi
    
    rm -rf "$test_dir"
}

# Add to TESTS array
TESTS=(
    # ... existing tests ...
    test_new_feature
)
```

## Troubleshooting

### Common Issues
- **Permission errors**: Ensure test directory is writable
- **Missing dependencies**: Install required tools (Python bagit, OpenSSL, etc.)
- **Bash version**: Requires Bash 4.0+ for associative arrays
- **Path issues**: Run tests from the testing directory

### Debug Mode
Set `DEBUG=1` environment variable for verbose output:
```bash
DEBUG=1 ./test_framework.sh
```

## Test Coverage

The testing framework provides comprehensive coverage of:
- ✅ All BagIt specification requirements
- ✅ All command-line options and flags
- ✅ All supported checksum algorithms
- ✅ All metadata fields and formats
- ✅ Error conditions and edge cases
- ✅ Cross-platform compatibility
- ✅ Performance scenarios
- ✅ Security considerations (path validation)

This ensures the Bash implementation maintains 100% compatibility with the Python reference implementation.