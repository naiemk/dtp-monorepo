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

EXAMPLES:
    ./keystore.sh --help
    ./keystore.sh --keys-path ./my-keystore.db list
    ./keystore.sh create --passphrase "my-password"
    ./keystore.sh export --address "ccc..." --passphrase "my-password"
    ./keystore.sh import-raw 0x1234... --passphrase "my-password"

ENVIRONMENT VARIABLES:
    FOUNDRY_KEYSTORE_PATH    Host path to keystore directory (default: ./keystore)
    DTN_NODE_IMAGE           Docker image name (default: dtn-network-node:latest)

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

# Run cckey with all passed arguments
print_info "Running: cckey $*"
print_info "Keystore mounted from: $KEYSTORE_ABS_PATH"

docker run --rm -it \
    -v "$KEYSTORE_ABS_PATH":/app/keystore \
    "$IMAGE_NAME" \
    cckey --keys-path /app/keystore/keystore.db "$@"