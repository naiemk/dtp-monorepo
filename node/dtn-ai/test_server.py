#!/usr/bin/env python3
"""
Test script for DTN AI Server
Tests the API endpoints with sample requests
"""

import asyncio
import json
import aiohttp
import sys

async def test_server():
    """Test the DTN AI server endpoints"""
    base_url = "http://localhost:8026"
    
    async with aiohttp.ClientSession() as session:
        # Test health check
        print("Testing health check...")
        try:
            async with session.get(f"{base_url}/health") as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"Health check passed: {data}")
                else:
                    print(f"Health check failed: {response.status}")
        except Exception as e:
            print(f"Health check error: {e}")
            return
        
        # Test text generation
        print("\nTesting text generation...")
        text_request = {
            "requestId": "test-001",
            "model": "model.system.openai-gpt-o3-simpletext",
            "call": {
                "parameters": ["Hello, how are you today?"],
                "types": ["string"]
            }
        }
        
        try:
            async with session.post(
                f"{base_url}/api/request",
                json=text_request,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"Text generation successful: {data}")
                else:
                    print(f"Text generation failed: {response.status}")
                    error_text = await response.text()
                    print(f"Error: {error_text}")
        except Exception as e:
            print(f"Text generation error: {e}")
        
        # Test image generation
        print("\nTesting image generation...")
        image_request = {
            "requestId": "test-002",
            "model": "model.system.openai-gpt-o3-simpleimage",
            "call": {
                "parameters": ["A beautiful sunset over mountains", 512, 512],
                "types": ["string", "uint64", "uint64"]
            }
        }
        
        try:
            async with session.post(
                f"{base_url}/api/request",
                json=image_request,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"Image generation successful: {data}")
                    if data.get('data'):
                        print(f"Image data length: {len(data['data'])}")
                else:
                    print(f"Image generation failed: {response.status}")
                    error_text = await response.text()
                    print(f"Error: {error_text}")
        except Exception as e:
            print(f"Image generation error: {e}")
        
        # Test invalid model
        print("\nTesting invalid model...")
        invalid_request = {
            "requestId": "test-003",
            "model": "model.system.invalid-model",
            "call": {
                "parameters": ["test"],
                "types": ["string"]
            }
        }
        
        try:
            async with session.post(
                f"{base_url}/api/request",
                json=invalid_request,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 400:
                    data = await response.json()
                    print(f"Invalid model handled correctly: {data}")
                else:
                    print(f"Invalid model test failed: {response.status}")
        except Exception as e:
            print(f"Invalid model test error: {e}")

if __name__ == "__main__":
    print("Starting DTN AI Server tests...")
    print("Make sure the server is running on port 8026")
    print("=" * 50)
    
    asyncio.run(test_server())
    
    print("\n" + "=" * 50)
    print("Tests completed!") 