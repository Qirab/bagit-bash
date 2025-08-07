# BagIt Python Implementation Analysis Report

## Executive Summary

This report provides a comprehensive analysis of the bagit.py reference implementation (v1.9.0) to guide the development of a feature-perfect Bash implementation (bagit.sh). The analysis includes all functionality, command-line options, behaviors, edge cases, and a complete testing framework.

## 1. Core Functionality Analysis

### 1.1 Bag Creation

The `make_bag()` function performs the following operations:

1. **Directory Structure Transformation**:
   - Creates a temporary directory within the target
   - Moves all existing files to the temporary directory
   - Renames the temporary directory to "data/"
   - Preserves original directory permissions on data/

2. **Manifest Generation**:
   - Default algorithms: SHA-256 and SHA-512
   - Supports 14 hash algorithms total
   - Creates manifest-{algorithm}.txt files
   - Format: `{checksum}  {filepath}` (two spaces as separator)

3. **Required Files Created**:
   - `bagit.txt` - Bag declaration
   - `bag-info.txt` - Metadata file
   - `manifest-{algorithm}.txt` - One or more payload manifests
   - `tagmanifest-{algorithm}.txt` - Tag file manifests

### 1.2 Bag Validation

Three validation modes are supported:

1. **Normal Validation** (`--validate`):
   - Verifies bag structure
   - Checks all file checksums
   - Validates completeness
   - Verifies tag manifests

2. **Fast Validation** (`--validate --fast`):
   - Uses Payload-Oxum only
   - Checks file count and total size
   - Does not verify checksums

3. **Completeness-Only** (`--validate --completeness-only`):
   - Verifies all files are present
   - Checks Payload-Oxum
   - Does not verify checksums

## 2. Command-Line Interface

### 2.1 Basic Usage
```bash
bagit.py [options] directory [directory ...]
```

### 2.2 Options

#### General Options:
- `--processes N`: Use N processes for checksum calculation (default: 1)
- `--log FILE`: Log output to file (default: stdout)
- `--quiet`: Suppress progress information except errors
- `--validate`: Validate instead of create
- `--fast`: Fast validation using Payload-Oxum only
- `--completeness-only`: Check completeness without checksum validation

#### Checksum Algorithms (14 total):
- `--md5`: Generate MD5 manifest
- `--sha1`: Generate SHA-1 manifest
- `--sha224`: Generate SHA-224 manifest
- `--sha256`: Generate SHA-256 manifest (default)
- `--sha384`: Generate SHA-384 manifest
- `--sha512`: Generate SHA-512 manifest (default)
- `--sha3_224`: Generate SHA3-224 manifest
- `--sha3_256`: Generate SHA3-256 manifest
- `--sha3_384`: Generate SHA3-384 manifest
- `--sha3_512`: Generate SHA3-512 manifest
- `--blake2b`: Generate BLAKE2B manifest
- `--blake2s`: Generate BLAKE2S manifest
- `--shake_128`: Generate SHAKE-128 manifest
- `--shake_256`: Generate SHAKE-256 manifest

#### Metadata Options (all optional):
- `--source-organization`: Organization creating the bag
- `--organization-address`: Physical address
- `--contact-name`: Contact person
- `--contact-phone`: Phone number
- `--contact-email`: Email address
- `--external-description`: Description of bag contents
- `--external-identifier`: External ID
- `--bag-size`: Human-readable size
- `--bag-group-identifier`: Group identifier
- `--bag-count`: Bag count (e.g., "1 of 5")
- `--internal-sender-identifier`: Internal ID
- `--internal-sender-description`: Internal description
- `--bagit-profile-identifier`: BagIt profile URL

## 3. File Formats and Standards

### 3.1 bagit.txt
```
BagIt-Version: 0.97
Tag-File-Character-Encoding: UTF-8
```
- Must be exactly 2 lines
- No BOM allowed
- Always UTF-8 encoded

### 3.2 bag-info.txt
- Key-value pairs: `Label: Value`
- Auto-generated fields:
  - `Bagging-Date`: YYYY-MM-DD format
  - `Bag-Software-Agent`: bagit.py version and URL
  - `Payload-Oxum`: {total_bytes}.{file_count}
- Sorted alphabetically by key
- Values stripped of CR/LF characters

### 3.3 manifest-{algorithm}.txt
- Format: `{checksum}  {filepath}`
- Two spaces between checksum and filepath
- Forward slashes for all paths
- Files sorted alphabetically
- Special character encoding:
  - `%0D` for CR
  - `%0A` for LF
  - `%` for percent sign

### 3.4 tagmanifest-{algorithm}.txt
- Same format as payload manifests
- Includes all tag files except other tagmanifests
- Must include all payload manifests

## 4. Critical Behaviors and Edge Cases

### 4.1 File Handling
- **Symlinks**: Followed and content included
- **Hidden files**: Included in bag
- **Binary files**: Handled as opaque byte streams
- **Empty directories**: Not preserved (use .keep files)
- **Unicode filenames**: Normalized to NFC form

### 4.2 Path Handling
- All paths use forward slashes in manifests
- Relative paths from bag root
- No path length limitations
- Dangerous paths rejected (absolute, .., ~)

### 4.3 Error Conditions
- **Corrupted files**: Checksum mismatch error
- **Missing files**: Completeness validation failure
- **Extra files**: Completeness validation failure
- **No manifest files**: Structure validation failure
- **Empty bag**: No manifest files created (validation fails)

### 4.4 Special Cases
- **Empty payload**: Payload-Oxum = "0.0"
- **Concurrent bagging**: Not protected (undefined behavior)
- **Bag-in-bag**: Allowed (inner bag treated as payload)
- **Large files**: No size limits
- **Many files**: Performance scales with --processes option

## 5. Testing Framework

### 5.1 Test Framework Structure

Two test scripts have been created:

1. **test_framework.sh**: Core functionality tests
   - Basic bag creation
   - Checksum algorithms
   - Metadata handling
   - Validation modes
   - Error detection

2. **test_cases.sh**: Advanced test scenarios
   - Multiprocessing
   - Unicode handling
   - Binary files
   - Symlinks
   - Edge cases

### 5.2 Test Execution

```bash
# Run basic tests
./test_framework.sh

# Run advanced tests
./test_cases.sh

# Clean up test files
./test_framework.sh clean
```

### 5.3 Test Coverage

The test suite covers:
- All command-line options
- All checksum algorithms
- All validation modes
- All metadata fields
- Error conditions
- Edge cases
- Performance testing

## 6. Implementation Requirements for bagit.sh

### 6.1 Must-Have Features
1. All 14 checksum algorithms (using system tools)
2. All three validation modes
3. Multiprocessing support
4. All metadata fields
5. Proper manifest formatting
6. Error handling and reporting

### 6.2 Behavioral Compatibility
1. Identical directory structure
2. Same manifest file formats
3. Matching checksum calculations
4. Compatible path handling
5. Same validation logic

### 6.3 Tool Dependencies
- Standard POSIX utilities
- Checksum tools: md5sum, sha1sum, sha256sum, etc.
- GNU coreutils preferred for consistency

## 7. Validation Checklist

Before considering bagit.sh complete, ensure:

- [ ] All tests in test_framework.sh pass
- [ ] All tests in test_cases.sh pass
- [ ] Output bags validate with bagit.py
- [ ] bagit.py bags validate with bagit.sh
- [ ] Performance is acceptable for large bags
- [ ] Error messages are clear and helpful
- [ ] Help text matches functionality

## 8. Known Issues and Limitations

1. **Empty bags**: Cannot create valid empty bags (no files = no manifests)
2. **Deprecation warnings**: Python regex warnings in current version
3. **Platform differences**: Path separators, checksum tool names
4. **Concurrent operations**: Not thread-safe

## 9. Recommendations

1. **Start with core features**: Basic bag creation and validation
2. **Implement incrementally**: Add algorithms and options gradually
3. **Test continuously**: Run test suite after each feature
4. **Match output exactly**: Use bagit.py output as reference
5. **Document differences**: Note any intentional deviations

## Conclusion

This analysis provides a complete understanding of bagit.py's functionality and behavior. The included test framework enables systematic verification of the Bash implementation. Following this guide will ensure bagit.sh achieves feature parity with the Python reference implementation.