#!/usr/bin/env python3
"""Integration test for the Gemini processor.
Requires a valid GOOGLE_API_KEY environment variable."""

import os
from processor_gemini import execute_call

def test_gemini_with_api_key():
    api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("No GOOGLE_API_KEY found. To run this test, set the environment variable:")
        print("export GOOGLE_API_KEY='your-api-key'")
        return

    model = "model.system.google-gemini-1_5-flash"

    result, result_type = execute_call(
        model,
        ["What is the latest BITCOIN price and at what time? Return only the price and time in the following format: [price, time]"],
        ["string"],
    )
    print("Result type:", result_type)
    print("Result:\n", result)

if __name__ == "__main__":
    test_gemini_with_api_key()
