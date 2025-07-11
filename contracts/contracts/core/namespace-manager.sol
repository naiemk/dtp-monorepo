// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./multiowner-base.sol";
import "./inamespace-manager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NamespaceManager is Initializable, UUPSUpgradeable, MultiOwnerBase, INamespaceManager {
    /// @custom:storage-location erc7201:dtn.core.namespacemanager.001
    struct NamespaceManagerStorageV001 {
        mapping(bytes32 => NamespaceConfig) namespaces;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.core.namespacemanager.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NamespaceManagerStorageV001Location = 0xa1a8a1e2cb6009f225580651017bd88c470975b96e9e7869a2efeb9cc01cfd00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        __NamespaceManager_init(_owner);
    }

    function __NamespaceManager_init(address _owner) internal onlyInitializing {
        __MultiOwnerBase_init(_owner);

        _registerNamespace("model.system", address(0));
        _registerNamespace("node.system", address(0));
        _registerNamespace("trust.system", address(0));
        _registerNamespace("api.system", address(0));
    }

    function __NamespaceManager_init_unchained() internal onlyInitializing {
    }

    /// @dev Returns the storage struct for this contract
    function _getStorage() internal pure returns (NamespaceManagerStorageV001 storage $) {
        assembly {
            $.slot := NamespaceManagerStorageV001Location
        }
    }

    /// @inheritdoc INamespaceManager
    function getNamespaceOwner(bytes32 namespaceId) external view override returns (address) {
        NamespaceManagerStorageV001 storage $ = _getStorage();
        return $.namespaces[namespaceId].owner;
    }

    /// @inheritdoc INamespaceManager
    function registerNamespace(string memory namespace, address owner) external override onlyDtn {
        require(owner != address(0), "NamespaceManager: zero address owner");
        NamespaceManagerStorageV001 storage $ = _getStorage();
        bytes32 namespaceId = keccak256(abi.encodePacked(namespace));
        require($.namespaces[namespaceId].owner == address(0), "NamespaceManager: namespace already exists");
        
        $.namespaces[namespaceId] = NamespaceConfig({
            owner: owner,
            namespaceId: namespaceId,
            namespace: namespace // Namespace string is not stored to save gas
        });

            emit NamespaceRegistered(namespace, namespaceId, owner);
    }

    function _registerNamespace(string memory namespace, address owner) internal {
        NamespaceManagerStorageV001 storage $ = _getStorage();
        bytes32 namespaceId = keccak256(abi.encodePacked(namespace));
        require($.namespaces[namespaceId].owner == address(0), "NamespaceManager: namespace already exists");
        
        $.namespaces[namespaceId] = NamespaceConfig({
            owner: owner,
            namespaceId: namespaceId,
            namespace: namespace // Namespace string is not stored to save gas
        });
        emit NamespaceRegistered(namespace, namespaceId, owner);
    }

    /// @dev Event emitted when a new namespace is registered
    event NamespaceRegistered(string indexed namespace, bytes32 indexed namespaceId, address indexed owner);

    function _authorizeUpgrade(address newImplementation) internal onlyOwner virtual override {
    }
}