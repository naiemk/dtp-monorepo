// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDtnAiModels {
    function modelId(string memory modelName) external view returns (bytes32);
}

/**
 * @title IDtnAi
 * @notice Interface for DtnAI, defining the core AI interaction methods
 */
interface IDtnAi is IDtnAiModels {
    /**
     * @notice Represents different types of AI call responses
     */
    enum CallType {
        IPFS,      // Response will be stored on IPFS
        DIRECT     // Response will be returned directly
    }

    enum AggregationType {
        ANY,
        ALL,
        SELECT_BEST,
        VOTE,
        RANK
    }

    /**
     * @notice Structure for AI request parameters
     */
    struct DtnRequest {
        bytes call;     // Encoded call data
        CallType calltype;  // Type of response expected
        uint256 feePerByteReq; // Fee per byte for request size
        uint256 feePerByteRes; // Fee per byte for response size
        uint256 totalFeePerRes; // Maximum total fee for response
    }

    struct DtnRouting {
        bytes32[] trustNamespaceIds;
        bytes32[] trustedNodeIds; // Allows to specify a list of trusted nodes to answer the request
        uint32 redundancy; // How many nodes will answer the same request
        uint8 confidenceLevel; // 0 - 10
        AggregationType aggregationType;
    }

    /**
     * @notice Structure for AI response
     */
    struct Response {
        uint256 status;      // Response status code
        string message;      // Additional message or error details
        string response;     // The actual response data
        bytes32 nodeId;      // ID of the node that provided the response
        uint256 timestamp;   // When the response was provided
    }

    /**
     * @notice Callback structure for handling AI responses
     */
    struct CallBack {
        address target;     // Contract to call back
        bytes4 success;     // Function selector for successful response
        bytes4 failure;     // Function selector for failed response
    }

    /**
     * @notice Starts a new user session with specified token amount
     * @param amount Amount of tokens to allocate for the session
     * @return sessionId Unique identifier for the created session
     */
    function startUserSession(uint256 amount) external returns (uint256 sessionId);

    /**
     * @notice Closes an active user session
     * @param sessionId ID of the session to close
     */
    function closeUserSession(uint256 sessionId) external;

    /**
     * @notice Makes an AI request
     * @param sessionId Active session ID
     * @param modelId ID of the AI model to use
     * @param routingSystem Routing system configuration
     * @param dtnRequest Request parameters including call data and type
     * @param callback Callback information for handling response
     * @param user Address of the user making the request
     * @param callbackGas Gas limit for callback execution
     * @return requestId Unique identifier for the request
     */
    function request(
        uint256 sessionId,
        bytes32 modelId,
        IDtnAi.DtnRouting memory routingSystem,
        IDtnAi.DtnRequest memory dtnRequest,
        IDtnAi.CallBack memory callback,
        address user,
        uint256 callbackGas
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Fetches the response from the last AI request
     * @return status Response status
     * @return message Additional message or error details
     * @return response The actual response data
     */
    function fetchResponse(bytes32 requestId) external view returns (
        uint256 status,
        string memory message,
        string memory response
    );

    /**
     * @notice Responds to an AI request
     * @param requestId The ID of the request to respond to
     * @param status The status of the response (0 for success)
     * @param message Additional message or error details
     * @param response The actual response data
     * @param nodeId The ID of the responding node
     * @param requestSize Size of request in bytes
     * @param responseSize Size of response in bytes
     */
    function respondToRequest(
        bytes32 requestId,
        uint256 status,
        string memory message,
        string memory response,
        bytes32 nodeId,
        uint256 requestSize,
        uint256 responseSize
    ) external;
}
