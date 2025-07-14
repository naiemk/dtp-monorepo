# DTN Network Node CLI

A command-line interface for running DTN (Decentralized Trust Network) nodes.

## Installation

1. Install dependencies:
```bash
npm install
# or
bun install
```

2. Set up your environment variables in a `.env` file or export them:
```bash
export OWNER_PRIVATE_KEY="your_owner_private_key"
export WORKER_PRIVATE_KEY="your_worker_private_key"
```

3. Configure your node by editing `nodeConfig.yaml`

## Usage

### Run Once
Execute the DTN service once and exit:
```bash
# Using npm script
bun run start:once
# or directly
bun run src/index.ts run-once
# or with custom config
bun run src/index.ts run-once --config ./custom-config.yaml
```

### Run in Loop
Run the DTN service continuously with a configurable interval:
```bash
# Using npm script
bun run start:loop
# or directly
bun run src/index.ts loop
# or with custom interval (in seconds)
bun run src/index.ts loop --interval 10
# or with custom config and interval
bun run src/index.ts loop --config ./custom-config.yaml --interval 30
```

### Configure Node
Register and configure your node on the blockchain:
```bash
# Using npm script
bun run configure
# or directly
bun run src/index.ts configure-node
# or with custom config
bun run src/index.ts configure-node --config ./custom-config.yaml
```

## Global Options

- `-c, --config <path>`: Path to configuration file (default: `./nodeConfig.yaml`)
- `-v, --verbose`: Enable verbose logging
- `-h, --help`: Show help information

## Examples

```bash
# Run with verbose logging
bun run src/index.ts run-once --verbose

# Run in loop with 30-second intervals and verbose logging
bun run src/index.ts loop --interval 30 --verbose

# Configure node with custom config
bun run src/index.ts configure-node --config ./production-config.yaml
```

## Configuration

The CLI uses a YAML configuration file (`nodeConfig.yaml` by default) that defines:

- Network settings (RPC URL, contract addresses)
- Node information (username, node name, worker address)
- Model configurations
- IPFS settings
- Local cache directory

See `nodeConfig.yaml` for a complete example.

## Environment Variables

Required environment variables (referenced in config):
- `OWNER_PRIVATE_KEY`: Private key for node owner operations
- `WORKER_PRIVATE_KEY`: Private key for worker operations

## Error Handling

The CLI includes comprehensive error handling:
- Graceful shutdown on SIGINT/SIGTERM
- Automatic retry logic in loop mode
- Detailed error messages with context
- Proper exit codes for automation

## Development

To build the project:
```bash
bun run build
```

To run in development mode with watch:
```bash
bun run dev
```

## Docker Operations

### Build and Test Docker Image

Build the Docker image:
```bash
bun run docker:build
```

Test the Docker container:
```bash
bun run docker:test
```

Build and test in one command:
```bash
bun run docker:all
```

Clean up Docker resources:
```bash
bun run docker:clean
```

For more details, see [scripts/README.md](scripts/README.md).
