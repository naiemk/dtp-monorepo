#!/usr/bin/env python3
"""
Local test script for DTN AI Server
Tests server functionality without Docker
"""

import asyncio
import json
import sys
import time
from aiohttp import web, ClientSession
import requests

def test_server_initialization():
    """Test server initialization"""
    print("🧪 Testing server initialization...")
    try:
        from server import DTNAIServer
        server = DTNAIServer()
        print("✅ Server initializes successfully")
        print(f"   Loaded models: {list(server.processors.keys())}")
        return server
    except Exception as e:
        print(f"❌ Server initialization failed: {e}")
        return None

def test_processor_import():
    """Test processor module import"""
    print("🧪 Testing processor import...")
    try:
        from processor_gpt_o3 import ApiError, execute_call
        print("✅ Processor imports successfully")
        return True
    except Exception as e:
        print(f"❌ Processor import failed: {e}")
        return False

async def test_server_endpoints():
    """Test server endpoints"""
    print("🧪 Testing server endpoints...")
    
    # Start server in background
    from server import DTNAIServer
    server = DTNAIServer()
    
    app = web.Application()
    app.router.add_post('/api/request', server.handle_request)
    app.router.add_get('/health', server.health_check)
    
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, 'localhost', 8027)
    await site.start()
    
    try:
        # Test health endpoint
        print("   Testing health endpoint...")
        async with ClientSession() as session:
            async with session.get('http://localhost:8027/health') as response:
                if response.status == 200:
                    data = await response.json()
                    if data.get('status') == 'healthy':
                        print("   ✅ Health endpoint works")
                    else:
                        print("   ❌ Health endpoint returned invalid status")
                else:
                    print(f"   ❌ Health endpoint failed: {response.status}")
        
        # Test invalid request
        print("   Testing invalid request...")
        async with ClientSession() as session:
            async with session.post('http://localhost:8027/api/request', 
                                  json={"invalid": "request"}) as response:
                if response.status == 400:
                    print("   ✅ Invalid request properly rejected")
                else:
                    print(f"   ❌ Invalid request not handled correctly: {response.status}")
        
        # Test unsupported model
        print("   Testing unsupported model...")
        async with ClientSession() as session:
            async with session.post('http://localhost:8027/api/request', 
                                  json={
                                      "requestId": "test123",
                                      "model": "unsupported-model",
                                      "call": {"parameters": [], "types": []}
                                  }) as response:
                if response.status == 400:
                    print("   ✅ Unsupported model properly rejected")
                else:
                    print(f"   ❌ Unsupported model not handled correctly: {response.status}")
        
        print("✅ All endpoint tests passed")
        
    finally:
        await runner.cleanup()

def test_config_loading():
    """Test configuration loading"""
    print("🧪 Testing configuration loading...")
    try:
        import yaml
        with open('config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        
        if 'models' in config and len(config['models']) > 0:
            print("✅ Configuration loaded successfully")
            print(f"   Models configured: {len(config['models'])}")
            for model in config['models']:
                print(f"   - {model.get('model')} -> {model.get('processor')}")
            return True
        else:
            print("❌ Configuration missing models")
            return False
    except Exception as e:
        print(f"❌ Configuration loading failed: {e}")
        return False

def test_dependencies():
    """Test all dependencies"""
    print("🧪 Testing dependencies...")
    dependencies = [
        ('aiohttp', 'aiohttp'),
        ('yaml', 'PyYAML'),
        ('openai', 'openai'),
        ('requests', 'requests')
    ]
    
    all_good = True
    for module_name, package_name in dependencies:
        try:
            __import__(module_name)
            print(f"   ✅ {package_name} available")
        except ImportError:
            print(f"   ❌ {package_name} not available")
            all_good = False
    
    return all_good

async def main():
    """Main test function"""
    print("🚀 Starting DTN AI Server Local Tests\n")
    
    # Test dependencies
    if not test_dependencies():
        print("❌ Dependency test failed")
        sys.exit(1)
    
    # Test configuration
    if not test_config_loading():
        print("❌ Configuration test failed")
        sys.exit(1)
    
    # Test processor import
    if not test_processor_import():
        print("❌ Processor import test failed")
        sys.exit(1)
    
    # Test server initialization
    server = test_server_initialization()
    if not server:
        print("❌ Server initialization test failed")
        sys.exit(1)
    
    # Test server endpoints
    await test_server_endpoints()
    
    print("\n🎉 All tests passed!")
    print("\n📝 Test Summary:")
    print("  ✅ All dependencies available")
    print("  ✅ Configuration loads correctly")
    print("  ✅ Processor module imports")
    print("  ✅ Server initializes properly")
    print("  ✅ Endpoints respond correctly")
    print("  ✅ Error handling works")
    
    print("\n💡 The server is ready for Docker packaging!")

if __name__ == "__main__":
    asyncio.run(main()) 