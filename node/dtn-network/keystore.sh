#!/bin/bash

# Simple wrapper script for foundry-keystore-cli (cckey) in Docker
# This script passes all command line arguments directly to cckey

set -e

# Default configuration
FOUNDRY_KEYSTORE_PATH="${FOUNDRY_KEYSTORE_PATH:-./.keystore}"
IMAGE_NAME="${DTN_NODE_IMAGE:-dtn-network-node:latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to show help
show_help() {
    cat << EOF
DTN Network Keystore CLI Wrapper

This is a simple Docker wrapper for foundry-keystore-cli (cckey).
All arguments are passed directly to cckey running inside a Docker container.

USAGE:
    ./keystore.sh [cckey-options] <command> [command-options]
    ./keystore.sh import-private-key <32-byte-private-key> --passphrase "password"

EXAMPLES:
    ./keystore.sh --help
    ./keystore.sh --keys-path ./my-keystore.db list
    ./keystore.sh create --passphrase "my-password"
    ./keystore.sh export --address "ccc..." --passphrase "my-password"
    ./keystore.sh import-raw 0x1234... --passphrase "my-password"
    ./keystore.sh import-private-key 02fe70bae08a7abf242172937b56260694fc5cbdbb10517c479fa33460036a3f --passphrase "my-password"

ENVIRONMENT VARIABLES:
    FOUNDRY_KEYSTORE_PATH    Host path to keystore directory (default: ./keystore)
    DTN_NODE_IMAGE           Docker image name (default: dtn-network-node:latest)

KEY PADDING:
    - cckey requires 64-byte (128 hex characters) private keys
    - Standard private keys are 32-byte (64 hex characters)
    - Use 'import-private-key' command to automatically pad 32-byte keys
    - Or manually pad by duplicating the key: 32bytekey + 32bytekey

NOTE:
    - The keystore directory is automatically mounted to /app/keystore in the container
    - Use --keys-path /app/keystore/keystore.db (or your preferred filename) in cckey commands
    - All cckey commands and options are supported unchanged
EOF
}

# Check if help is requested
if [ "${1:-}" = "help" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    print_error "Docker image '$IMAGE_NAME' not found"
    print_info "Please build the image first with: npm run docker:build"
    exit 1
fi

# Ensure keystore directory exists
if [ -d "$FOUNDRY_KEYSTORE_PATH" ]; then
    print_info "Creating keystore directory: $FOUNDRY_KEYSTORE_PATH"
    mkdir -p "$FOUNDRY_KEYSTORE_PATH"
    print_success "Keystore directory created"
fi

# Get the absolute path to avoid issues with relative paths
KEYSTORE_ABS_PATH="$(realpath "$FOUNDRY_KEYSTORE_PATH")"

# Handle import-private-key command (32-byte key with automatic padding)
if [ "${1:-}" = "import-private-key" ]; then
    if [ $# -lt 2 ]; then
        print_error "Usage: ./keystore.sh import-private-key <32-byte-private-key> --passphrase \"password\""
        exit 1
    fi
    
    PRIVATE_KEY="$2"
    
    # Validate that it's a 32-byte private key (64 hex characters)
    if ! echo "$PRIVATE_KEY" | grep -qE '^[a-fA-F0-9]{64}$'; then
        print_error "Private key must be 64 hex characters (32 bytes)"
        print_info "Example: 02fe70bae08a7abf242172937b56260694fc5cbdbb10517c479fa33460036a3f"
        exit 1
    fi
    
    # Pad the 32-byte key to 64 bytes by duplicating it
    PADDED_KEY="${PRIVATE_KEY}${PRIVATE_KEY}"
    
    print_info "Importing 32-byte private key with automatic padding..."
    print_info "Original key: ${PRIVATE_KEY:0:16}...${PRIVATE_KEY:48:16}"
    print_info "Padded key: ${PADDED_KEY:0:16}...${PADDED_KEY:112:16}"
    
    # Shift arguments to remove 'import-private-key' and replace with 'import-raw'
    shift
    set -- "import-raw" "$PADDED_KEY" "$@"
fi

# Run cckey with all passed arguments
print_info "Running: cckey $*"
print_info "Keystore mounted from: $KEYSTORE_ABS_PATH"

# Check if running in non-interactive mode (e.g., from tests or scripts)
if [ -t 0 ] && [ -t 1 ]; then
    # Interactive mode - use -it flags
    docker run --rm -it \
        -v "$KEYSTORE_ABS_PATH":/app/keystore \
        "$IMAGE_NAME" \
        cckey --keys-path /app/keystore/keystore.db "$@"
else
    # Non-interactive mode - don't use -it flags
    docker run --rm \
        -v "$KEYSTORE_ABS_PATH":/app/keystore \
        "$IMAGE_NAME" \
        cckey --keys-path /app/keystore/keystore.db "$@"
fi