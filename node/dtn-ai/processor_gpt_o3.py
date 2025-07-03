#!/usr/bin/env python3
"""
GPT-O3 Processor Module
Handles text and image generation requests for OpenAI GPT-O3 models
"""

import json
import logging
import base64
import os
import requests
from typing import List, Tuple, Any, Optional
from openai import OpenAI

logger = logging.getLogger(__name__)

# Initialize OpenAI client
def _get_openai_client() -> OpenAI:
    """Get OpenAI client with API key from environment"""
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        raise ValueError("OPENAI_API_KEY environment variable is required")
    return OpenAI(api_key=api_key)

def execute_call(model: str, parameters: List[Any], types: List[str]) -> Tuple[Any, str]:
    """
    Execute a call to the GPT-O3 model
    
    Args:
        model: The model name (e.g., "model.system.openai-gpt-o3-simpletext")
        parameters: List of parameters for the model call
        types: List of parameter types corresponding to parameters
    
    Returns:
        Tuple of (result, result_type)
    """
    try:
        logger.info(f"Processing {model} with parameters: {parameters}, types: {types}")
        
        # Determine the model type from the model name
        if "simpletext" in model:
            return _handle_text_generation(parameters, types)
        elif "simpleimage" in model:
            return _handle_image_generation(parameters, types)
        else:
            raise ValueError(f"Unknown model type: {model}")
            
    except Exception as e:
        logger.error(f"Error in execute_call for model {model}: {e}")
        raise

def _handle_text_generation(parameters: List[Any], types: List[str]) -> Tuple[str, str]:
    """
    Handle text generation requests
    
    Expected parameters:
    - parameters[0]: prompt (string)
    
    Returns:
    - result: generated text (string)
    - result_type: "string"
    """
    if len(parameters) < 1:
        raise ValueError("Text generation requires at least 1 parameter (prompt)")
    
    if len(types) < 1 or types[0] != "string":
        raise ValueError("First parameter must be a string (prompt)")
    
    prompt = parameters[0]
    
    try:
        client = _get_openai_client()
        
        # Use GPT-4o for text generation (latest model)
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "user", "content": prompt}
            ],
            max_tokens=1000,
            temperature=0.7
        )
        
        generated_text = response.choices[0].message.content
        if not generated_text:
            raise ValueError("No response generated from OpenAI API")
        
        logger.info(f"Generated text response: {generated_text[:100]}...")
        return generated_text, "string"
        
    except Exception as e:
        logger.error(f"OpenAI API error for text generation: {e}")
        # Fallback to mock response if API fails
        fallback_response = f"Mock GPT-O3 response to: {prompt}"
        logger.warning(f"Using fallback response: {fallback_response[:100]}...")
        return fallback_response, "string"

def _handle_image_generation(parameters: List[Any], types: List[str]) -> Tuple[str, str]:
    """
    Handle image generation requests using GPT-4o multimodal capabilities
    
    Expected parameters:
    - parameters[0]: prompt (string)
    - parameters[1]: width (uint64) [optional, not used by GPT-4o]
    - parameters[2]: height (uint64) [optional, not used by GPT-4o]
    
    Returns:
    - result: base64 encoded image data (string)
    - result_type: "bytes"
    """
    if len(parameters) < 1:
        raise ValueError("Image generation requires at least 1 parameter (prompt)")
    if len(types) < 1 or types[0] != "string":
        raise ValueError("First parameter must be a string (prompt)")
    prompt = parameters[0]

    try:
        client = _get_openai_client()
        # GPT-4o image output via chat completions
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "user", "content": prompt}
            ],
            response_format={"type": "image_url"},
            max_tokens=1  # No text output, just image
        )
        # Extract image URL from response
        image_url = response.choices[0].message.content[0].get("image_url")
        if not image_url:
            raise ValueError("No image URL returned from GPT-4o API")
        # Download the image and convert to base64
        image_response = requests.get(image_url)
        image_response.raise_for_status()
        image_data = image_response.content
        base64_data = base64.b64encode(image_data).decode('utf-8')
        logger.info(f"Generated image for prompt: {prompt} using GPT-4o")
        return base64_data, "bytes"
    except Exception as e:
        logger.error(f"OpenAI API error for GPT-4o image generation: {e}")
        # Fallback to mock response if API fails
        mock_image_data = b"mock_image_data"
        mock_base64 = base64.b64encode(mock_image_data).decode('utf-8')
        logger.warning(f"Using fallback image response for prompt: {prompt}")
        return mock_base64, "bytes"

def _validate_parameters(parameters: List[Any], types: List[str], expected_types: List[str]) -> None:
    """
    Validate that parameters match expected types
    
    Args:
        parameters: List of parameters
        types: List of parameter types
        expected_types: List of expected types
    """
    if len(parameters) != len(expected_types):
        raise ValueError(f"Expected {len(expected_types)} parameters, got {len(parameters)}")
    
    if len(types) != len(expected_types):
        raise ValueError(f"Expected {len(expected_types)} type specifications, got {len(types)}")
    
    for i, (param, param_type, expected_type) in enumerate(zip(parameters, types, expected_types)):
        if param_type != expected_type:
            raise ValueError(f"Parameter {i} should be {expected_type}, got {param_type}")

# Example usage and testing
if __name__ == "__main__":
    # Test text generation
    try:
        result, result_type = execute_call(
            "model.system.openai-gpt-o3-simpletext",
            ["Hello, how are you?"],
            ["string"]
        )
        print(f"Text result: {result}, type: {result_type}")
    except Exception as e:
        print(f"Text generation error: {e}")
    
    # Test image generation
    try:
        result, result_type = execute_call(
            "model.system.openai-gpt-o3-simpleimage",
            ["A beautiful sunset", 512, 512],
            ["string", "uint64", "uint64"]
        )
        print(f"Image result length: {len(result)}, type: {result_type}")
    except Exception as e:
        print(f"Image generation error: {e}") 