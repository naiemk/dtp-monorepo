// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./imodel-manager.sol";
import "hardhat/console.sol";
import "../utils/idtn-ai.sol";
import "../utils/namespace-utils.sol";
import "../core/inamespace-manager.sol";

/**
 * @title ModelManager
 * @notice Manages model APIs and model registration
 */
contract ModelManagerUpgradeable is IModelManager, AccessControlUpgradeable, IDtnAiModels {
    bytes32 public constant NAMESPACE_ADMIN_ROLE = keccak256("NAMESPACE_ADMIN_ROLE");

    /// @custom:storage-location erc7201:dtn.storage.modelmanager.001
    struct ModelManagerStorageV001 {
        // The namespace manager contract address
        address namespaceManager;
        // The router contract address
        address router;
        // API ID => Model API
        mapping(bytes32 => ModelApi) apisById;
        // Model ID => Model Config
        mapping(bytes32 => ModelConfig) modelsById;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.modelmanager.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ModelStorageV001Location = 0x317ad3d122488b64c2d86bf285bd2d0e9a7289d8b50201f32d6abb04fde8a300;

    function initialize(address owner) public initializer {
        __ModelManager_init(owner);
    }

    function __ModelManager_init(address owner) internal onlyInitializing {
        __AccessControl_init();
        __ModelManager_init_unchained(owner);
    }

    function __ModelManager_init_unchained(address owner) internal onlyInitializing {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(NAMESPACE_ADMIN_ROLE, owner);
    }

    function getModelStorageV001() internal pure returns (ModelManagerStorageV001 storage $) {
        assembly {
            $.slot := ModelStorageV001Location
        }
    }

    function _setDependencies(address _namespaceManager) internal virtual {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        $.namespaceManager = _namespaceManager;
    }

    /**
     * @notice Set the router address (only callable by admin)
     * @param _router The router contract address
     */
    function setRouter(address _router) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        $.router = _router;
    }


    /**
     * @notice Register a model API for a namespace
     * @param namespace The namespace the API belongs to
     * @param apiName The API name
     * @param specs The API specification
     * @param docs Documentation for the API
     */
    function registerModelAPI(
        string memory namespace,
        string memory apiName,
        string memory specs,
        string memory docs
    ) external override {
        ModelManagerStorageV001 storage $ = getModelStorageV001();

        // Check namespace ownership through namespace manager
        bytes32 namespaceId = keccak256(abi.encodePacked(namespace));
        address owner = INamespaceManager($.namespaceManager).getNamespaceOwner(namespaceId);
        if (owner != msg.sender && !hasRole(NAMESPACE_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedNamespaceAccess(namespace);
        }

        bytes32 apiId = keccak256(abi.encodePacked(namespace, ".", apiName));
        $.apisById[apiId] = ModelApi({
            apiNamespaceId: namespaceId,
            apiName: apiName,
            apiId: apiId,
            specs: specs,
            docs: docs
        });

        emit ModelAPIRegistered(namespace, apiName, docs);
    }

    /**
     * @notice Register a new model in a namespace
     * @param namespace The namespace to register the model in
     * @param modelName The name of the model
     * @return modelId The unique identifier for the model
     */
    function registerModel(
        string memory namespace,
        string memory modelName,
        string memory modelApi
    ) external override returns (bytes32) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();

        // Check namespace ownership through namespace manager
        bytes32 namespaceId = keccak256(abi.encodePacked(namespace));
        address owner = INamespaceManager($.namespaceManager).getNamespaceOwner(namespaceId);
        if (owner != msg.sender && !hasRole(NAMESPACE_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedNamespaceAccess(namespace);
        }

        string memory fullModelName = string.concat(namespace, ".", modelName);
        if (bytes(modelName).length == 0) {
            revert InvalidModelName(modelName);
        }

        bytes32 _modelId = keccak256(abi.encodePacked(fullModelName));
        $.modelsById[_modelId] = ModelConfig({
            modelNamespaceId: namespaceId,
            modelId: _modelId,
            modelApiId: keccak256(abi.encodePacked(modelApi)),
            modelName: fullModelName
        });

        emit ModelRegistered(namespace, modelName, _modelId);
        return _modelId;
    }

    /**
     * @notice Get the model API configuration
     * @param _modelId The unique identifier for the model
     * @return modelApi The model API configuration
     */
    function getModelAPI(bytes32 _modelId) external view override returns (ModelApi memory) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        bytes32 modelApiId = $.modelsById[_modelId].modelApiId;
        return $.apisById[modelApiId];
    }

    /**
     * @notice Get the model configuration
     * @param _modelId The unique identifier for the model
     * @return modelConfig The model configuration
     */
    function getModelConfig(bytes32 _modelId) external view override returns (ModelConfig memory) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        return $.modelsById[_modelId];
    }

    /**
     * @notice Check if a model exists
     * @param _modelId The unique identifier for the model
     * @return exists True if the model exists, false otherwise
     */
    function modelExists(bytes32 _modelId) external view override returns (bool) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        return $.modelsById[_modelId].modelId != bytes32(0);
    }

    /**
     * @notice Calculate the model ID from the full model name (namespace.modelName)
     * @param modelFullName The full model name in format namespace.modelName
     * @return The calculated model ID
     */
    function modelId(string memory modelFullName) external pure 
        override(IDtnAiModels) 
        returns (bytes32) 
    {
        return keccak256(abi.encodePacked(modelFullName));
    }
}
