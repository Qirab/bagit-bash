# BagIt Bash Implementation Quick Reference

## Command-Line Argument Parsing Order

1. Check for `--version` (print version and exit)
2. Parse options in any order
3. Validate option combinations
4. Process directory arguments

## Bag Creation Workflow

```bash
1. Validate directory exists and is readable/writable
2. Change to bag directory
3. Create temp directory (mktemp -d)
4. Move all files to temp directory
5. Rename temp to "data/"
6. Generate manifests for requested algorithms
7. Create bagit.txt
8. Create bag-info.txt with metadata
9. Create tagmanifest files
```

## Checksum Calculation

### Hash Command Mapping
```bash
md5:       md5sum (Linux) or md5 -r (macOS)
sha1:      sha1sum or shasum -a 1
sha224:    sha224sum or shasum -a 224
sha256:    sha256sum or shasum -a 256
sha384:    sha384sum or shasum -a 384
sha512:    sha512sum or shasum -a 512
sha3_224:  openssl dgst -sha3-224
sha3_256:  openssl dgst -sha3-256
sha3_384:  openssl dgst -sha3-384
sha3_512:  openssl dgst -sha3-512
blake2b:   b2sum or openssl dgst -blake2b512
blake2s:   b2sum -a blake2s or openssl dgst -blake2s256
shake_128: openssl dgst -shake128
shake_256: openssl dgst -shake256
```

## Manifest Format

```
{checksum}  {filepath}
```
- Exactly two spaces between checksum and filepath
- Forward slashes for all paths
- Sorted alphabetically by filepath
- Special encoding: %0D (CR), %0A (LF), % (percent)

## Payload-Oxum Calculation

```bash
# Count bytes
total_bytes=$(find data -type f -exec stat -f%z {} + | awk '{sum+=$1} END {print sum}')
# or on Linux:
total_bytes=$(find data -type f -exec stat -c%s {} + | awk '{sum+=$1} END {print sum}')

# Count files
file_count=$(find data -type f | wc -l)

# Format
echo "Payload-Oxum: ${total_bytes}.${file_count}"
```

## Validation Logic

### Normal Validation
1. Check bagit.txt exists and is valid
2. Check data/ directory exists
3. Check at least one manifest exists
4. For each file in manifests:
   - Verify file exists
   - Calculate checksum
   - Compare with manifest
5. Check for extra files not in manifests
6. Verify tag manifests if present

### Fast Validation
1. Check bagit.txt exists and is valid
2. Read Payload-Oxum from bag-info.txt
3. Count actual files and bytes in data/
4. Compare with Payload-Oxum values

### Completeness-Only
1. Check all required files exist
2. Verify Payload-Oxum
3. Check all manifest files are present
4. Don't calculate checksums

## Error Exit Codes

- 0: Success
- 1: General error (invalid bag, validation failure)
- 2: Usage error (invalid options)
- 3: File/directory not found
- 4: Permission denied
- 5: Checksum tool not available

## Platform Detection

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific code
    MD5_CMD="md5 -r"
    STAT_FMT="-f%z"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux specific code
    MD5_CMD="md5sum"
    STAT_FMT="-c%s"
fi
```

## Key Variables

```bash
# Defaults
DEFAULT_ALGORITHMS=("sha256" "sha512")
BAGIT_VERSION="0.97"
ENCODING="UTF-8"

# Generated values
BAGGING_DATE=$(date +%Y-%m-%d)
BAG_SOFTWARE_AGENT="bagit.sh v1.0.0 <https://github.com/user/bagit-bash>"
```

## Testing Your Implementation

```bash
# Quick test
mkdir test_bag && echo "test" > test_bag/file.txt
./bagit.sh test_bag
./bagit.sh --validate test_bag

# Run full test suite
./test_framework.sh

# Compare with Python
bagit.py ref_bag
./bagit.sh test_bag
diff -r ref_bag test_bag
```