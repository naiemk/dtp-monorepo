# DTN Integration Tests

This directory contains integration tests for the DTN (Decentralized Trust Network) system using an external Hardhat node.

## Overview

The integration tests are designed to run against an external Hardhat node to ensure that:
- Ignition deployment scripts work correctly with external nodes
- Contract interactions work properly across different processes
- The full DTN system can be tested end-to-end

## Prerequisites

- Node.js and npm installed
- Hardhat and related dependencies installed in the `contracts` directory
- The `contracts` directory should be properly set up with all required contracts and ignition modules

## Running the Tests

### Option 1: Using the Test Runner Script (Recommended)

The easiest way to run the tests is using the provided test runner script:

```bash
cd integ-test
./run-test.sh
```

This script will:
1. Start an external Hardhat node
2. Wait for the node to be ready
3. Run the tests with `--network local`
4. Clean up the external node when done

### Option 2: Manual Setup

If you prefer to run the tests manually:

1. Start the external Hardhat node:
   ```bash
   cd integ-test
   ./start-hardhat-node.sh
   ```

2. In a separate terminal, run the tests:
   ```bash
   cd integ-test
   npx hardhat test test/full-example-test.js --network local
   ```

3. Stop the external node when done:
   ```bash
   ./stop-hardhat-node.sh
   ```

## Test Structure

The integration test (`full-example-test.js`) follows these steps:

1. **Step 1**: Verify external Hardhat network is running
2. **Step 2**: Deploy MockERC20 token for fees
3. **Step 3**: Deploy DTN contracts using Ignition CLI with `--network local`
4. **Step 4**: Simulate DTN full node deployment
5. **Step 5**: Deploy CallAiExample contract using Ignition CLI with `--network local`
6. **Step 6**: Run AI example request and validate response

## Configuration

The test uses the following configuration:

- **Network**: `local` (connects to external Hardhat node on `http://localhost:8545`)
- **Chain ID**: 31337 (Hardhat default)
- **Test Accounts**: Generated from mnemonic "test test test test test test test test test test test junk"

## Files

- `test/full-example-test.js` - Main integration test file
- `start-hardhat-node.sh` - Script to start external Hardhat node
- `stop-hardhat-node.sh` - Script to stop external Hardhat node
- `run-test.sh` - Complete test runner script
- `hardhat.config.js` - Hardhat configuration with local network
- `README.md` - This documentation

## Troubleshooting

### Node Already Running
If you get an error about the node already running, you can stop it first:
```bash
./stop-hardhat-node.sh
```

### Connection Issues
If the tests fail to connect to the external node:
1. Check that the node is running: `curl http://localhost:8545`
2. Check the node logs: `tail -f hardhat-node.log`
3. Restart the node: `./stop-hardhat-node.sh && ./start-hardhat-node.sh`

### Ignition Deployment Issues
If Ignition deployment fails:
1. Ensure you're in the correct directory (`integ-test`)
2. Check that the `contracts` directory has all required ignition modules
3. Verify the parameter files are being created correctly

## Notes

- The external node approach ensures that Ignition CLI commands work properly
- The test uses simplified contract ABIs for testing purposes
- In production, you would use proper deployment artifacts
- The node simulation in Step 4 is for testing purposes only