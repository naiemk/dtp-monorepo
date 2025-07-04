#!/usr/bin/env python3
"""
DTN AI Server Node - Python HTTP Server
Serves AI model requests asynchronously on port 8026
"""

import asyncio
import json
import logging
import os
import sys
from typing import Dict, Any, Tuple, Optional
from aiohttp import web, ClientSession
import yaml

# Import the ApiError from processor module
try:
    from processor_gpt_o3 import ApiError as ProcessorApiError
except ImportError:
    # Fallback if processor module is not available
    class ProcessorApiError(Exception):
        def __init__(self, message: str, error_code: Optional[str] = None):
            self.message = message
            self.error_code = error_code
            super().__init__(self.message)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DTNAIServer:
    def __init__(self, config_path: str = "config.yaml"):
        self.config_path = config_path
        self.config = self.load_config()
        self.processors = {}
        self.load_processors()
    
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                config = yaml.safe_load(f)
            logger.info(f"Loaded configuration: {config}")
            return config
        except FileNotFoundError:
            logger.error(f"Config file {self.config_path} not found")
            sys.exit(1)
        except yaml.YAMLError as e:
            logger.error(f"Error parsing config file: {e}")
            sys.exit(1)
    
    def load_processors(self):
        """Dynamically load processor modules based on config"""
        for model_config in self.config.get('models', []):
            model_name = model_config.get('model')
            processor_name = model_config.get('processor')
            
            if not model_name or not processor_name:
                logger.warning(f"Invalid model config: {model_config}")
                continue
            
            try:
                # Import processor module
                processor_module = __import__(processor_name, fromlist=['execute_call'])
                self.processors[model_name] = processor_module
                logger.info(f"Loaded processor {processor_name} for model {model_name}")
            except ImportError as e:
                logger.error(f"Failed to load processor {processor_name} for model {model_name}: {e}")
    
    async def handle_request(self, request: web.Request) -> web.Response:
        """Handle incoming AI model requests"""
        try:
            # Parse request body
            body = await request.json()
            
            # Validate request structure
            required_fields = ['requestId', 'model', 'call']
            for field in required_fields:
                if field not in body:
                    return web.json_response({
                        'requestId': body.get('requestId', 'unknown'),
                        'data': '',
                        'datatype': '',
                        'error': f'Missing required field: {field}'
                    }, status=400)
            
            request_id = body['requestId']
            model_name = body['model']
            call_data = body['call']
            
            # Validate call structure
            if 'parameters' not in call_data or 'types' not in call_data:
                return web.json_response({
                    'requestId': request_id,
                    'data': '',
                    'datatype': '',
                    'error': 'Call must contain parameters and types'
                }, status=400)
            
            parameters = call_data['parameters']
            types = call_data['types']
            
            logger.info(f"Processing request {request_id} for model {model_name}")
            
            # Check if model is supported
            if model_name not in self.processors:
                return web.json_response({
                    'requestId': request_id,
                    'data': '',
                    'datatype': '',
                    'error': f'Model {model_name} not supported'
                }, status=400)
            
            # Process request asynchronously
            try:
                processor = self.processors[model_name]
                result, result_type = await asyncio.to_thread(
                    processor.execute_call, 
                    model_name, 
                    parameters, 
                    types
                )
                
                return web.json_response({
                    'requestId': request_id,
                    'data': result,
                    'datatype': result_type,
                    'error': ''
                })
                
            except ProcessorApiError as e:
                logger.error(f"API error processing request {request_id}: {e.message}")
                return web.json_response({
                    'requestId': request_id,
                    'data': '',
                    'datatype': '',
                    'error': e.message
                }, status=400)
                
            except Exception as e:
                logger.error(f"Error processing request {request_id}: {e}")
                return web.json_response({
                    'requestId': request_id,
                    'data': '',
                    'datatype': '',
                    'error': f'Processing error: {str(e)}'
                }, status=500)
                
        except json.JSONDecodeError:
            return web.json_response({
                'requestId': 'unknown',
                'data': '',
                'datatype': '',
                'error': 'Invalid JSON in request body'
            }, status=400)
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return web.json_response({
                'requestId': 'unknown',
                'data': '',
                'datatype': '',
                'error': f'Server error: {str(e)}'
            }, status=500)
    
    async def health_check(self, request: web.Request) -> web.Response:
        """Health check endpoint"""
        return web.json_response({
            'status': 'healthy',
            'models': list(self.processors.keys())
        })

def main():
    """Main server entry point"""
    # Get port from environment or default to 8026
    port = int(os.getenv('PORT', 8026))
    
    # Initialize server
    server = DTNAIServer()
    
    # Create web application
    app = web.Application()
    
    # Add routes
    app.router.add_post('/api/request', server.handle_request)
    app.router.add_get('/health', server.health_check)
    
    # Start server
    logger.info(f"Starting DTN AI Server on port {port}")
    web.run_app(app, port=port, host='0.0.0.0')

if __name__ == '__main__':
    main() 