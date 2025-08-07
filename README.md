# BagIT Bash
bagit-bash is a bash shell implementation of BagIT

The goal of this project is to create full a BagIT spec implementation in the Bash shell. The BagIT spec is defined by RFC 8493 and this project hopes to have feature parity with the python implementation of BagIT.

## Requirements

**Bash 4.0 or later** is required for this implementation.

### Checking Your Bash Version
```bash
bash --version
```

### Upgrading Bash (if needed)
- **macOS**: `brew install bash` (installs Bash 5.x)
- **Ubuntu/Debian**: Usually has Bash 4+ by default
- **CentOS/RHEL**: May need `yum update bash` for older versions

**Note**: macOS ships with Bash 3.2 by default. You'll need to install a newer version via Homebrew or MacPorts to use bagit-bash.

## Features

*   Create BagIt bags from a directory.
*   Validate existing BagIt bags.
*   Support for a wide range of checksum algorithms including MD5, SHA-1, SHA-256, SHA-512, SHAKE-128, SHAKE-256, SHA3-224, SHA3-256, SHA3-384, SHA3-512, BLAKE2b, BLAKE2s, SHA-224, and SHA-384.
*   Fast validation mode to only check the payload-oxum.
*   Completeness-only validation mode to check payload completeness without checksum validation.
*   Parallel checksum calculation for faster processing.
*   Support for adding various optional BagIt metadata fields.

# Usage

```bash
./bagit.sh [options] <directory>
```

## Options

*   `-h`, `--help`: Show the help message.
*   `--processes PROCESSES`: Use multiple processes to calculate checksums faster (default: 1).
*   `--log LOG`: The name of the log file (default: stdout).
*   `--quiet`: Suppress all progress information other than errors.
*   `--validate`: Validate existing bags in the provided directories instead of creating new ones.
*   `--fast`: Modify `--validate` behaviour to only test whether the bag directory has the number of files and total size specified in Payload-Oxum without performing checksum validation to detect corruption.
*   `--completeness-only`: Modify `--validate` behaviour to test whether the bag directory has the expected payload specified in the checksum manifests without performing checksum validation to detect corruption.

### Checksum Algorithms
Select the manifest algorithms to be used when creating bags (default=sha256).

*   `--shake_256`: Generate SHAKE_256 manifest when creating a bag.
*   `--sha256`: Generate SHA-256 manifest when creating a bag.
*   `--sha3_512`: Generate SHA3_512 manifest when creating a bag.
*   `--sha1`: Generate SHA-1 manifest when creating a bag.
*   `--shake_128`: Generate SHAKE_128 manifest when creating a bag.
*   `--sha3_224`: Generate SHA3_224 manifest when creating a bag.
*   `--sha3_384`: Generate SHA3_384 manifest when creating a bag.
*   `--blake2s`: Generate BLAKE2S manifest when creating a bag.
*   `--sha3_256`: Generate SHA3_256 manifest when creating a bag.
*   `--sha512`: Generate SHA-512 manifest when creating a bag.
*   `--md5`: Generate MD-5 manifest when creating a bag.
*   `--blake2b`: Generate BLAKE2B manifest when creating a bag.
*   `--sha384`: Generate SHA-384 manifest when creating a bag.
*   `--sha224`: Generate SHA-224 manifest when creating a bag.

### Optional Bag Metadata
*   `--source-organization SOURCE_ORGANIZATION`
*   `--organization-address ORGANIZATION_ADDRESS`
*   `--contact-name CONTACT_NAME`
*   `--contact-phone CONTACT_PHONE`
*   `--contact-email CONTACT_EMAIL`
*   `--external-description EXTERNAL_DESCRIPTION`
*   `--external-identifier EXTERNAL_IDENTIFIER`
*   `--bag-size BAG_SIZE`
*   `--bag-group-identifier BAG_GROUP_IDENTIFIER`
*   `--bag-count BAG_COUNT`
*   `--internal-sender-identifier INTERNAL_SENDER_IDENTIFIER`
*   `--internal-sender-description INTERNAL_SENDER_DESCRIPTION`
*   `--bagit-profile-identifier BAGIT_PROFILE_IDENTIFIER`

## Testing

A comprehensive testing framework is available in the `testing/` directory:

```bash
# Run all test suites
cd testing
./run_all_tests.sh

# Run individual test suites
./test_framework.sh      # Core functionality tests
./test_cases.sh          # Advanced edge cases  
./comparison_test.sh     # Cross-validation with Python bagit.py
./error_test.sh          # Error handling tests
```

See `testing/README.md` for detailed testing documentation.

## License

bagit-bash is released under the Creative Commons Zero v1.0 Universal license.
https://github.com/Qirab/bagit-bash

bagit-bash is based on the Library of Congress bagit-python version which is in the Public Domain. 
https://github.com/LibraryOfCongress/bagit-python



