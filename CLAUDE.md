# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is bagit-bash, a **completed** Bash shell implementation of the BagIt specification (RFC 8493). The project has achieved full feature parity with the Python bagit.py reference implementation and is production-ready.

**Project Status: COMPLETE** ✅
- Feature-perfect bagit.sh implementation
- Comprehensive testing framework with 25+ test cases
- Complete documentation and validation reports
- Cross-platform compatibility (macOS/Linux)
- All BagIt v0.97 specification requirements met

## Project Structure

```
bagit-bash/
├── bagit.sh                    # Main implementation (production-ready)
├── README.md                   # User documentation
├── CLAUDE.md                   # This file
├── LICENSE                     # CC0 license
├── reference/                  # Reference materials
│   ├── bagit.py               # Python reference implementation  
│   └── bagit-rfc-8493-spec.txt # BagIt RFC 8493 specification
├── reports/                    # Analysis and implementation reports
│   ├── BAGIT_ANALYSIS_REPORT.md
│   ├── IMPLEMENTATION_GUIDE.md
│   ├── IMPLEMENTATION_NOTES.md
│   └── VALIDATION_REPORT.md
└── testing/                    # Comprehensive test framework
    ├── README.md              # Testing documentation
    ├── run_all_tests.sh       # Test runner script
    ├── test_framework.sh      # Core functionality tests
    ├── test_cases.sh          # Advanced edge case tests
    ├── comparison_test.sh     # Cross-validation tests
    └── error_test.sh          # Error handling tests
```

## Implementation Features

The bagit.sh implementation includes:

### ✅ **Complete BagIt v0.97 Compliance**
- All required and optional bag elements
- Proper bag structure with data/ directory  
- Correct file formats and UTF-8 encoding

### ✅ **All Checksum Algorithms (14 total)**
- MD5, SHA-1, SHA-224, SHA-256, SHA-384, SHA-512
- SHA3-224, SHA3-256, SHA3-384, SHA3-512  
- BLAKE2B, BLAKE2S, SHAKE-128, SHAKE-256

### ✅ **All Validation Modes**
- Normal: Full checksum verification
- Fast: Payload-Oxum validation only
- Completeness-only: File presence without checksums

### ✅ **All Metadata Fields**
- 13 standard BagIt metadata fields supported
- Proper capitalization and formatting
- Automatic Payload-Oxum generation

### ✅ **Cross-Platform Support**
- macOS and Linux compatibility
- Automatic platform detection
- Portable checksum commands

## Command Reference

```bash
# Basic usage
./bagit.sh [options] <directory>

# Common operations
./bagit.sh my_directory                    # Create bag with defaults (SHA-256, SHA-512)
./bagit.sh --validate my_bag               # Validate existing bag
./bagit.sh --validate --fast my_bag        # Fast validation
./bagit.sh --md5 --sha1 my_directory       # Specific algorithms
./bagit.sh --source-organization "My Org" --contact-email "me@example.com" my_directory

# All options available - see ./bagit.sh --help for full list
```

## Development Commands

```bash
# Run the implementation
./bagit.sh --version
./bagit.sh --help

# Run tests
cd testing
./run_all_tests.sh                        # All test suites
./test_framework.sh                       # Core functionality tests
./test_cases.sh                          # Advanced edge cases
./comparison_test.sh                      # Cross-validation with Python
./error_test.sh                          # Error handling

# Lint the code (if shellcheck available)
shellcheck bagit.sh

# Validate against Python implementation
./testing/comparison_test.sh
```

## Requirements

- **Bash 4.0+** (required for associative arrays)
- Standard Unix tools (find, sort, stat, awk, etc.)
- Checksum utilities (md5sum/md5, shasum, openssl)
- Python bagit.py (optional, for cross-validation testing)

## Testing Framework

The project includes a comprehensive testing suite:

### Test Coverage
- **25+ test cases** covering all functionality
- **Cross-validation** with Python bagit.py  
- **Error condition testing** for robustness
- **Edge case handling** (Unicode, binary files, etc.)
- **Performance testing** with various scenarios

### Running Tests
```bash
cd testing
./run_all_tests.sh    # Run all test suites with summary

# Individual test suites:
./test_framework.sh   # 15 core functionality tests
./test_cases.sh       # 10 advanced edge case tests  
./comparison_test.sh  # Cross-validation with Python
./error_test.sh       # Error handling validation
```

## Key Implementation Notes

### Security Considerations
- Path validation prevents directory traversal attacks
- Dangerous paths (absolute, .., ~) are rejected
- Input sanitization for metadata values
- Safe handling of special characters in filenames

### Performance Features  
- Efficient checksum calculation using system tools
- Atomic file operations where possible
- Sorted output for deterministic results
- Cross-platform checksum command detection

### Compatibility
- **Bash Version**: Requires Bash 4.0+ (associative arrays)
- **Platforms**: macOS (with Homebrew Bash) and Linux
- **Python Compatibility**: 100% compatible with bagit.py output
- **BagIt Specification**: Full RFC 8493 v0.97 compliance

## Maintenance and Development

This project is **feature-complete** and production-ready. Future development might include:

- Performance optimizations for very large bags
- Additional checksum algorithms as they become standardized  
- Enhanced error reporting and diagnostics
- Windows compatibility (via WSL or Git Bash)

For any modifications, ensure:
1. All tests continue to pass (`./testing/run_all_tests.sh`)
2. Cross-validation with Python implementation succeeds
3. BagIt specification compliance is maintained
4. Documentation is updated accordingly