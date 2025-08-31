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

    result, result_type = execute_call(
        "model.system.google-gemini-2_5-flash",
        ["Find a recent news headline about space exploration and cite the source URL."],
        ["string"],
    )
    print("Result type:", result_type)
    print("Result:\n", result)

if __name__ == "__main__":
    test_gemini_with_api_key()
