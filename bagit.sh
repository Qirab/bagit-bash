#!/usr/bin/env bash
#
# bagit.sh - A Bash implementation of the BagIt File Packaging Format
# Version: 1.2.0 (Bash 4.0+ Required)
# Compliant with BagIt specification v0.97 and bagit.py functionality

# Check minimum bash version (4.0 required for associative arrays)
check_bash_version() {
  if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "ERROR: This script requires Bash 4.0 or higher for associative array support. Current version: $BASH_VERSION" >&2
    exit 1
  fi
}

# Perform version check immediately
check_bash_version

# Version information
readonly SCRIPT_VERSION="1.2.0"
readonly BAGIT_VERSION="0.97"
readonly ENCODING="UTF-8"
readonly PROJECT_URL="https://github.com/Qirab/bagit-bash"

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

# Associative arrays for performance optimization
declare -A ALGORITHMS_MAP # Track which algorithms are enabled
declare -A METADATA_MAP   # Store metadata key-value pairs
declare -A CHECKSUM_CMDS  # Cache checksum commands
declare -A FILE_CHECKSUMS # Cache calculated checksums

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

  # Get current time with milliseconds (pure bash implementation)
  local timestamp
  if [[ "$IS_MACOS" == true ]]; then
    # macOS: Use epoch time with microsecond precision if available
    local base_time=$(date '+%Y-%m-%d %H:%M:%S')
    # Use $$ (process ID) and current time to create pseudo-milliseconds
    local ms=$((($(date +%s) + $$) % 1000))
    timestamp="$base_time,$(printf "%03d" "$ms")"
  else
    # Linux date with nanoseconds converted to milliseconds
    timestamp=$(date '+%Y-%m-%d %H:%M:%S,%3N' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S,000')
  fi

  if [[ -n "$LOG_FILE" ]]; then
    echo "$timestamp - $level - $message" >>"$LOG_FILE"
  fi

  if [[ "$QUIET" == "false" || "$level" == "ERROR" ]]; then
    case "$level" in
    ERROR)
      echo -e "${RED}ERROR${NC}: $message" >&2
      ;;
    INFO)
      echo "$timestamp - $level - $message" >&2
      ;;
    *)
      echo "$timestamp - $level - $message" >&2
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
  echo "bagit version $SCRIPT_VERSION"
  exit 0
}

# Print usage
usage() {
  cat <<EOF
usage: $0 [-h] [--processes PROCESSES] [--log LOG] [--quiet]
                [--validate] [--fast] [--completeness-only] [--sha3_512]
                [--blake2s] [--sha384] [--sha3_384] [--sha256] [--sha1]
                [--blake2b] [--md5] [--sha3_224] [--sha3_256] [--shake_128]
                [--sha512] [--shake_256] [--sha224]
                [--source-organization SOURCE_ORGANIZATION]
                [--organization-address ORGANIZATION_ADDRESS]
                [--contact-name CONTACT_NAME] [--contact-phone CONTACT_PHONE]
                [--contact-email CONTACT_EMAIL]
                [--external-description EXTERNAL_DESCRIPTION]
                [--external-identifier EXTERNAL_IDENTIFIER]
                [--bag-size BAG_SIZE]
                [--bag-group-identifier BAG_GROUP_IDENTIFIER]
                [--bag-count BAG_COUNT]
                [--internal-sender-identifier INTERNAL_SENDER_IDENTIFIER]
                [--internal-sender-description INTERNAL_SENDER_DESCRIPTION]
                [--bagit-profile-identifier BAGIT_PROFILE_IDENTIFIER]
                directory [directory ...]

bagit version $SCRIPT_VERSION

BagIt is a directory, filename convention for bundling an arbitrary set of
files with a manifest, checksums, and additional metadata. More about BagIt
can be found at:

    http://purl.org/net/bagit

bagit.sh is a pure python drop in library and command line tool for creating,
and working with BagIt directories.

Command-Line Usage:

Basic usage is to give bagit.sh a directory to bag up:

    \$ bagit.sh my_directory

This does a bag-in-place operation where the current contents will be moved
into the appropriate BagIt structure and the metadata files will be created.

You can bag multiple directories if you wish:

    \$ bagit.sh directory1 directory2

Optionally you can provide metadata which will be stored in bag-info.txt:

    \$ bagit.sh --source-organization "Library of Congress" directory

You can also select which manifest algorithms will be used:

    \$ bagit.sh --sha1 --md5 --sha256 --sha512 directory

For more information or to contribute to bagit-bash's development, please
visit $PROJECT_URL

positional arguments:
  directory             Directory which will be converted into a bag in place
                        by moving any existing files into the BagIt structure
                        and creating the manifests and other metadata.

options:
  -h, --help            show this help message and exit
  --processes PROCESSES
                        Use multiple processes to calculate checksums faster
                        (default: 1)
  --log LOG             The name of the log file (default: stdout)
  --quiet               Suppress all progress information other than errors
  --validate            Validate existing bags in the provided directories
                        instead of creating new ones
  --fast                Modify --validate behaviour to only test whether the
                        bag directory has the number of files and total size
                        specified in Payload-Oxum without performing checksum
                        validation to detect corruption.
  --completeness-only   Modify --validate behaviour to test whether the bag
                        directory has the expected payload specified in the
                        checksum manifests without performing checksum
                        validation to detect corruption.

Checksum Algorithms:
  Select the manifest algorithms to be used when creating bags (default=sha256, sha512)

  --sha384              Generate SHA-384 manifest when creating a bag
  --shake_128           Generate SHAKE_128 manifest when creating a bag
  --sha3_512            Generate SHA3_512 manifest when creating a bag
  --md5                 Generate MD-5 manifest when creating a bag
  --sha512              Generate SHA-512 manifest when creating a bag
  --shake_256           Generate SHAKE_256 manifest when creating a bag
  --sha1                Generate SHA-1 manifest when creating a bag
  --sha256              Generate SHA-256 manifest when creating a bag
  --sha3_256            Generate SHA3_256 manifest when creating a bag
  --sha3_384            Generate SHA3_384 manifest when creating a bag
  --sha3_224            Generate SHA3_224 manifest when creating a bag
  --blake2b             Generate BLAKE2B manifest when creating a bag
  --blake2s             Generate BLAKE2S manifest when creating a bag
  --sha224              Generate SHA-224 manifest when creating a bag

Optional Bag Metadata:
  --source-organization SOURCE_ORGANIZATION
  --organization-address ORGANIZATION_ADDRESS
  --contact-name CONTACT_NAME
  --contact-phone CONTACT_PHONE
  --contact-email CONTACT_EMAIL
  --external-description EXTERNAL_DESCRIPTION
  --external-identifier EXTERNAL_IDENTIFIER
  --bag-size BAG_SIZE
  --bag-group-identifier BAG_GROUP_IDENTIFIER
  --bag-count BAG_COUNT
  --internal-sender-identifier INTERNAL_SENDER_IDENTIFIER
  --internal-sender-description INTERNAL_SENDER_DESCRIPTION
  --bagit-profile-identifier BAGIT_PROFILE_IDENTIFIER

EOF
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Get the appropriate checksum command for an algorithm
get_checksum_command() {
  local alg="$1"

  # Check cache first
  if [[ -n "${CHECKSUM_CMDS[$alg]:-}" ]]; then
    echo "${CHECKSUM_CMDS[$alg]}"
    return 0
  fi

  local cmd=""
  case "$alg" in
  md5)
    if [[ "$IS_MACOS" == true ]]; then
      cmd="md5 -r"
    else
      cmd="md5sum"
    fi
    ;;
  sha1)
    if command_exists sha1sum; then
      cmd="sha1sum"
    else
      cmd="shasum -a 1"
    fi
    ;;
  sha224)
    if command_exists sha224sum; then
      cmd="sha224sum"
    else
      cmd="shasum -a 224"
    fi
    ;;
  sha256)
    if command_exists sha256sum; then
      cmd="sha256sum"
    else
      cmd="shasum -a 256"
    fi
    ;;
  sha384)
    if command_exists sha384sum; then
      cmd="sha384sum"
    else
      cmd="shasum -a 384"
    fi
    ;;
  sha512)
    if command_exists sha512sum; then
      cmd="sha512sum"
    else
      cmd="shasum -a 512"
    fi
    ;;
  sha3_224)
    cmd="openssl dgst -sha3-224"
    ;;
  sha3_256)
    cmd="openssl dgst -sha3-256"
    ;;
  sha3_384)
    cmd="openssl dgst -sha3-384"
    ;;
  sha3_512)
    cmd="openssl dgst -sha3-512"
    ;;
  blake2b)
    if command_exists b2sum; then
      cmd="b2sum"
    else
      cmd="openssl dgst -blake2b512"
    fi
    ;;
  blake2s)
    if command_exists b2sum; then
      cmd="b2sum -a blake2s"
    else
      cmd="openssl dgst -blake2s256"
    fi
    ;;
  shake_128)
    cmd="openssl dgst -shake128"
    ;;
  shake_256)
    cmd="openssl dgst -shake256"
    ;;
  *)
    error "Unknown algorithm: $alg"
    return 1
    ;;
  esac

  # Cache the command and return it
  CHECKSUM_CMDS[$alg]="$cmd"
  echo "$cmd"
}

# Calculate checksum of a file
calculate_checksum() {
  local file="$1"
  local alg="$2"
  local cache_key="${file}:${alg}"

  # Check cache first
  if [[ -n "${FILE_CHECKSUMS[$cache_key]:-}" ]]; then
    echo "${FILE_CHECKSUMS[$cache_key]}"
    return 0
  fi

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

  # Cache the result
  FILE_CHECKSUMS[$cache_key]="$output"
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

  # Convert backslashes to forward slashes for manifest (Unix path normalization)
  # Note: This line should convert \ to / but the original had a bug
  # For now, removing this problematic conversion since Linux already uses forward slashes
  # rel_path="${rel_path//\\//}"

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

  # Convert algorithms array to comma-separated string for display
  local alg_string=$(printf "%s, " "${algorithms[@]}")
  alg_string=${alg_string%, } # Remove trailing comma and space

  info "Using $processes processes to generate manifests: $alg_string"

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

      # Get relative path from base directory for display
      local rel_path="${file#$(pwd)/}"
      info "Generating manifest lines for file $rel_path"

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
  info "Creating bagit.txt"
}

# Create bag-info.txt file
create_bag_info() {
  local total_bytes="$1"
  local file_count="$2"

  # Set default values in associative array
  METADATA_MAP["Bagging-Date"]="$(date +%Y-%m-%d)"
  METADATA_MAP["Bag-Software-Agent"]="bagit.sh v$SCRIPT_VERSION <$PROJECT_URL>"
  METADATA_MAP["Payload-Oxum"]="$total_bytes.$file_count"

  # Add any metadata from the METADATA array to the map
  for item in "${METADATA[@]}"; do
    if [[ "$item" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      METADATA_MAP["$key"]="$value"
    fi
  done

  # Sort metadata keys and write to file
  {
    for key in $(printf '%s\n' "${!METADATA_MAP[@]}" | sort); do
      echo "$key: ${METADATA_MAP[$key]}"
    done
  } >bag-info.txt

  info "Creating bag-info.txt"
}

# Generate tagmanifest file
generate_tagmanifest() {
  local alg="$1"
  local tagmanifest="tagmanifest-${alg}.txt"

  info "Creating $(pwd)/$tagmanifest"

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
  info "Creating data directory"

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
      info "Moving $item to $(pwd)/$temp_dir/$item"
      mv "$item" "$temp_dir/" || {
        error "Failed to move $item"
        rm -rf "$temp_dir"
        cd "$old_dir"
        return 1
      }
    fi
  done 2>/dev/null

  # Rename temp directory to data
  info "Moving $(pwd)/$temp_dir to data"
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
}

# Load and parse a tag file into associative array
load_tag_file() {
  local file="$1"

  # Check if second parameter is provided (new style with nameref)
  if [[ $# -eq 2 ]]; then
    local -n result_map=$2 # nameref to the associative array

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
          # Store previous key-value in associative array
          result_map["$key"]="$value"
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
      result_map["$key"]="$value"
    fi
  else
    # Legacy mode - output as key=value pairs for backward compatibility
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

  # Load tags into associative array
  declare -A bagit_tags
  if ! load_tag_file "$bagit_file" bagit_tags; then
    return 1
  fi

  # Check required tags
  if [[ -z "${bagit_tags["BagIt-Version"]:-}" ]]; then
    error "Missing required tag in bagit.txt: BagIt-Version"
    return 1
  fi

  if [[ ! "${bagit_tags["BagIt-Version"]}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    error "Invalid BagIt version: ${bagit_tags["BagIt-Version"]}"
    return 1
  fi

  if [[ -z "${bagit_tags["Tag-File-Character-Encoding"]:-}" ]]; then
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
    return 0
  fi

  # Load bag-info.txt into associative array
  declare -A bag_info_tags
  load_tag_file "$bag_info" bag_info_tags

  local oxum="${bag_info_tags["Payload-Oxum"]:-}"

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

  return 0
}

# Validate completeness
validate_completeness() {
  local bag_dir="$1"
  declare -A manifest_files # Use associative array for O(1) lookups

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
          manifest_files["$filepath"]=1 # Mark file as present in manifest
        fi
      done <"$manifest"
    fi
  done

  # Check all manifest files exist and find extra files
  local missing_files=()
  for filepath in "${!manifest_files[@]}"; do
    if [[ ! -f "$bag_dir/$filepath" ]]; then
      missing_files[${#missing_files[@]}]="$filepath"
    fi
  done

  # Check for extra files using O(1) lookup in associative array
  local extra_files=()
  while IFS= read -r file; do
    local rel_path="${file#$bag_dir/}"
    if [[ -z "${manifest_files[$rel_path]:-}" ]]; then
      extra_files[${#extra_files[@]}]="$rel_path"
    fi
  done < <(find "$bag_dir/data" -type f -print 2>/dev/null)

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

  return 0
}

# Validate checksums
validate_checksums() {
  local bag_dir="$1"
  local processes="$2"

  local has_errors=false

  # First, validate payload files
  for manifest in "$bag_dir"/manifest-*.txt; do
    if [[ ! -f "$manifest" ]]; then
      continue
    fi

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

        info "Verifying checksum for file $full_path"

        # Calculate actual checksum
        local alg=$(basename "$manifest" | sed 's/manifest-\(.*\)\.txt/\1/')
        local actual_checksum=$(calculate_checksum "$full_path" "$alg")

        if [[ "$expected_checksum" != "$actual_checksum" ]]; then
          error "$filepath $alg validation failed: expected=$expected_checksum found=$actual_checksum"
          has_errors=true
        fi
      fi
    done <"$manifest"
  done

  # Then, validate tag files
  for tagmanifest in "$bag_dir"/tagmanifest-*.txt; do
    if [[ ! -f "$tagmanifest" ]]; then
      continue
    fi

    while IFS= read -r line; do
      # Skip empty lines and comments
      if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
      fi

      # Parse tagmanifest line
      if [[ "$line" =~ ^([a-fA-F0-9]+)[[:space:]]+(.+)$ ]]; then
        local expected_checksum="${BASH_REMATCH[1]}"
        local filepath="${BASH_REMATCH[2]}"

        local full_path="$bag_dir/$filepath"

        if [[ ! -f "$full_path" ]]; then
          error "$filepath: File missing"
          has_errors=true
          continue
        fi

        info "Verifying checksum for file $full_path"

        # Calculate actual checksum
        local alg=$(basename "$tagmanifest" | sed 's/tagmanifest-\(.*\)\.txt/\1/')
        local actual_checksum=$(calculate_checksum "$full_path" "$alg")

        if [[ "$expected_checksum" != "$actual_checksum" ]]; then
          error "$filepath $alg validation failed: expected=$expected_checksum found=$actual_checksum"
          has_errors=true
        fi
      fi
    done <"$tagmanifest"
  done

  if [[ "$has_errors" == true ]]; then
    return 1
  fi

  return 0
}

# Validate a bag
validate_bag() {
  local bag_dir="$1"

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

  # Extract just the directory name for the final message to match Python format
  local dir_name=$(basename "$bag_dir")
  info "$dir_name is valid"
  return 0
}

# Parse command line arguments
parse_args() {
  local directories=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --version | -v)
      print_version
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    --processes | -p)
      shift
      if [[ -z "${1:-}" || ! "$1" =~ ^[0-9]+$ || "$1" -le 0 ]]; then
        error "The number of processes must be greater than 0"
        exit 2
      fi
      PROCESSES="$1"
      ;;
    --log | -l)
      shift
      if [[ -z "${1:-}" ]]; then
        error "--log requires a filename"
        exit 2
      fi
      LOG_FILE="$1"
      ;;
    --quiet | -q)
      QUIET=true
      ;;
    --validate | -V)
      VALIDATE=true
      ;;
    --fast | -f)
      FAST=true
      ;;
    --completeness-only | -c)
      COMPLETENESS_ONLY=true
      ;;
    # Checksum algorithms
    --md5 | --sha1 | --sha224 | --sha256 | --sha384 | --sha512 | --sha3_224 | --sha3_256 | --sha3_384 | --sha3_512 | --blake2b | --blake2s | --shake_128 | --shake_256)
      local alg="${1#--}"
      ALGORITHMS[${#ALGORITHMS[@]}]="$alg"
      ALGORITHMS_MAP["$alg"]=1 # Mark algorithm as enabled
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
    # Populate algorithms map for defaults
    for alg in "${DEFAULT_ALGORITHMS[@]}"; do
      ALGORITHMS_MAP["$alg"]=1
    done
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
