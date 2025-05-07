// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./imodel-manager.sol";

/**
 * @title ModelManager
 * @notice Manages model namespaces, APIs, and model registration
 */
contract ModelManagerUpgradeable is IModelManager, AccessControlUpgradeable {
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

    function registerModelAPI(
        string memory namespace,
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

    function registerModel(
        string memory namespace,
        string memory modelName
    ) external override returns (bytes32) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();

        if (!$.namespaceExists[namespace]) {
            revert NamespaceNotFound(namespace);
        }

        if ($.namespaceOwners[namespace] != msg.sender && !hasRole(NAMESPACE_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedNamespaceAccess(namespace);
        }

        string memory fullModelName = string.concat(namespace, ".", modelName);
        if (bytes(modelName).length == 0) {
            revert InvalidModelName(modelName);
        }

        bytes32 modelId = keccak256(abi.encodePacked(fullModelName));
        $.modelIds[fullModelName] = modelId;

        emit ModelRegistered(namespace, modelName, modelId);
        return modelId;
    }

    function modelId(string memory modelName) external view override returns (bytes32) {
        ModelManagerStorageV001 storage $ = getModelStorageV001();
        return $.modelIds[modelName];
    }
}
