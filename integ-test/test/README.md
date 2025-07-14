# DTN Integration Test Suite

This directory contains integration tests for the DTN (Decentralized Trust Network) system.

## Files

- `full-example-test.js` - Main integration test that runs through the complete DTN workflow
- `dtn-node-manager.js` - Helper class for managing DTN node operations
- `README.md` - This documentation file

## DtnNodeManager Class

The `DtnNodeManager` class provides a clean, modular interface for launching and managing DTN full nodes during testing.

### Features

- **Dependency Checking**: Verifies that Docker, docker-compose, and curl are available
- **Configuration Management**: Creates test configuration files for the DTN network and AI sidecars
- **Service Management**: Starts services and monitors their health (assumes Docker images are pre-built)
- **Health Testing**: Tests health endpoints and API endpoints with retry logic
- **Logging**: Displays service logs for debugging
- **Cleanup**: Properly shuts down services and cleans up resources

### Usage

```javascript
const DtnNodeManager = require("./dtn-node-manager");

// Initialize the manager
const dtnNodeManager = new DtnNodeManager(fullNodeDir, testConfig);

// Launch the complete DTN full node
await dtnNodeManager.launchNode(deployedAddresses, owner, user1);

// Clean up when done
await dtnNodeManager.cleanup();
```

### Methods

#### `checkDependencies()`
Checks if required dependencies (Docker, docker-compose, curl) are available.

#### `createTestConfiguration(deployedAddresses, owner, user1)`
Creates a test configuration file (`full_config.yaml`) with:
- Network settings pointing to the test environment
- Contract addresses from previous deployment steps
- Test environment variables
- dtn-ai sidecar configuration

#### `createTestEnvironment(owner, user1)`
Creates a `.env` file with test environment variables including private keys.

#### `runSetupScript()`
Runs the DTN full node setup script to generate Docker Compose files.



#### `startServices()`
Starts the DTN services using docker-compose.

#### `waitForServices()`
Waits for services to be ready and checks their status.

#### `testHealthEndpoints()`
Tests the dtn-ai health endpoint with retry logic.

#### `testApiEndpoints()`
Tests the dtn-ai API endpoint with a sample request.

#### `checkServiceLogs()`
Displays logs from both dtn-network and dtn-ai services.

#### `verifyServices()`
Verifies that all services are running and healthy.

#### `launchNode(deployedAddresses, owner, user1)`
Main method that orchestrates the complete node launch process.

#### `cleanup()`
Shuts down services and cleans up resources.

### Error Handling

The class includes comprehensive error handling:
- Automatic cleanup on failure
- Retry logic for health checks
- Graceful handling of missing dependencies
- Detailed error messages with context

### Configuration

The manager uses the following configuration structure:

```javascript
const testConfig = {
  rpcUrl: "http://localhost:8545",
  chainId: 31337,
  nodePort: 8026,
  aiPort: 8027,
  testPrompt: "What is 2 + 2? Answer with only the number.",
  expectedResponse: "4"
};
```

### Dependencies

The manager requires:
- **Docker**: For running containerized services (images must be pre-built)
- **docker-compose**: For orchestrating multiple services
- **curl**: For testing HTTP endpoints
- **yaml**: For parsing and writing YAML configuration files

### Testing

The manager is designed to work with the integration test suite and provides:
- Health check validation
- API endpoint testing
- Service log monitoring
- Automatic cleanup

**Note**: This manager assumes that Docker images are already built and available. It focuses on running and testing the services rather than building them.

This modular approach makes the integration tests more maintainable and easier to debug. 