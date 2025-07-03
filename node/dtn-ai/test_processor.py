#!/usr/bin/env python3
"""
Test script for the updated GPT-O3 processor
Tests the processor module directly without requiring API keys
"""

import os
import sys
from processor_gpt_o3 import execute_call

def test_processor_without_api_key():
    """Test processor behavior when no API key is available"""
    print("Testing GPT-O3 processor without API key...")
    print("=" * 50)
    
    # Test text generation (should fallback to mock)
    print("\n1. Testing text generation:")
    try:
        result, result_type = execute_call(
            "model.system.openai-gpt-o3-simpletext",
            ["What is the capital of France?"],
            ["string"]
        )
        print(f"✅ Text generation successful")
        print(f"   Result type: {result_type}")
        print(f"   Result preview: {result[:100]}...")
    except Exception as e:
        print(f"❌ Text generation failed: {e}")
    
    # Test image generation (should fallback to mock)
    print("\n2. Testing image generation:")
    try:
        result, result_type = execute_call(
            "model.system.openai-gpt-o3-simpleimage",
            ["A beautiful sunset over mountains", 1024, 1024],
            ["string", "uint64", "uint64"]
        )
        print(f"✅ Image generation successful")
        print(f"   Result type: {result_type}")
        print(f"   Base64 data length: {len(result)}")
    except Exception as e:
        print(f"❌ Image generation failed: {e}")
    
    # Test invalid model
    print("\n3. Testing invalid model:")
    try:
        result, result_type = execute_call(
            "model.system.invalid-model",
            ["test"],
            ["string"]
        )
        print(f"❌ Invalid model should have failed")
    except Exception as e:
        print(f"✅ Invalid model correctly rejected: {e}")
    
    # Test parameter validation
    print("\n4. Testing parameter validation:")
    try:
        result, result_type = execute_call(
            "model.system.openai-gpt-o3-simpletext",
            [],  # Empty parameters
            []
        )
        print(f"❌ Empty parameters should have failed")
    except Exception as e:
        print(f"✅ Parameter validation working: {e}")

def test_processor_with_api_key():
    """Test processor with API key (if available)"""
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        print("\n" + "=" * 50)
        print("No OPENAI_API_KEY found. To test with real API:")
        print("export OPENAI_API_KEY='your-api-key-here'")
        print("Then run this test again.")
        return
    
    print("\n" + "=" * 50)
    print("Testing GPT-O3 processor with API key...")
    print("=" * 50)
    
    # Test real text generation
    print("\n1. Testing real text generation:")
    try:
        result, result_type = execute_call(
            "model.system.openai-gpt-o3-simpletext",
            ["Explain quantum computing in simple terms"],
            ["string"]
        )
        print(f"✅ Real text generation successful")
        print(f"   Result type: {result_type}")
        print(f"   Result: {result}")
    except Exception as e:
        print(f"❌ Real text generation failed: {e}")
    
    # Test real image generation
    print("\n2. Testing real image generation:")
    try:
        result, result_type = execute_call(
            "model.system.openai-gpt-o3-simpleimage",
            ["A futuristic city skyline at sunset", 1024, 1024],
            ["string", "uint64", "uint64"]
        )
        print(f"✅ Real image generation successful")
        print(f"   Result type: {result_type}")
        print(f"   Base64 data length: {len(result)}")
        print(f"   First 50 chars: {result[:50]}...")
    except Exception as e:
        print(f"❌ Real image generation failed: {e}")

if __name__ == "__main__":
    print("GPT-O3 Processor Test Suite")
    print("=" * 50)
    
    # Test without API key first
    test_processor_without_api_key()
    
    # Test with API key if available
    test_processor_with_api_key()
    
    print("\n" + "=" * 50)
    print("Test suite completed!") 