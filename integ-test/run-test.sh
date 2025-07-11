#!/bin/bash

# Run integration tests with external Hardhat node
# This script starts an external Hardhat node and runs the tests with --network local

set -e

echo "🧪 Running DTN Integration Tests with External Hardhat Node"
echo "=========================================================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up..."
    if [ -f "stop-hardhat-node.sh" ]; then
        ./stop-hardhat-node.sh
    fi
    echo "✅ Cleanup completed"
}

# Set up trap to cleanup on script exit
trap cleanup EXIT

# Start the external Hardhat node
echo "🚀 Starting external Hardhat node..."
./start-hardhat-node.sh

# Wait a moment for the node to be fully ready
echo "⏳ Waiting for node to be fully ready..."
sleep 3

# Run the tests with local network
echo "🧪 Running tests with --network local..."
npx hardhat test test/full-example-test.js --network local

echo "✅ Tests completed!" 