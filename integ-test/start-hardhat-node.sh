#!/bin/bash

# Start Hardhat node for integration tests
# This script starts an external Hardhat node that the tests can connect to

set -e

echo "🚀 Starting external Hardhat node for integration tests..."

# Kill any existing Hardhat node process
pkill -f "hardhat node" || true

# Wait a moment for the process to be killed
sleep 2

# Start the Hardhat node in the background
echo "Starting Hardhat node on http://localhost:8545..."
cd "$(dirname "$0")"
npx hardhat node --hostname 0.0.0.0 > hardhat-node.log 2>&1 &

# Store the process ID
echo $! > hardhat-node.pid

# Wait for the node to be ready
echo "Waiting for Hardhat node to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8545 > /dev/null 2>&1; then
        echo "✅ Hardhat node is ready!"
        echo "Node is running on http://localhost:8545"
        echo "Process ID: $(cat hardhat-node.pid)"
        echo "Log file: hardhat-node.log"
        exit 0
    fi
    echo "Waiting for node to start... ($i/30)"
    sleep 1
done

echo "❌ Failed to start Hardhat node"
exit 1 