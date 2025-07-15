# Request Format Guide

This guide explains how to understand model APIs and create different types of requests for the DTN (Decentralized Trust Network) system.

## Quick Reference Table

| Request Type | Model API | Example |
|-------------|-----------|---------|
| Simple Text | `string, uint64, uint64 -> bytes` | `"Test", 1, 2` |
| Placeholder Substitution | `string, bool -> bytes` | `"This {0} is {1:uint}?", false` |
| Array with Placeholders | `string[], uint256 -> bytes` | `["Hello {0}", "World {1:uint}"], 100` |
| Multiple Placeholders | `string, uint256 -> bytes` | `"Hello {0}, you are {1} years old", 100` |
| Complex Types | `uint256, bool -> bytes` | `123, true` |

## Understanding Model APIs

A model API defines the interface for interacting with an AI model. It consists of:

1. **Input Parameters**: The data types and structure of parameters the model expects
2. **Output Type**: The data type the model returns
3. **Documentation**: Human-readable description of what the model does

### API Specification Format

The API specification follows this pattern:
```
input_type1, input_type2, ... -> output_type
```

Common input types include:
- `string` - Text data
- `uint256` - Unsigned integer (256-bit)
- `uint64` - Unsigned integer (64-bit)
- `bool` - Boolean value (true/false)
- `address` - Ethereum address
- `string[]` - Array of strings
- `uint256[]` - Array of integers

## Creating Requests

### 1. Simple Parameters (No Placeholders)

When your request doesn't need dynamic substitution, you can pass parameters directly:

```solidity
// Model API: "string, uint64, uint64 -> bytes"
// This model takes a string and two numbers, returns bytes

function createSimpleRequest() external {
    // Encode the parameters
    bytes memory callData = abi.encode(
        "Test",    // string parameter
        1,         // uint64 parameter  
        2          // uint64 parameter
    );
    
    // Create the request
    RouterRequest memory request = RouterRequest({
        modelId: "your-model-id",
        request: DtnRequest({
            call: callData,
            extraParams: "",  // Empty since no placeholders
            calltype: 0,
            feePerByteReq: 1000,
            feePerByteRes: 1000,
            totalFeePerRes: 1000000
        })
        // ... other fields
    });
}
```

### 2. Parameters with Placeholder Substitution

Placeholders allow you to dynamically insert values into your request. Use the format `{index:type}` or just `{index}` for string type.

```solidity
// Model API: "string, bool -> bytes"
// This model takes a string with placeholders and a boolean

function createPlaceholderRequest() external {
    // The string contains placeholders that will be replaced
    bytes memory callData = abi.encode(
        "This {0} is {1:uint} and {0} then {2:address}?",  // Placeholders: {0}, {1:uint}, {2:address}
        false  // boolean parameter
    );
    
    // Extra parameters that will replace the placeholders
    bytes memory extraParams = abi.encode(
        "mystr",     // Replaces {0}
        12,          // Replaces {1:uint}
        0x1234567890123456789012345678901234567890  // Replaces {2:address}
    );
    
    RouterRequest memory request = RouterRequest({
        modelId: "your-model-id",
        request: DtnRequest({
            call: callData,
            extraParams: extraParams,
            calltype: 0,
            feePerByteReq: 1000,
            feePerByteRes: 1000,
            totalFeePerRes: 1000000
        })
        // ... other fields
    });
}
```

### 3. Array Parameters with Placeholders

You can use placeholders within arrays:

```solidity
// Model API: "string[], uint256 -> bytes"
// This model takes an array of strings (with placeholders) and a number

function createArrayRequest() external {
    // Array with placeholders in each element
    string[] memory messages = new string[](2);
    messages[0] = "Hello {0}";
    messages[1] = "World {1:uint}";
    
    bytes memory callData = abi.encode(
        messages,  // string[] with placeholders
        100        // uint256 parameter
    );
    
    // Extra parameters for placeholder replacement
    bytes memory extraParams = abi.encode(
        "Alice",  // Replaces {0}
        42        // Replaces {1:uint}
    );
    
    RouterRequest memory request = RouterRequest({
        modelId: "your-model-id",
        request: DtnRequest({
            call: callData,
            extraParams: extraParams,
            calltype: 0,
            feePerByteReq: 1000,
            feePerByteRes: 1000,
            totalFeePerRes: 1000000
        })
        // ... other fields
    });
}
```

### 4. Multiple Placeholders in Same String

You can have multiple placeholders in a single string, and reuse the same placeholder:

```solidity
// Model API: "string, uint256 -> bytes"
// This model takes a string with multiple placeholders and a number

function createMultiPlaceholderRequest() external {
    // String with multiple placeholders, including reused ones
    bytes memory callData = abi.encode(
        "Hello {0}, you are {1} years old and live at {2:address}",  // Multiple placeholders
        100  // uint256 parameter
    );
    
    // Extra parameters for all placeholders
    bytes memory extraParams = abi.encode(
        "Alice",  // Replaces {0}
        "25",     // Replaces {1} (string type by default)
        0x1234567890123456789012345678901234567890  // Replaces {2:address}
    );
    
    RouterRequest memory request = RouterRequest({
        modelId: "your-model-id",
        request: DtnRequest({
            call: callData,
            extraParams: extraParams,
            calltype: 0,
            feePerByteReq: 1000,
            feePerByteRes: 1000,
            totalFeePerRes: 1000000
        })
        // ... other fields
    });
}
```

### 5. Complex Data Types

You can work with more complex data structures:

```solidity
// Model API: "uint256, bool -> bytes"
// This model takes a number and a boolean

function createComplexTypeRequest() external {
    bytes memory callData = abi.encode(
        123,   // uint256 parameter
        true   // bool parameter
    );
    
    RouterRequest memory request = RouterRequest({
        modelId: "your-model-id",
        request: DtnRequest({
            call: callData,
            extraParams: "",  // No placeholders needed
            calltype: 0,
            feePerByteReq: 1000,
            feePerByteRes: 1000,
            totalFeePerRes: 1000000
        })
        // ... other fields
    });
}
```

## Placeholder Syntax

### Basic Placeholders
- `{0}` - Uses string type by default
- `{1}` - Uses string type by default
- `{2}` - Uses string type by default

### Typed Placeholders
- `{0:uint}` - Unsigned integer
- `{1:address}` - Ethereum address
- `{2:bool}` - Boolean value
- `{3:uint256}` - 256-bit unsigned integer

### Placeholder Rules
1. **Index-based**: Placeholders are replaced by index (0, 1, 2, etc.)
2. **Type specification**: Use `{index:type}` to specify the data type
3. **Default type**: If no type is specified, `string` is used
4. **Reuse**: You can reuse the same placeholder multiple times in a string
5. **Order**: Extra parameters must be provided in the order of their indices

## Complete Example Contract

Here's a complete example showing how to create different types of requests:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RequestExamples {
    
    struct DtnRequest {
        bytes call;
        bytes extraParams;
        uint8 calltype;
        uint256 feePerByteReq;
        uint256 feePerByteRes;
        uint256 totalFeePerRes;
    }
    
    struct RouterRequest {
        uint256 sessionId;
        address user;
        bool completed;
        bytes32 modelId;
        DtnRequest request;
        // ... other fields omitted for brevity
    }
    
    // Example 1: Simple text generation
    function createTextGenerationRequest() external view returns (bytes memory) {
        bytes memory callData = abi.encode(
            "Generate a story about a brave knight",
            1000  // max tokens
        );
        
        return abi.encode(
            RouterRequest({
                modelId: "text-generation-model",
                request: DtnRequest({
                    call: callData,
                    extraParams: "",
                    calltype: 0,
                    feePerByteReq: 1000,
                    feePerByteRes: 1000,
                    totalFeePerRes: 1000000
                })
            })
        );
    }
    
    // Example 2: Personalized content with placeholders
    function createPersonalizedRequest(string memory userName, uint256 userAge) external view returns (bytes memory) {
        bytes memory callData = abi.encode(
            "Hello {0}, you are {1:uint} years old. Generate a personalized greeting.",
            true  // include emoji
        );
        
        bytes memory extraParams = abi.encode(
            userName,  // {0}
            userAge    // {1:uint}
        );
        
        return abi.encode(
            RouterRequest({
                modelId: "personalized-model",
                request: DtnRequest({
                    call: callData,
                    extraParams: extraParams,
                    calltype: 0,
                    feePerByteReq: 1000,
                    feePerByteRes: 1000,
                    totalFeePerRes: 1000000
                })
            })
        );
    }
    
    // Example 3: Multi-language support
    function createMultiLanguageRequest(string memory language, string[] memory keywords) external view returns (bytes memory) {
        bytes memory callData = abi.encode(
            "Translate to {0}: {1}",
            keywords,  // array of keywords
            500        // max length
        );
        
        bytes memory extraParams = abi.encode(
            language  // {0}
        );
        
        return abi.encode(
            RouterRequest({
                modelId: "translation-model",
                request: DtnRequest({
                    call: callData,
                    extraParams: extraParams,
                    calltype: 0,
                    feePerByteReq: 1000,
                    feePerByteRes: 1000,
                    totalFeePerRes: 1000000
                })
            })
        );
    }
}
```

## Best Practices

1. **Always specify types** for placeholders when possible to avoid ambiguity
2. **Use meaningful indices** and document the order of extra parameters
3. **Test your requests** with different parameter combinations
4. **Handle errors** when model APIs are not found
5. **Optimize gas usage** by minimizing the size of call data and extra parameters
6. **Validate inputs** before creating requests to ensure proper formatting

## Common Use Cases

- **Text Generation**: Create stories, articles, or creative content
- **Translation**: Convert text between different languages
- **Personalization**: Generate content tailored to specific users
- **Data Analysis**: Process and analyze structured data
- **Code Generation**: Generate code snippets or templates
- **Image Descriptions**: Generate descriptions for images (when supported)

This format provides a flexible and powerful way to interact with AI models while maintaining type safety and clear parameter substitution. 