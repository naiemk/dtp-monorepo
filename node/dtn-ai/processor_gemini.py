"""Gemini Processor Module
Handles text generation requests for Google Gemini models with web grounding."""

import logging
import os
from typing import List, Tuple, Any, Optional

import google.generativeai as genai
from google.api_core.exceptions import GoogleAPIError

logger = logging.getLogger(__name__)

class ApiError(Exception):
    """Custom exception for API errors"""
    def __init__(self, message: str, error_code: Optional[str] = None):
        self.message = message
        self.error_code = error_code
        super().__init__(self.message)

def _translate_model_name(model: str) -> str:
    """Translate internal model name to Gemini model name"""
    if "google-gemini-2_5-pro" in model:
        return "models/gemini-2.0-pro"
    if "google-gemini-2_5-flash-lite" in model:
        return "models/gemini-2.0-flash-lite"
    if "google-gemini-2_5-flash" in model:
        return "models/gemini-2.0-flash"
    raise ValueError(f"Unknown model name: {model}")

def _get_gemini_model(model_name: str) -> genai.GenerativeModel:
    """Configure API key and return GenerativeModel with search tool"""
    api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ApiError("GOOGLE_API_KEY environment variable is required", "MISSING_API_KEY")
    genai.configure(api_key=api_key)
    tool = genai.protos.Tool(google_search_retrieval=genai.protos.GoogleSearchRetrieval())
    return genai.GenerativeModel(model_name, tools=[tool])

def execute_call(model: str, parameters: List[Any], types: List[str]) -> Tuple[Any, str]:
    """Execute a call to the Gemini model"""
    logger.info(f"Processing {model} with parameters: {parameters}, types: {types}")
    return _handle_text_generation(parameters, model, types)

def _handle_text_generation(parameters: List[Any], model: str, types: List[str]) -> Tuple[str, str]:
    """Handle text generation requests"""
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
        gemini_model = _get_gemini_model(_translate_model_name(model))
        response = gemini_model.generate_content(prompt)
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
