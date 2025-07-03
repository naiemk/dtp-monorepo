# DTN AI Server Setup Guide

## Overview
This is a Python HTTP server that serves AI model requests asynchronously on port 8026. It supports multiple models through a configurable processor system.

## Files Structure
```
node/dtn-ai/
├── server.py              # Main HTTP server
├── config.yaml            # Model configuration
├── processor_gpt_o3.py    # GPT-O3 processor module
├── requirements.txt       # Python dependencies
├── test_server.py         # Test script
├── README.md              # Original README
└── SETUP.md               # This setup guide
```

## Installation

1. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Verify installation:**
   ```bash
   python -c "import aiohttp, yaml; print('Dependencies installed successfully')"
   ```

## Configuration

The server uses `config.yaml` to map model names to their processor modules:

```yaml
models:
  - model: "model.system.openai-gpt-o3-simpletext"
    processor: "processor_gpt_o3"
  
  - model: "model.system.openai-gpt-o3-simpleimage"
    processor: "processor_gpt_o3"
```

## Running the Server

1. **Start the server:**
   ```bash
   python server.py
   ```

2. **Or with custom port:**
   ```bash
   PORT=8080 python server.py
   ```

3. **Verify server is running:**
   ```bash
   curl http://localhost:8026/health
   ```

## API Usage

### Health Check
```bash
GET /health
```

### Model Request
```bash
POST /api/request
Content-Type: application/json

{
    "requestId": "unique-request-id",
    "model": "model.system.openai-gpt-o3-simpletext",
    "call": {
        "parameters": ["Hello, how are you?"],
        "types": ["string"]
    }
}
```

### Response Format
```json
{
    "requestId": "unique-request-id",
    "data": "AI response data",
    "datatype": "string",
    "error": ""
}
```

## Testing

Run the test script to verify functionality:

```bash
python test_server.py
```

## Adding New Models

1. **Create a new processor module** (e.g., `processor_my_model.py`):
   ```python
   def execute_call(model: str, parameters: List[Any], types: List[str]) -> Tuple[Any, str]:
       # Your model logic here
       return result, result_type
   ```

2. **Add to config.yaml**:
   ```yaml
   models:
     - model: "model.system.my-new-model"
       processor: "processor_my_model"
   ```

3. **Restart the server**

## Error Handling

The server returns appropriate HTTP status codes:
- `200`: Success
- `400`: Bad request (missing fields, invalid model, etc.)
- `500`: Server error (processing errors)

## Docker Support

To run in Docker:

```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8026
CMD ["python", "server.py"]
```

## Environment Variables

- `PORT`: Server port (default: 8026)

## Logging

The server logs to stdout with INFO level. Check logs for:
- Configuration loading
- Model processor loading
- Request processing
- Errors and exceptions 