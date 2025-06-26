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

    /// @notice Struct to store model API configuration
    struct ModelApi {
        bytes32 apiNamespaceId;
        string apiName;
        bytes32 apiId;
        string specs;
        string docs;
    }

    /// @notice Struct to store model serving configuration
    struct ModelConfig {
        bytes32 modelNamespaceId; // The namespace id of the model group
        bytes32 modelId;
        bytes32 modelApiId;
        string modelName;
    }

    /// @notice Register a model API for a namespace
    /// @param namespace The namespace the API belongs to
    /// @param apiName The API name
    /// @param specs The API specification
    /// @param docs Documentation for the API
    function registerModelAPI(string memory namespace, string memory apiName, string memory specs, string memory docs) external;

    /// @notice Register a new model in a namespace
    /// @param namespace The namespace to register the model in
    /// @param modelName The name of the model
    /// @param modelApi The API of the model
    /// @return modelId The unique identifier for the model
    function registerModel(string memory namespace, string memory modelName, string memory modelApi) external returns (bytes32);

    /// @notice Get the model API configuration
    /// @param apiId The unique identifier for the model API
    /// @return modelApi The model API configuration
    function getModelAPI(bytes32 apiId) external view returns (ModelApi memory);

    /// @notice Get the model configuration
    /// @param modelId The unique identifier for the model
    /// @return modelConfig The model configuration
    function getModelConfig(bytes32 modelId) external view returns (ModelConfig memory);

    /// @notice Check if a model exists
    /// @param modelId The unique identifier for the model
    /// @return exists True if the model exists, false otherwise
    function modelExists(bytes32 modelId) external view returns (bool);
}
