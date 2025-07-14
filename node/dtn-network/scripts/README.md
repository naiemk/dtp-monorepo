# DTN Network Node Scripts

This directory contains build and test scripts for the DTN Network Node.

## Scripts Overview

### `build.sh`
Builds the Docker image for the DTN Network Node.

**Features:**
- Validates Docker is running
- Checks for required files
- Builds using `Dockerfile.prod`
- Provides colored output and progress indicators
- Cleans up existing test containers

**Usage:**
```bash
./scripts/build.sh
```

### `test.sh`
Tests the Docker container to ensure the DTN Network Node service is working properly.

**Features:**
- Validates the Docker image exists
- Creates a test configuration
- Runs the container with test environment variables
- Performs multiple health checks:
  - CLI help command functionality
  - Configuration loading
  - Application structure validation
  - Binary permissions
  - Container health status
- Cleans up test environment

**Usage:**
```bash
./scripts/test.sh
```

## Quick Start

### Using bun scripts (Recommended)
```bash
# Build and test in one command
bun run docker:all

# Or individually
bun run docker:build
bun run docker:test

# Clean up
bun run docker:clean
```

### Using npm scripts
```bash
# Build Docker image
npm run docker:build

# Test Docker container
npm run docker:test

# Build and test
npm run docker:all

# Clean up
npm run docker:clean
```

### Using scripts directly
```bash
# Build
./scripts/build.sh

# Test
./scripts/test.sh
```

## Prerequisites

- Docker installed and running
- Bun (for running scripts)
- Node.js 18+ (for local development)

## Test Configuration

The test script creates a temporary `test-config.yaml` file with:
- Test private keys (dummy values)
- Basic network configuration
- Test node settings

This configuration is used to verify the application can:
- Load configuration files
- Parse YAML correctly
- Handle environment variables
- Execute CLI commands

## Troubleshooting

### Docker not running
```bash
# Start Docker
sudo systemctl start docker
# or
sudo service docker start
```

### Permission denied
```bash
# Make scripts executable
chmod +x scripts/*.sh
```

### Image not found
```bash
# Build the image first
./scripts/build.sh
```

### Container fails to start
Check the container logs:
```bash
docker logs dtn-node-test
```

## Development Workflow

1. **Build the image:**
   ```bash
   bun run docker:build
   ```

2. **Test the container:**
   ```bash
   bun run docker:test
   ```

3. **Clean up when done:**
   ```bash
   bun run docker:clean
   ```

## Integration with CI/CD

These scripts can be easily integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Build and Test DTN Node
  run: |
    cd node/dtn-network
    bun run docker:all
```

The scripts return appropriate exit codes for automation:
- `0` - Success
- `1` - Failure

## Environment Variables

The test script uses these environment variables:
- `TEST_OWNER_PRIVATE_KEY` - Test owner private key
- `TEST_WORKER_PRIVATE_KEY` - Test worker private key
- `NODE_ENV` - Set to "test"

For production, you'll need to set:
- `OWNER_PRIVATE_KEY` - Real owner private key
- `WORKER_PRIVATE_KEY` - Real worker private key 