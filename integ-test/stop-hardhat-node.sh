#!/bin/bash

# Stop Hardhat node for integration tests
# This script stops the external Hardhat node that was started by start-hardhat-node.sh

set -e

echo "🛑 Stopping external Hardhat node..."

# Check if we have a PID file
if [ -f "hardhat-node.pid" ]; then
    PID=$(cat hardhat-node.pid)
    echo "Found Hardhat node process ID: $PID"
    
    # Try to kill the process gracefully
    if kill -0 $PID 2>/dev/null; then
        echo "Stopping Hardhat node process..."
        kill $PID
        
        # Wait for the process to stop
        for i in {1..10}; do
            if ! kill -0 $PID 2>/dev/null; then
                echo "✅ Hardhat node stopped successfully"
                rm -f hardhat-node.pid
                exit 0
            fi
            echo "Waiting for process to stop... ($i/10)"
            sleep 1
        done
        
        # Force kill if it's still running
        echo "Force killing Hardhat node process..."
        kill -9 $PID 2>/dev/null || true
        rm -f hardhat-node.pid
    else
        echo "Process $PID is not running"
        rm -f hardhat-node.pid
    fi
else
    echo "No PID file found, trying to kill any hardhat node processes..."
fi

# Also try to kill any remaining hardhat node processes
pkill -f "hardhat node" || true

echo "✅ Hardhat node cleanup completed" 