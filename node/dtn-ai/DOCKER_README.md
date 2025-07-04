# DTN AI Server Docker Package

This directory contains a minimal Alpine Docker image for the DTN AI Server.

## 🐳 Docker Image Features

- **Multi-stage build** for minimal image size (~100-200MB)
- **Alpine Linux** base for security and small footprint
- **Non-root user** for security
- **Health checks** for monitoring
- **Resource limits** for production deployment

## 📦 Files

- `Dockerfile` - Multi-stage Alpine build configuration
- `.dockerignore` - Excludes unnecessary files from build context
- `docker-compose.yml` - Easy deployment with environment variables
- `build.sh` - Build script with helpful output
- `test_docker.sh` - Comprehensive Docker testing script
- `test_server_local.py` - Local testing without Docker

## 🚀 Quick Start

### 1. Build the Image

```bash
# Using the build script (recommended)
./build.sh

# Or manually
docker build -t dtn-ai-server:latest .
```

### 2. Run the Container

```bash
# Using Docker
docker run -d --name dtn-ai-server \
  -p 8026:8026 \
  -e OPENAI_API_KEY=your_api_key \
  dtn-ai-server:latest

# Using Docker Compose
OPENAI_API_KEY=your_api_key docker-compose up -d
```

### 3. Test the Container

```bash
# Run comprehensive tests
./test_docker.sh

# Check health endpoint
curl http://localhost:8026/health

# Test API endpoint
curl -X POST http://localhost:8026/api/request \
  -H "Content-Type: application/json" \
  -d '{
    "requestId": "test123",
    "model": "model.system.openai-gpt-o3-simpletext",
    "call": {
      "parameters": ["Hello, how are you?"],
      "types": ["string"]
    }
  }'
```

## 🧪 Testing

### Local Testing (without Docker)

```bash
# Create virtual environment
python3 -m venv test_env
source test_env/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run local tests
python3 test_server_local.py
```

### Docker Testing

```bash
# Build and test
./build.sh
./test_docker.sh
```

## 📊 Expected Results

### Local Tests
```
🚀 Starting DTN AI Server Local Tests

🧪 Testing dependencies...
   ✅ aiohttp available
   ✅ PyYAML available
   ✅ openai available
   ✅ requests available
🧪 Testing configuration loading...
✅ Configuration loaded successfully
   Models configured: 2
   - model.system.openai-gpt-o3-simpletext -> processor_gpt_o3
   - model.system.openai-gpt-o3-simpleimage -> processor_gpt_o3
🧪 Testing processor import...
✅ Processor imports successfully
🧪 Testing server initialization...
✅ Server initializes successfully
   Loaded models: ['model.system.openai-gpt-o3-simpletext', 'model.system.openai-gpt-o3-simpleimage']
🧪 Testing server endpoints...
   ✅ Health endpoint works
   ✅ Invalid request properly rejected
   ✅ Unsupported model properly rejected
✅ All endpoint tests passed

🎉 All tests passed!
```

### Docker Tests
```
🧪 Testing DTN AI Server Docker Image...
✅ Image found: dtn-ai-server:latest
📊 Image size:
REPOSITORY        TAG     SIZE
dtn-ai-server     latest  156MB
🚀 Starting container...
✅ Container is running
⏳ Waiting for server to be ready...
✅ Server is ready!
🏥 Testing health endpoint...
Health response: {"status": "healthy", "models": ["model.system.openai-gpt-o3-simpletext", "model.system.openai-gpt-o3-simpleimage"]}
✅ Health check passed
🔍 Testing API endpoint with invalid request...
✅ Invalid request properly rejected (400)
🔍 Testing API endpoint with unsupported model...
✅ Unsupported model properly rejected (400)
🔄 Testing container restart...
✅ Container restart successful
🎉 All tests passed!
```

## 🔧 Configuration

### Environment Variables

- `OPENAI_API_KEY` (required) - Your OpenAI API key
- `PORT` (optional) - Server port (default: 8026)

### Configuration File

The `config.yaml` file maps model names to processor modules:

```yaml
models:
  - model: "model.system.openai-gpt-o3-simpletext"
    processor: "processor_gpt_o3"
  - model: "model.system.openai-gpt-o3-simpleimage"
    processor: "processor_gpt_o3"
```

## 🏥 Health Monitoring

The container includes health checks that verify the server is responding:

```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' dtn-ai-server

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' dtn-ai-server
```

## 📈 Resource Usage

The docker-compose file includes resource limits:

- **Memory**: 256MB-512MB
- **CPU**: 0.5-1.0 cores

Monitor resource usage:

```bash
docker stats dtn-ai-server
```

## 🔒 Security Features

- Runs as non-root user (`dtn`)
- Minimal runtime dependencies
- Read-only config mount in docker-compose
- Alpine Linux base for reduced attack surface

## 🐛 Troubleshooting

### Common Issues

1. **Container fails to start**
   ```bash
   docker logs dtn-ai-server
   ```

2. **Missing API key**
   ```bash
   export OPENAI_API_KEY=your_api_key
   docker-compose up -d
   ```

3. **Port already in use**
   ```bash
   # Change port in docker-compose.yml or use different port
   docker run -p 8027:8026 dtn-ai-server:latest
   ```

4. **Permission issues**
   ```bash
   # Ensure build script is executable
   chmod +x build.sh test_docker.sh
   ```

### Logs

```bash
# View container logs
docker logs dtn-ai-server

# Follow logs in real-time
docker logs -f dtn-ai-server

# View last 50 lines
docker logs --tail 50 dtn-ai-server
```

## 📝 API Usage

### Health Check
```bash
curl http://localhost:8026/health
```

### Text Generation
```bash
curl -X POST http://localhost:8026/api/request \
  -H "Content-Type: application/json" \
  -d '{
    "requestId": "req123",
    "model": "model.system.openai-gpt-o3-simpletext",
    "call": {
      "parameters": ["Generate a short story about a robot"],
      "types": ["string"]
    }
  }'
```

### Image Generation
```bash
curl -X POST http://localhost:8026/api/request \
  -H "Content-Type: application/json" \
  -d '{
    "requestId": "req456",
    "model": "model.system.openai-gpt-o3-simpleimage",
    "call": {
      "parameters": ["A beautiful sunset over mountains"],
      "types": ["string"]
    }
  }'
```

## 🎯 Production Deployment

For production deployment, consider:

1. **Environment variables**: Use secrets management
2. **Logging**: Configure structured logging
3. **Monitoring**: Set up metrics collection
4. **Scaling**: Use orchestration tools (Kubernetes, Docker Swarm)
5. **Backup**: Regular configuration backups

```bash
# Production example with secrets
docker run -d \
  --name dtn-ai-server \
  -p 8026:8026 \
  --env-file .env \
  --restart unless-stopped \
  --memory=512m \
  --cpus=1.0 \
  dtn-ai-server:latest
``` 