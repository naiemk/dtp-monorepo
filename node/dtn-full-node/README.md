# DTN Full Node Setup

This directory contains a complete setup for running a DTN (Decentralized Trust Network) full node with dtn-network and dtn-ai sidecars using Docker Compose.

## Overview

The setup automatically generates Docker Compose configurations from a single `full_config.yaml` file, creating:
- One dtn-network service (main node)
- Multiple dtn-ai sidecar services (based on configuration)
- Proper networking and volume management
- Health checks and resource limits

## Quick Start

1. **Clone and navigate to the directory:**
   ```bash
   cd node/dtn-full-node
   ```

2. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Configure your environment:**
   ```bash
   # Edit the .env file with your actual values
   nano .env
   ```

4. **Start the services:**
   ```bash
   ./start_docker.sh start
   ```

5. **Check the status:**
   ```bash
   ./start_docker.sh status
   ```

## Configuration

### full_config.yaml

The main configuration file that defines:
- DTN network settings (keys, RPC, contracts)
- IPFS configuration (Pinata)
- Model APIs and custom models
- Node information
- dtn-ai sidecar configurations

Example structure:
```yaml
dtn-network:
  keys:
    ownerPrivateKey: "OWNER_PRIVATE_KEY_ENV_VAR_NAME"
    workerPrivateKey: "WORKER_PRIVATE_KEY_ENV_VAR_NAME"
  network:
    rpcUrl: "https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID"
    chainId: 11155111
  # ... more configuration

dtn-ai-sidecars:
  - openai-proxy:
      envs:
        openai_api_key: "YOUR_OPENAI_API_KEY_ENV_VAR_NAME"
      models:
        - model: "model.system.openai-gpt-o3-simpletext"
          processor: "processor_gpt_o3"
```

### Environment Variables (.env)

Create a `.env` file with your actual values:
```bash
# Private Keys
OWNER_PRIVATE_KEY=your_actual_owner_private_key
WORKER_PRIVATE_KEY=your_actual_worker_private_key

# Network
INFURA_PROJECT_ID=your_infura_project_id

# IPFS (Pinata)
PINATA_API_KEY=your_pinata_api_key
PINATA_SECRET_KEY=your_pinata_secret_key

# OpenAI (for sidecars)
YOUR_OPENAI_API_KEY_ENV_VAR_NAME=your_openai_api_key
```

## Generated Files

After running the setup script, the following files are generated:

- `config.yaml` - Configuration for the dtn-network service
- `docker-compose.yml` - Complete Docker Compose setup
- `sidecar-configs/` - Individual configuration files for each dtn-ai sidecar

## Services

### dtn-network
- **Container**: Main DTN network node
- **Port**: Internal only (no external exposure)
- **Volumes**: 
  - `./config.yaml:/app/nodeConfig.yaml:ro`
  - `dtn-cache:/app/cache`
- **Health Check**: Node.js process check

### dtn-ai-sidecars
- **Containers**: Multiple sidecar services (one per configuration)
- **Ports**: `8026-8030` (dynamically assigned)
- **Volumes**: Individual config files mounted as `/app/config.yaml`
- **Health Check**: HTTP health endpoint check
- **Resources**: 512M memory, 1 CPU limit

## Network Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   dtn-network   │    │  dtn-ai-sidecar │
│   (main node)   │◄──►│   (openai-1)    │
└─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         └──────────────►│  dtn-ai-sidecar │
                        │   (openai-2)    │
                        └─────────────────┘
```

All services communicate through the `dtn-network` bridge network.

## Management Commands

### Start Services
```bash
docker-compose up -d
```

### Stop Services
```bash
docker-compose down
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f dtn-network
docker-compose logs -f dtn-ai-openai-proxy-1
```

### Check Status
```bash
docker-compose ps
```

### Rebuild Services
```bash
docker-compose build
docker-compose up -d
```

### Update Configuration
```bash
# Edit full_config.yaml
nano full_config.yaml

# Regenerate configurations
./setup.sh

# Restart services
docker-compose down
docker-compose up -d
```

## Troubleshooting

### Common Issues

1. **Environment variables not set**
   - Ensure `.env` file exists and contains all required variables
   - Check that variable names match those in `full_config.yaml`

2. **Port conflicts**
   - Sidecar ports are automatically assigned (8026-8030)
   - Check for conflicts with `docker-compose ps`

3. **Health check failures**
   - Check logs: `docker-compose logs <service-name>`
   - Verify API keys and network connectivity

4. **Configuration errors**
   - Validate YAML syntax in `full_config.yaml`
   - Check generated config files in `sidecar-configs/`

### Debug Mode

Run services in foreground to see detailed logs:
```bash
docker-compose up
```

### Clean Restart

To completely reset the setup:
```bash
docker-compose down -v
rm -rf sidecar-configs/
rm config.yaml
./setup.sh
docker-compose up -d
```

## Security Considerations

- Never commit `.env` files to version control
- Use strong, unique private keys
- Regularly rotate API keys
- Monitor service logs for suspicious activity
- Keep Docker images updated

## Support

For issues related to:
- **DTN Network**: Check the dtn-network documentation
- **DTN AI**: Check the dtn-ai documentation
- **Docker Setup**: Review this README and generated configurations 