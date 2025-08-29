# DTN Network Node CLI

A command-line interface for running DTN (Decentralized Trust Network) nodes.

## Installation

1. Install dependencies:
```bash
npm install
# or
bun install
```

2. Set up your foundry keystore with private keys:
```bash
# Install foundry-keystore-cli (if not already installed)
npm install -g foundry-keystore-cli

# Create and store your private keys in the keystore
cckey create --keys-path ~/.foundry/keystores --name owner-key --password "your-secure-passphrase"
cckey create --keys-path ~/.foundry/keystores --name worker-key --password "your-secure-passphrase"

# Set environment variables for keystore access
export FOUNDRY_KEYSTORE_PASSPHRASE="your-secure-passphrase"
# Optional: Set custom keystore path (defaults to ~/.foundry/keystores)
export FOUNDRY_KEYSTORE_PATH="/path/to/your/keystore"
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
- Keystore key names for private key references

The configuration file references keystore key names (e.g., `owner-key`, `worker-key`) instead of environment variables for enhanced security.

See `nodeConfig.yaml` for a complete example.

## Environment Variables

Required environment variables for keystore access:
- `FOUNDRY_KEYSTORE_PASSPHRASE`: Passphrase to decrypt keys from the foundry keystore
- `FOUNDRY_KEYSTORE_PATH`: (Optional) Custom path to keystore directory (defaults to `~/.foundry/keystores`)

## Keystore Management

The application uses foundry-keystore-cli (cckey) for secure private key management. Key operations:

```bash
# List available keys
cckey list --keys-path ~/.foundry/keystores

# Create a new key
cckey create --keys-path ~/.foundry/keystores --name my-key --password "secure-passphrase"

# Export a key (for backup)
cckey export --keys-path ~/.foundry/keystores --name my-key --password "secure-passphrase"

# Import an existing key
cckey import-raw --keys-path ~/.foundry/keystores --name my-key --private-key "0x..." --password "secure-passphrase"
```

Ensure your keystore contains keys with names matching those specified in your `nodeConfig.yaml` file.

## Docker-Only Usage (No npm required)

If you prefer to use only Docker without installing npm locally, you can manage keys using the provided `keystore.sh` script:

### Setup with Docker

1. **Build the Docker image:**
   ```bash
   ./scripts/build.sh
   ```

2. **Set up environment variables:**
   ```bash
   export FOUNDRY_KEYSTORE_PASSPHRASE="your-secure-passphrase"
   ```

3. **Manage keys using the keystore script:**
   ```bash
   # Create keys for your node (returns the generated address)
   ./keystore.sh --keys-path /app/keystore/keystore.db create --passphrase "your-passphrase"
   
   # List all keys
   ./keystore.sh --keys-path /app/keystore/keystore.db list
   
   # Export a key (for backup) - use the address from create/list
   ./keystore.sh --keys-path /app/keystore/keystore.db export --address "ccc..." --passphrase "your-passphrase"
   
   # Import an existing private key
   ./keystore.sh --keys-path /app/keystore/keystore.db import-raw 0x1234567890abcdef... --passphrase "your-passphrase"
   
   # Delete a key - use the address
   ./keystore.sh --keys-path /app/keystore/keystore.db delete --address "ccc..."
   ```

4. **Run the node using Docker Compose:**
   ```bash
   # Start the node
   docker-compose up -d
   
   # View logs
   docker-compose logs -f
   
   # Stop the node
   docker-compose down
   ```

### Keystore Script Commands

The `keystore.sh` script is a simple wrapper that passes all arguments directly to `cckey` running in Docker:

- `./keystore.sh [options] command [command-options]` - All cckey commands are supported
- `./keystore.sh help` - Show help information
- Use `--keys-path /app/keystore/keystore.db` to specify the keystore file location

Common examples:
- Create key: `./keystore.sh --keys-path /app/keystore/keystore.db create --passphrase "pass"`
- List keys: `./keystore.sh --keys-path /app/keystore/keystore.db list`
- Export key: `./keystore.sh --keys-path /app/keystore/keystore.db export --address "ccc..." --passphrase "pass"`

The keystore directory (`./keystore`) is shared between the host and Docker container, so keys persist across container restarts.

### Alternative: Using npm script

If you have npm installed, you can also use:
```bash
npm run keystore -- --keys-path /app/keystore/keystore.db create --passphrase "pass"
npm run keystore -- --keys-path /app/keystore/keystore.db list
```

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
