// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./imodel-manager.sol";
import "hardhat/console.sol";
import "../utils/idtn-ai.sol";
import "../utils/namespace-utils.sol";

/**
 * @title ModelManager
 * @notice Manages model namespaces, APIs, and model registration
 */
contract ModelManagerUpgradeable is IModelManager, AccessControlUpgradeable, IDtnAiModels {
    bytes32 public constant NAMESPACE_ADMIN_ROLE = keccak256("NAMESPACE_ADMIN_ROLE");

    /// @custom:storage-location erc7201:dtn.storage.modelmanager.001
    struct ModelManagerStorageV001 {
        // Namespace => owner
        mapping(string => address) namespaceOwners;
        // Namespace => exists
        mapping(string => bool) namespaceExists;
        // Namespace => API
        mapping(string => string) namespaceAPIs;
        // Namespace => API docs
        mapping(string => string) namespaceDocs;
        // Model name => model ID
        mapping(string => bytes32) modelIds;
        // Model ID => Model Config
        mapping(bytes32 => ModelConfig) modelConfigs;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.modelmanager.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ModelStorageV001Location = 0x317ad3d122488b64c2d86bf285bd2d0e9a7289d8b50201f32d6abb04fde8a300;

    function __ModelManager_init() internal onlyInitializing {
        __AccessControl_init();
        __ModelManager_init_unchained();
    }

    function __ModelManager_init_unchained() internal onlyInitializing {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(NAMESPACE_ADMIN_ROLE, msg.sender);
    }

    function getModelStorageV001() internal pure returns (ModelManagerStorageV001 storage $) {
        assembly {
            $.slot := ModelStorageV001Location
        }
    }

    function registerModelNamespace(string memory namespace) external override {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        
        if ($.namespaceExists[namespace]) {
            revert NamespaceAlreadyExists(namespace);
        }

        $.namespaceExists[namespace] = true;
        $.namespaceOwners[namespace] = msg.sender;

        emit ModelNamespaceRegistered(namespace, msg.sender);
    }

    /**
     * @notice Register an API in the model manager.
     * If the API is public, i.e. under namsepace system.models, only can be regiestered
     * by the model manager admin.
     * If the API is node-specific, only node owner can register it.
     * @param apiNamespace The namespace of the API
     * @param api The API name
     * @param docs The API docs
     */
    function registerModelAPI(
        string memory apiNamespace,
        string memory api,
        string memory docs
    ) external override {
        ModelManagerStorageV001 storage $ = getModelStorageV001();

        if (!$.namespaceExists[namespace]) {
            revert NamespaceNotFound(namespace);
        }

        if ($.namespaceOwners[namespace] != msg.sender && !hasRole(NAMESPACE_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedNamespaceAccess(namespace);
        }

        $.namespaceAPIs[namespace] = api;
        $.namespaceDocs[namespace] = docs;

        emit ModelAPIRegistered(namespace, api, docs);
    }

    /**
     * @notice Register a model in the model manager. Model is registered on a namespace,
     * and implements an API, which comes from an API namespace.
     * For example, a hypotetical fine-tuned DeepSeek model for arabic literature
     * api NS: system.models.deepseek
     * model NS: nodes.megadeonz
     * model name: deepseek-arabic-literature
     * @param apiNamespaceId The namespace id of the API that is registering the model
     * @param modelNamespaceId The namespace id of the model
     * @param modelName The name of the model
     */
    function registerModel(
        bytes32 apiNamespaceId,
        bytes32 modelNamespaceId,
        string memory modelName
    ) external override returns (bytes32) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();

        // Model can be registered on the node namespace, or a public one
        if (!isNodeNamespaceOwner(namespace, msg.sender) &&
            !hasRole(NAMESPACE_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedNamespaceAccess(namespace);
        }

        string memory fullModelName = string.concat(namespace, ".", modelName);
        if (bytes(modelName).length == 0) {
            revert InvalidModelName(modelName);
        }

        bytes32 _modelId = keccak256(abi.encodePacked(fullModelName));
        $.modelIds[fullModelName] = _modelId;
        $.modelConfigs[_modelId] = ModelConfig({
            modelNamespaceId: keccak256(abi.encodePacked(namespace)),
            modelId: _modelId,
            modelName: fullModelName,
            requestPricePerByte: 0,
            responsePricePerByte: 0
        });

        emit ModelRegistered(namespace, modelName, _modelId);
        return _modelId;
    }

    function modelId(string memory modelName) external view 
        override(IDtnAiModels) 
        returns (bytes32) 
    {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        return $.modelIds[modelName];
    }

    function isNodeNamespaceOwner(string memory namespace, address node
    ) external view returns (bool) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        (string memory namespace,) =
            NamespaceUtils.extractResourceNamespace(namespace);
        bytes32 nodeNamespaceId = keccak256(abi.encodePacked(namespace));
        // TODO: Check from the node-manager, to see if the namespace is a node id
        // return $.namespaceOwners[namespace] == node;
        return false;
    }
}
