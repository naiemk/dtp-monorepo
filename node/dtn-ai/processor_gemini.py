"""Gemini Processor Module
Handles text generation requests for Google Gemini models with search grounding."""

import logging
import os
from typing import List, Tuple, Any, Optional

# Use the standard import
import google.generativeai as genai

# ONLY import Tool from google.generativeai.types
from google.generativeai.types import Tool
from google.api_core.exceptions import GoogleAPIError

logger = logging.getLogger(__name__)

# --- Your ApiError class and other functions remain the same ---
class ApiError(Exception):
    def __init__(self, message: str, error_code: Optional[str] = None):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)

def _translate_model_name(model: str) -> str:
    if "google-gemini-1_5-pro" in model:
        return "models/gemini-1.5-pro-latest"
    if "google-gemini-1_5-flash" in model:
        return "models/gemini-1.5-flash-latest"
    if "google-gemini-2_5-pro" in model:
        return "models/gemini-2.5-pro"
    if "google-gemini-2_5-flash-lite" in model:
        return "models/gemini-2.5-flash-lite"
    if "google-gemini-2_5-flash" in model:
        return "models/gemini-2.5-flash"
    raise ValueError(f"Unknown model name: {model}")

def execute_call(model: str, parameters: List[Any], types: List[str]) -> Tuple[Any, str]:
    logger.info(f"Processing {model} with parameters: {parameters}, types: {types}")
    return _handle_text_generation(parameters, model, types)

def _handle_text_generation(parameters: List[Any], model: str, types: List[str]) -> Tuple[str, str]:
    """Handle text generation requests"""
    # ... (parameter checking logic is unchanged) ...
    if len(parameters) < 1:
        raise ApiError("Text generation requires at least 1 parameter (prompt)", "INVALID_PARAMETERS")
    parameter = parameters[0]
    if len(types) < 1 or (types[0] != "string" and types[0] != "string[]"):
        raise ApiError("First parameter must be a string or string[] (prompt)", "INVALID_PARAMETERS")

    if isinstance(parameter, list):
        prompt = "\n".join(parameter)
    else:
        prompt = parameter
    logger.info(f"Prompt: \n====== \n{prompt}\n======")

    try:
        model_name = _translate_model_name(model)
        gemini_model = genai.GenerativeModel(
            model_name=model_name
        )

        # The definitive, correct way to enable Google Search
        search_tool = Tool(google_search_retrieval={})
        tools = [search_tool] if "1.5" in model_name else [] # 2.5 does not support search yet
        
        response = gemini_model.generate_content(
            contents=prompt,
            tools=tools
        )
        
        generated_text = getattr(response, "text", None)
        if not generated_text:
            raise ApiError("No response generated from Gemini API", "NO_RESPONSE")
        return generated_text, "string"
    except GoogleAPIError as e:
        logger.error(f"Gemini API error for text generation: {e}")
        raise ApiError(f"Text generation failed: {str(e)}", "TEXT_GENERATION_ERROR")
    except Exception as e:
        logger.error(f"Unexpected error from Gemini: {e}")
        raise ApiError(f"Text generation failed: {str(e)}", "TEXT_GENERATION_ERROR")