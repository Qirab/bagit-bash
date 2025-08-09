#!/bin/bash
#
# bagit.sh - A Bash implementation of the BagIt File Packaging Format
# Version: 1.0.1 (Bash 3.2 Compatible)
# Compliant with BagIt specification v0.97 and bagit.py functionality

# Check minimum bash version (3.2 required)
check_bash_version() {
  if [[ ${BASH_VERSINFO[0]} -lt 3 ]] || [[ ${BASH_VERSINFO[0]} -eq 3 && ${BASH_VERSINFO[1]} -lt 2 ]]; then
    echo "ERROR: This script requires Bash 3.2 or higher. Current version: $BASH_VERSION" >&2
    exit 1
  fi
}

# Perform version check immediately
check_bash_version

# Version information
readonly SCRIPT_VERSION="1.0.1"
readonly BAGIT_VERSION="0.97"
readonly ENCODING="UTF-8"
readonly PROJECT_URL="https://github.com/user/bagit-bash"

# Default values
readonly DEFAULT_ALGORITHMS=("sha256" "sha512")
readonly HASH_BLOCK_SIZE=524288 # 512KB blocks for hashing

# Global variables
ALGORITHMS=()
METADATA=()
PROCESSES=1
LOG_FILE=""
QUIET=false
VALIDATE=false
FAST=false
COMPLETENESS_ONLY=false

# Platform detection
if [[ "$OSTYPE" == "darwin"* ]]; then
  IS_MACOS=true
  STAT_SIZE_FMT="-f%z"
  DATE_CMD="date"
else
  IS_MACOS=false
  STAT_SIZE_FMT="-c%s"
  DATE_CMD="date"
fi

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  if [[ -n "$LOG_FILE" ]]; then
    echo "[$timestamp] $level - $message" >>"$LOG_FILE"
  fi

  if [[ "$QUIET" == "false" || "$level" == "ERROR" ]]; then
    case "$level" in
    ERROR)
      echo -e "${RED}ERROR${NC}: $message" >&2
      ;;
    INFO)
      echo "$message" >&2
      ;;
    *)
      echo "[$level] $message" >&2
      ;;
    esac
  fi
}

error() {
  log "ERROR" "$@"
}

info() {
  log "INFO" "$@"
}

# Print version and exit
print_version() {
  echo "bagit.sh version $SCRIPT_VERSION"
  exit 0
}

# Print usage
usage() {
  cat <<EOF
Usage: $0 [options] directory [directory ...]

BagIt is a directory, filename convention for bundling an arbitrary set of
files with a manifest, checksums, and additional metadata.

Options:
  --version             Show version and exit
  --help                Show this help message
  --processes N         Use N processes for checksum calculation (default: 1)
  --log FILE           Log output to file (default: stdout)
  --quiet              Suppress progress information except errors
  --validate           Validate existing bags instead of creating new ones
  --fast               Fast validation using Payload-Oxum only
  --completeness-only  Check completeness without checksum validation

Checksum algorithms:
  --md5                Generate MD5 manifest
  --sha1               Generate SHA-1 manifest
  --sha224             Generate SHA-224 manifest
  --sha256             Generate SHA-256 manifest (default)
  --sha384             Generate SHA-384 manifest
  --sha512             Generate SHA-512 manifest (default)
  --sha3_224           Generate SHA3-224 manifest
  --sha3_256           Generate SHA3-256 manifest
  --sha3_384           Generate SHA3-384 manifest
  --sha3_512           Generate SHA3-512 manifest
  --blake2b            Generate BLAKE2B manifest
  --blake2s            Generate BLAKE2S manifest
  --shake_128          Generate SHAKE-128 manifest
  --shake_256          Generate SHAKE-256 manifest

Metadata options:
  --source-organization TEXT        Organization creating the bag
  --organization-address TEXT       Physical address
  --contact-name TEXT              Contact person
  --contact-phone TEXT             Phone number
  --contact-email TEXT             Email address
  --external-description TEXT      Description of bag contents
  --external-identifier TEXT       External ID
  --bag-size TEXT                  Human-readable size
  --bag-group-identifier TEXT      Group identifier
  --bag-count TEXT                 Bag count (e.g., "1 of 5")
  --internal-sender-identifier TEXT Internal ID
  --internal-sender-description TEXT Internal description
  --bagit-profile-identifier TEXT  BagIt profile URL

Examples:
  $0 my_directory                  # Create a bag with default checksums
  $0 --md5 --sha1 my_directory     # Create with specific checksums
  $0 --validate my_bag             # Validate an existing bag
  $0 --validate --fast my_bag      # Fast validation using Payload-Oxum

EOF
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Get the appropriate checksum command for an algorithm
get_checksum_command() {
  local alg="$1"

  case "$alg" in
  md5)
    if [[ "$IS_MACOS" == true ]]; then
      echo "md5 -r"
    else
      echo "md5sum"
    fi
    ;;
  sha1)
    if command_exists sha1sum; then
      echo "sha1sum"
    else
      echo "shasum -a 1"
    fi
    ;;
  sha224)
    if command_exists sha224sum; then
      echo "sha224sum"
    else
      echo "shasum -a 224"
    fi
    ;;
  sha256)
    if command_exists sha256sum; then
      echo "sha256sum"
    else
      echo "shasum -a 256"
    fi
    ;;
  sha384)
    if command_exists sha384sum; then
      echo "sha384sum"
    else
      echo "shasum -a 384"
    fi
    ;;
  sha512)
    if command_exists sha512sum; then
      echo "sha512sum"
    else
      echo "shasum -a 512"
    fi
    ;;
  sha3_224)
    echo "openssl dgst -sha3-224"
    ;;
  sha3_256)
    echo "openssl dgst -sha3-256"
    ;;
  sha3_384)
    echo "openssl dgst -sha3-384"
    ;;
  sha3_512)
    echo "openssl dgst -sha3-512"
    ;;
  blake2b)
    if command_exists b2sum; then
      echo "b2sum"
    else
      echo "openssl dgst -blake2b512"
    fi
    ;;
  blake2s)
    if command_exists b2sum; then
      echo "b2sum -a blake2s"
    else
      echo "openssl dgst -blake2s256"
    fi
    ;;
  shake_128)
    echo "openssl dgst -shake128"
    ;;
  shake_256)
    echo "openssl dgst -shake256"
    ;;
  *)
    error "Unknown algorithm: $alg"
    return 1
    ;;
  esac
}

# Calculate checksum of a file
calculate_checksum() {
  local file="$1"
  local alg="$2"
  local cmd=$(get_checksum_command "$alg")

  if [[ -z "$cmd" ]]; then
    return 1
  fi

  # Handle different command output formats
  local output
  if [[ "$cmd" =~ ^openssl ]]; then
    # OpenSSL format: algorithm(file)= checksum
    output=$($cmd "$file" 2>/dev/null | sed 's/^.*= //')
  elif [[ "$cmd" =~ ^md5\ -r ]]; then
    # macOS md5 -r format: checksum file
    output=$($cmd "$file" 2>/dev/null | awk '{print $1}')
  else
    # Standard format: checksum  file
    output=$($cmd "$file" 2>/dev/null | awk '{print $1}')
  fi

  echo "$output"
}

# Encode filename for manifest (handle special characters)
encode_filename() {
  local filename="$1"
  # Replace CR with %0D and LF with %0A
  filename=$(echo "$filename" | sed 's/\r/%0D/g' | sed 's/\n/%0A/g')
  echo "$filename"
}

# Decode filename from manifest
decode_filename() {
  local filename="$1"
  # Replace %0D with CR and %0A with LF
  filename=$(echo "$filename" | sed 's/%0D/\r/g' | sed 's/%0A/\n/g')
  echo "$filename"
}

# Check if path is dangerous (absolute, contains .., or ~)
is_dangerous_path() {
  local path="$1"

  # Check for absolute paths
  if [[ "$path" =~ ^/ ]]; then
    return 0
  fi

  # Check for parent directory references
  if [[ "$path" =~ \.\. ]]; then
    return 0
  fi

  # Check for home directory expansion
  if [[ "$path" =~ ^~ ]]; then
    return 0
  fi

  return 1
}

# Check if we can read and write to all files in a directory
check_permissions() {
  local dir="$1"
  local unreadable=()
  local unwritable=()

  # Check directory itself
  if [[ ! -r "$dir" ]]; then
    unreadable+=("$dir")
  fi
  if [[ ! -w "$dir" ]]; then
    unwritable+=("$dir")
  fi

  # Check all files and subdirectories
  while IFS= read -r file; do
    if [[ ! -r "$file" ]]; then
      unreadable[${#unreadable[@]}]="$file"
    fi
    if [[ ! -w "$file" ]]; then
      unwritable[${#unwritable[@]}]="$file"
    fi
  done < <(find "$dir" -print 2>/dev/null || true)

  if [[ ${#unreadable[@]} -gt 0 ]]; then
    error "The following files/directories are not readable:"
    printf '%s\n' "${unreadable[@]}" >&2
    return 1
  fi

  if [[ ${#unwritable[@]} -gt 0 ]]; then
    error "The following files/directories are not writable:"
    printf '%s\n' "${unwritable[@]}" >&2
    return 1
  fi

  return 0
}

# Generate manifest for a single file
generate_manifest_line() {
  local file="$1"
  local alg="$2"
  local base_dir="$3"

  local checksum=$(calculate_checksum "$file" "$alg")
  if [[ -z "$checksum" ]]; then
    error "Failed to calculate $alg checksum for $file"
    return 1
  fi

  # Get relative path from base directory
  local rel_path="${file#$base_dir/}"

  # Convert to forward slashes for manifest
  if [[ "$OSTYPE" != "darwin"* ]]; then
    rel_path="${rel_path//\//}"
  fi

  # Encode special characters
  rel_path=$(encode_filename "$rel_path")

  echo "$checksum  $rel_path"
}

# Generate manifest files for data directory
generate_manifests() {
  local data_dir="$1"
  local processes="$2"
  shift 2
  local algorithms=($@)

  info "Generating manifest files for algorithms: ${algorithms[*]}" >&2

  # Temporary files for each algorithm
  local temp_files=()
  for alg in "${algorithms[@]}"; do
    temp_files[${#temp_files[@]}]=$(mktemp)
  done

  # Find all files in data directory
  local total_bytes=0
  local file_count=0

  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      ((file_count++))

      # Get file size
      local size=$(stat $STAT_SIZE_FMT "$file" 2>/dev/null || echo 0)
      ((total_bytes += size))

      # Generate checksums for all algorithms
      local i=0
      for alg in "${algorithms[@]}"; do
        if line=$(generate_manifest_line "$file" "$alg" "$(pwd)"); then
          echo "$line" >>"${temp_files[$i]}"
        else
          # Clean up and exit on error
          for temp in "${temp_files[@]}"; do
            rm -f "$temp"
          done
          return 1
        fi
        ((i++))
      done
    fi
  done < <(find "$data_dir" -type f -print 2>/dev/null | sort)

  # Sort and write final manifest files
  local i=0
  for alg in "${algorithms[@]}"; do
    local manifest_file="manifest-${alg}.txt"
    sort "${temp_files[$i]}" >"$manifest_file"
    rm -f "${temp_files[$i]}"
    info "Created $manifest_file" >&2
    ((i++))
  done

  echo "$total_bytes $file_count"
}

# Create bagit.txt file
create_bagit_txt() {
  cat >bagit.txt <<EOF
BagIt-Version: $BAGIT_VERSION
Tag-File-Character-Encoding: $ENCODING
EOF
  info "Created bagit.txt"
}

# Create bag-info.txt file
create_bag_info() {
  local total_bytes="$1"
  local file_count="$2"

  # Set default values
  METADATA[${#METADATA[@]}]="Bagging-Date: $(date +%Y-%m-%d)"
  METADATA[${#METADATA[@]}]="Bag-Software-Agent: bagit.sh v$SCRIPT_VERSION <$PROJECT_URL>"
  METADATA[${#METADATA[@]}]="Payload-Oxum: $total_bytes.$file_count"

  # Sort metadata keys and write to file
  {
    printf '%s\n' "${METADATA[@]}" | sort
  } >bag-info.txt

  info "Created bag-info.txt"
}

# Generate tagmanifest file
generate_tagmanifest() {
  local alg="$1"
  local tagmanifest="tagmanifest-${alg}.txt"

  info "Creating $tagmanifest"

  # Find all tag files (excluding tagmanifest files themselves)
  local tag_files=()
  for file in *.txt; do
    if [[ -f "$file" && ! "$file" =~ ^tagmanifest- ]]; then
      tag_files[${#tag_files[@]}]="$file"
    fi
  done

  # Sort files and generate checksums
  {
    for file in $(printf '%s\n' "${tag_files[@]}" | sort); do
      local checksum=$(calculate_checksum "$file" "$alg")
      if [[ -n "$checksum" ]]; then
        echo "$checksum $file"
      fi
    done
  } >"$tagmanifest"
}

# Create a new bag
create_bag() {
  local bag_dir="$1"

  # Validate directory
  if [[ ! -d "$bag_dir" ]]; then
    error "Directory does not exist: $bag_dir"
    return 1
  fi

  # Check permissions
  if ! check_permissions "$bag_dir"; then
    return 1
  fi

  # Save current directory
  local old_dir=$(pwd)

  # Change to bag directory
  cd "$bag_dir" || {
    error "Cannot change to directory: $bag_dir"
    return 1
  }

  info "Creating bag for directory $(pwd)"

  # Create temporary directory for data
  local temp_dir=$(mktemp -d)
  if [[ -z "$temp_dir" || ! -d "$temp_dir" ]]; then
    error "Failed to create temporary directory"
    cd "$old_dir"
    return 1
  fi

  # Move all existing files to temp directory
  local has_files=false
  for item in * .[!.]* ..?*; do
    if [[ -e "$item" && "$item" != "$(basename "$temp_dir")" ]]; then
      has_files=true
      info "Moving $item to data directory"
      mv "$item" "$temp_dir/" || {
        error "Failed to move $item"
        rm -rf "$temp_dir"
        cd "$old_dir"
        return 1
      }
    fi
  done 2>/dev/null

  # Rename temp directory to data
  mv "$temp_dir" data || {
    error "Failed to create data directory"
    rm -rf "$temp_dir"
    cd "$old_dir"
    return 1
  }

  # Generate manifests
  local oxum_output
  oxum_output=$(generate_manifests "data" "$PROCESSES" "${ALGORITHMS[@]}")
  if [[ $? -ne 0 ]]; then
    error "Failed to generate manifests"
    cd "$old_dir"
    return 1
  fi

  local total_bytes=$(echo "$oxum_output" | cut -d' ' -f1)
  local file_count=$(echo "$oxum_output" | cut -d' ' -f2)

  # Create bagit.txt
  create_bagit_txt

  # Create bag-info.txt
  create_bag_info "$total_bytes" "$file_count"

  # Create tagmanifest files
  for alg in "${ALGORITHMS[@]}"; do
    generate_tagmanifest "$alg"
  done

  cd "$old_dir"
  info "Successfully created bag: $bag_dir"
}

# Load and parse a tag file
load_tag_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  local key=""
  local value=""

  while IFS= read -r line; do
    # Skip empty lines
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
      continue
    fi

    # Check if line starts with whitespace (continuation)
    if [[ "$line" =~ ^[[:space:]] && -n "$key" ]]; then
      # Continuation of previous value
      value+="$line"
    else
      # New key-value pair
      if [[ -n "$key" ]]; then
        # Store previous key-value
        echo "$key=$value"
      fi

      # Parse new key-value
      if [[ "$line" =~ ^([^:]+):(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]# }" # Remove leading space
      else
        error "Invalid tag format in $file: $line"
        return 1
      fi
    fi
  done <"$file"

  # Store last key-value pair
  if [[ -n "$key" ]]; then
    echo "$key=$value"
  fi
}

# Validate bag structure
validate_structure() {
  local bag_dir="$1"

  # Check for required files
  if [[ ! -f "$bag_dir/bagit.txt" ]]; then
    error "Missing required file: bagit.txt"
    return 1
  fi

  if [[ ! -d "$bag_dir/data" ]]; then
    error "Missing required directory: data"
    return 1
  fi

  return 0
}

# Validate bagit.txt
validate_bagit_txt() {
  local bag_dir="$1"
  local bagit_file="$bag_dir/bagit.txt"

  # Check for BOM
  if head -c 3 "$bagit_file" | grep -q $'''\xef\xbb\xbf'''; then
    error "bagit.txt must not contain a byte-order mark"
    return 1
  fi

  # Load tags
  local tags_output
  tags_output=$(load_tag_file "$bagit_file")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local version_found=false
  local encoding_found=false

  while IFS='=' read -r key value; do
    if [[ "$key" == "BagIt-Version" ]]; then
      version_found=true
      if [[ ! "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then
        error "Invalid BagIt version: $value"
        return 1
      fi
    fi
    if [[ "$key" == "Tag-File-Character-Encoding" ]]; then
      encoding_found=true
    fi
  done <<<"$tags_output"

  if [[ "$version_found" == false ]]; then
    error "Missing required tag in bagit.txt: BagIt-Version"
    return 1
  fi
  if [[ "$encoding_found" == false ]]; then
    error "Missing required tag in bagit.txt: Tag-File-Character-Encoding"
    return 1
  fi

  return 0
}

# Validate Payload-Oxum
validate_oxum() {
  local bag_dir="$1"
  local bag_info="$bag_dir/bag-info.txt"

  if [[ ! -f "$bag_info" ]]; then
    info "No bag-info.txt found, skipping Payload-Oxum validation"
    return 0
  fi

  # Load bag-info.txt
  local tags_output
  tags_output=$(load_tag_file "$bag_info")

  local oxum=""
  while IFS='=' read -r key value; do
    if [[ "$key" == "Payload-Oxum" ]]; then
      oxum="$value"
      break
    fi
  done <<<"$tags_output"

  if [[ -z "$oxum" ]]; then
    if [[ "$FAST" == true ]]; then
      error "Fast validation requires Payload-Oxum in bag-info.txt"
      return 1
    fi
    return 0
  fi

  # Parse Payload-Oxum
  if [[ ! "$oxum" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
    error "Malformed Payload-Oxum value: $oxum"
    return 1
  fi

  local expected_bytes="${BASH_REMATCH[1]}"
  local expected_files="${BASH_REMATCH[2]}"

  # Count actual files and bytes
  local actual_bytes=0
  local actual_files=0

  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      ((actual_files++))
      local size=$(stat $STAT_SIZE_FMT "$file" 2>/dev/null || echo 0)
      ((actual_bytes += size))
    fi
  done < <(find "$bag_dir/data" -type f -print 2>/dev/null)

  # Compare
  if [[ "$expected_bytes" -ne "$actual_bytes" || "$expected_files" -ne "$actual_files" ]]; then
    error "Payload-Oxum validation failed. Expected $expected_files files and $expected_bytes bytes but found $actual_files files and $actual_bytes bytes"
    return 1
  fi

  info "Payload-Oxum validation passed"
  return 0
}

# Validate completeness
validate_completeness() {
  local bag_dir="$1"
  local manifest_files_list=$(mktemp)

  # Get all files from manifests
  for manifest in "$bag_dir"/manifest-*.txt; do
    if [[ -f "$manifest" ]]; then
      while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
          continue
        fi

        # Parse manifest line
        if [[ "$line" =~ ^[a-fA-F0-9]+[[:space:]]+(.+)$ ]]; then
          local filepath="${BASH_REMATCH[1]}"
          filepath=$(decode_filename "$filepath")
          echo "$filepath" >>"$manifest_files_list"
        fi
      done <"$manifest"
    fi
  done

  # Check all manifest files exist
  local missing_files=()
  while IFS= read -r filepath; do
    if [[ ! -f "$bag_dir/$filepath" ]]; then
      missing_files[${#missing_files[@]}]="$filepath"
    fi
  done <"$manifest_files_list"

  # Check for extra files
  local extra_files=()
  while IFS= read -r file; do
    local rel_path="${file#$bag_dir/}"
    if ! grep -q -x -F "$rel_path" "$manifest_files_list"; then
      extra_files[${#extra_files[@]}]="$rel_path"
    fi
  done < <(find "$bag_dir/data" -type f -print 2>/dev/null)

  rm -f "$manifest_files_list"

  # Report errors
  local has_errors=false

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    has_errors=true
    error "Missing files from manifest:"
    printf '  %s\n' "${missing_files[@]}" >&2
  fi

  if [[ ${#extra_files[@]} -gt 0 ]]; then
    has_errors=true
    error "Extra files not in manifest:"
    printf '  %s\n' "${extra_files[@]}" >&2
  fi

  if [[ "$has_errors" == true ]]; then
    return 1
  fi

  info "Completeness validation passed"
  return 0
}

# Validate checksums
validate_checksums() {
  local bag_dir="$1"
  local processes="$2"

  local has_errors=false

  # Process each manifest file
  for manifest in "$bag_dir"/manifest-*.txt; do
    if [[ ! -f "$manifest" ]]; then
      continue
    fi

    # Extract algorithm from filename
    local alg=$(basename "$manifest" | sed 's/manifest-\(.*\)\.txt/\1/')
    info "Validating $alg checksums"

    while IFS= read -r line; do
      # Skip empty lines and comments
      if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
      fi

      # Parse manifest line
      if [[ "$line" =~ ^([a-fA-F0-9]+)[[:space:]]+(.+)$ ]]; then
        local expected_checksum="${BASH_REMATCH[1]}"
        local filepath="${BASH_REMATCH[2]}"
        filepath=$(decode_filename "$filepath")

        local full_path="$bag_dir/$filepath"

        if [[ ! -f "$full_path" ]]; then
          error "$filepath: File missing"
          has_errors=true
          continue
        fi

        # Calculate actual checksum
        local actual_checksum=$(calculate_checksum "$full_path" "$alg")

        if [[ "$expected_checksum" != "$actual_checksum" ]]; then
          error "$filepath $alg validation failed: expected=$expected_checksum found=$actual_checksum"
          has_errors=true
        fi
      fi
    done <"$manifest"
  done

  if [[ "$has_errors" == true ]]; then
    return 1
  fi

  info "Checksum validation passed"
  return 0
}

# Validate a bag
validate_bag() {
  local bag_dir="$1"

  info "Validating bag: $bag_dir"

  # Check bag structure
  if ! validate_structure "$bag_dir"; then
    return 1
  fi

  # Validate bagit.txt
  if ! validate_bagit_txt "$bag_dir"; then
    return 1
  fi

  # Validate Payload-Oxum
  if ! validate_oxum "$bag_dir"; then
    return 1
  fi

  # Fast validation stops here
  if [[ "$FAST" == true ]]; then
    info "$bag_dir valid according to Payload-Oxum"
    return 0
  fi

  # Validate completeness
  if ! validate_completeness "$bag_dir"; then
    return 1
  fi

  # Completeness-only validation stops here
  if [[ "$COMPLETENESS_ONLY" == true ]]; then
    info "$bag_dir is complete and valid according to Payload-Oxum"
    return 0
  fi

  # Full validation includes checksums
  if ! validate_checksums "$bag_dir" "$PROCESSES"; then
    return 1
  fi

  info "$bag_dir is valid"
  return 0
}

# Parse command line arguments
parse_args() {
  local directories=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --version)
      print_version
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    --processes)
      shift
      if [[ -z "${1:-}" || ! "$1" =~ ^[0-9]+$ || "$1" -le 0 ]]; then
        error "The number of processes must be greater than 0"
        exit 2
      fi
      PROCESSES="$1"
      ;;
    --log)
      shift
      if [[ -z "${1:-}" ]]; then
        error "--log requires a filename"
        exit 2
      fi
      LOG_FILE="$1"
      ;;
    --quiet)
      QUIET=true
      ;;
    --validate)
      VALIDATE=true
      ;;
    --fast)
      FAST=true
      ;;
    --completeness-only)
      COMPLETENESS_ONLY=true
      ;;
    # Checksum algorithms
    --md5 | --sha1 | --sha224 | --sha256 | --sha384 | --sha512 | --sha3_224 | --sha3_256 | --sha3_384 | --sha3_512 | --blake2b | --blake2s | --shake_128 | --shake_256)
      local alg="${1#--}"
      ALGORITHMS[${#ALGORITHMS[@]}]="$alg"
      ;;
    # Metadata options
    --source-organization | --organization-address | --contact-name | --contact-phone | --contact-email | --external-description | --external-identifier | --bag-size | --bag-group-identifier | --bag-count | --internal-sender-identifier | --internal-sender-description | --bagit-profile-identifier)
      local key="${1#--}"
      # Convert to proper case (e.g., source-organization -> Source-Organization)
      # Use awk for portable case conversion
      key=$(echo "$key" | awk -F'- ' '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1))substr($i,2)}}1' OFS='-')
      shift
      if [[ -z "${1:-}" ]]; then
        error "--$(echo "$key" | tr '[:upper:]' '[:lower:]' | tr '_' '-') requires a value"
        exit 2
      fi
      METADATA[${#METADATA[@]}]="$key: $1"
      ;;
    -*)
      error "Unknown option: $1"
      usage
      exit 2
      ;;
    *)
      directories[${#directories[@]}]="$1"
      ;;
    esac
    shift
  done

  # Validate option combinations
  if [[ "$FAST" == true && "$VALIDATE" == false ]]; then
    error "--fast is only allowed as an option for --validate!"
    exit 2
  fi

  if [[ "$COMPLETENESS_ONLY" == true && "$VALIDATE" == false ]]; then
    error "--completeness-only is only allowed as an option for --validate!"
    exit 2
  fi

  # Check for required directories
  if [[ ${#directories[@]} -eq 0 ]]; then
    error "No directory specified"
    usage
    exit 2
  fi

  # Set default algorithms if none specified
  if [[ ${#ALGORITHMS[@]} -eq 0 ]]; then
    ALGORITHMS=("${DEFAULT_ALGORITHMS[@]}")
  fi

  # Process each directory
  local exit_code=0
  for dir in "${directories[@]}"; do
    if [[ "$VALIDATE" == true ]]; then
      if ! validate_bag "$dir"; then
        exit_code=1
      fi
    else
      if ! create_bag "$dir"; then
        exit_code=1
      fi
    fi
  done

  exit $exit_code
}

# Main entry point
main() {
  # Handle --version as special case
  if [[ "${1:-}" == "--version" ]]; then
    print_version
  fi

  parse_args "$@"
}

# Run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
