// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IModelManager
 * @notice IModelManager is the interface for the ModelManager
 */
interface IModelManager {
    function modelId(string memory modelName) external view returns (bytes32);
}
