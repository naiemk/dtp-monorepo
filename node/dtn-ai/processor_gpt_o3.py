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
from openai import OpenAI, BadRequestError

logger = logging.getLogger(__name__)

def _translate_model_name(model: str) -> str:
    """Translate model name to OpenAI model name"""
    if "gpt-5" in model:
        return "gpt-5"
    elif "gpt-5-mini" in model:
        return "gpt-5-mini"
    elif "gpt-5-nano" in model:
        return "gpt-5-nano"
    elif "image" in model:
        return "gpt-image-1"
    else:
        raise ValueError(f"Unknown model name: {model}")

class ApiError(Exception):
    """Custom exception for API errors"""
    def __init__(self, message: str, error_code: Optional[str] = None):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)

# Initialize OpenAI client
def _get_openai_client() -> OpenAI:
    """Get OpenAI client with API key from environment"""
    api_key = os.getenv('OPENAI_API_KEY')
    if not api_key:
        raise ApiError("OPENAI_API_KEY environment variable is required", "MISSING_API_KEY")
    return OpenAI(api_key=api_key)


def _sanitize_prompt(prompt: str) -> str:
    """Sanitize a prompt using GPT to remove inappropriate words."""
    client = _get_openai_client()
    sanitize_instruction = (
        "You are a model sanitizer. Clean up the following text between {{{{START}}}} and "
        "{{{{END}}}} by removing every word that is very inappropriate and replace them with "
        "a random fruit. Don't change anything that is not inappropriate.\n\n"
        "Return only the modified text including all the instructions in the original text.\n\n"
        "{{START}}\n" + prompt + "\n{{END}}"
    )
    try:
        response = client.chat.completions.create(
            model="gpt-5-nano",
            messages=[{"role": "user", "content": sanitize_instruction}],
            max_completion_tokens=4000,
        )
        sanitized = response.choices[0].message.content
        if not sanitized:
            raise ApiError("Sanitizer returned empty text", "NO_SANITIZED_TEXT")
        logger.info("Sanitized prompt: %s", sanitized)
        return sanitized
    except Exception as e:
        logger.error("Failed to sanitize prompt: %s", e)
        return prompt


def _is_moderation_error(error: Exception) -> bool:
    """Check if an OpenAI error was caused by content policy violations."""
    code = getattr(error, "code", "")
    if code and "policy" in str(code).lower():
        return True
    body = getattr(error, "body", None)
    if isinstance(body, dict):
        err = body.get("error") or body
        if isinstance(err, dict):
            err_code = err.get("code")
            if err_code and "policy" in str(err_code).lower():
                return True
    if "policy" in str(error).lower() or "safety" in str(error).lower():
        return True
    return False

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
        if "gpt-5" in model:
            return _handle_text_generation(parameters, model,types)
        elif "image" in model:
            return _handle_image_generation(parameters, types)
        else:
            raise ValueError(f"Unknown model type: {model}")
            
    except Exception as e:
        logger.error(f"Error in execute_call for model {model}: {e}")
        raise

def _handle_text_generation(parameters: List[Any], model: str, types: List[str]) -> Tuple[str, str]:
    """
    Handle text generation requests
    
    Expected parameters:
    - parameters[0]: prompt (string), or (string[])
    
    Returns:
    - result: generated text (string)
    - result_type: "string"
    """
    if len(parameters) < 1:
        raise ApiError("Text generation requires at least 1 parameter (prompt)", "INVALID_PARAMETERS")
    parameter = parameters[0] # The only parameter which can be string[] or string

    if len(types) < 1 or (types[0] != "string" and types[0] != "string[]"):
        raise ApiError("First parameter must be a string or string[] (prompt)", "INVALID_PARAMETERS")
    
    if isinstance(parameter, list):
        prompt = "\n".join(parameter)
    else:
        prompt = parameter[0]
    logger.info(f"Prompt: \n====== \n{prompt}\n======")

    try:
        client = _get_openai_client()
        response = client.chat.completions.create(
            model=_translate_model_name(model),
            messages=[
                {"role": "user", "content": prompt}
            ],
            max_completion_tokens=40000,
        )
        
        generated_text = response.choices[0].message.content
        if not generated_text:
            raise ApiError("No response generated from OpenAI API", "NO_RESPONSE")
        
        logger.info(f"Generated text response: {generated_text[:100]}...")
        return generated_text, "string"
        
    except Exception as e:
        logger.error(f"OpenAI API error for text generation: {e}")
        raise ApiError(f"Text generation failed: {str(e)}", "TEXT_GENERATION_ERROR")

def _handle_image_generation(parameters: List[Any], types: List[str]) -> Tuple[str, str]:
    """
    Handle image generation requests using GPT-4o multimodal capabilities
    
    Expected parameters:
    - parameters[0]: prompt (string), or (string[])
    - parameters[1]: width (uint64) [optional, not used by GPT-4o]
    - parameters[2]: height (uint64) [optional, not used by GPT-4o]
    
    Returns:
    - result: base64 encoded image data (string)
    - result_type: "bytes"
    """
    if len(parameters) < 1:
        raise ApiError("Image generation requires at least 1 parameter (prompt)", "INVALID_PARAMETERS")
    parameter = parameters[0] # The only parameter which can be string[] or string

    if len(types) < 1 or (types[0] != "string" and types[0] != "string[]"):
        raise ApiError("First parameter must be a string or string[] (prompt)", "INVALID_PARAMETERS")
    
    if isinstance(parameter, list):
        prompt = "\n".join(parameter)
    else:
        prompt = parameter[0]
    logger.info(f"Prompt: \n====== \n{prompt}\n======")

    try:
        client = _get_openai_client()
        size = "1024x1024"

        def _generate(img_prompt: str) -> str:
            response = client.images.generate(
                model="gpt-image-1",
                prompt=img_prompt,
                n=1,
                size=size,
                moderation="low",
            )
            image_b64: str | None = response.data[0].b64_json if response.data else None
            if not image_b64:
                raise ApiError("No image data in gpt-image-1 response", "NO_IMAGE_DATA")
            return image_b64

        try:
            image_b64 = _generate(prompt)
        except BadRequestError as be:
            if _is_moderation_error(be):
                logger.info("Prompt rejected by moderation. Attempting sanitization.")
                sanitized = _sanitize_prompt(prompt)
                image_b64 = _generate(sanitized)
            else:
                raise

        logger.info("Generated image for prompt %r using gpt-image-1", prompt)
        return image_b64, "bytes"

    except Exception as e:
        logger.error("OpenAI API error during image generation: %s", e)
        raise ApiError(f"Image generation failed: {e}", "IMAGE_GENERATION_ERROR")

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