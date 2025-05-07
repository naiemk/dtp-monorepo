// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IModelManager
 * @notice Interface for managing AI models and their namespaces
 */
interface IModelManager {
    /// Events
    event ModelNamespaceRegistered(string namespace, address owner);
    event ModelAPIRegistered(string namespace, string api, string docs);
    event ModelRegistered(string namespace, string modelName, bytes32 modelId);

    /// Errors
    error NamespaceNotFound(string namespace);
    error NamespaceAlreadyExists(string namespace);
    error UnauthorizedNamespaceAccess(string namespace);
    error InvalidModelName(string modelName);

    /// @notice Register a new model namespace
    /// @param namespace The namespace to register
    function registerModelNamespace(string memory namespace) external;

    /// @notice Register a model API for a namespace
    /// @param namespace The namespace the API belongs to
    /// @param api The API specification
    /// @param docs Documentation for the API
    function registerModelAPI(string memory namespace, string memory api, string memory docs) external;

    /// @notice Register a new model in a namespace
    /// @param namespace The namespace to register the model in
    /// @param modelName The name of the model
    /// @return modelId The unique identifier for the model
    function registerModel(string memory namespace, string memory modelName) external returns (bytes32);

    /// @notice Get a model's ID by its full name (namespace.modelName)
    /// @param modelName The full model name (e.g., "system.models.openai.gpt-4")
    /// @return The model ID
    function modelId(string memory modelName) external view returns (bytes32);
}
