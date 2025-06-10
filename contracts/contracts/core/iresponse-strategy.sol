// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/idtn-ai.sol";

/**
 * @title IResponseStrategy
 * @notice Interface for response aggregation strategies
 */
interface IResponseStrategy {
    /**
     * @notice Extracts a single response from multiple responses based on the strategy
     * @param requestId The ID of the request
     * @param responses Array of responses to aggregate
     * @return The selected response based on the strategy
     */
    function extractSingleResponse(
        bytes32 requestId,
        IDtnAi.Response[] memory responses
    ) external view returns (IDtnAi.Response memory);
} 