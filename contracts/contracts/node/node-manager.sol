// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./inode-manager.sol";
import "../core/dtn.sol";
import "../core/inamespace-manager.sol";
import "hardhat/console.sol";

/**
 * @title NodeManager
 * @notice Implementation of node management functionality for DeepTrust Network
 */
contract NodeManagerUpgradeable is 
    Initializable,
    UUPSUpgradeable,
    INodeManager,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;

    /// @custom:storage-location erc7201:dtn.storage.node.001
    struct NodeStorageV001 {
        address namespaceManager;
        mapping(bytes32 => string) users;
        mapping(bytes32 => Node) nodes;
        mapping(bytes32 => bytes32[]) nodeModels;
        mapping(bytes32 => mapping(bytes32 => bool)) modelToNode;
        mapping(bytes32 => bytes32[]) modelToNodeList;
        // New mappings for efficient lookups
        mapping(bytes32 => mapping(bytes32 => bool)) nodeHasTrustNamespace; // nodeId => namespaceId => hasNamespace
        mapping(bytes32 => mapping(bytes32 => uint256)) nodeTrustNamespaceExpiration; // nodeId => namespaceId => expiration
        mapping(bytes32 => mapping(bytes32 => bool)) nodeServesModel; // nodeId => modelId => servesModel

        uint256 minStakeAmount;
    }

    // bytes32(uint256(keccak256("dtn.storage.node.001")) - 1) & ~bytes32(uint256(0xff));
    bytes32 private constant NodeStorageV001Location =
        0xf1d8a1fbd219fcf17256caa0b8a67d409449fa7722eca5860c9b170f56e73300;

    // EIP712 domain separator
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant NAMESPACE_ASSIGNMENT_TYPEHASH = keccak256(
        "NamespaceAssignment(bytes32 targetId,string namespace,uint256 expiration)"
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize(address namespaceManager, uint256 minStakeAmount_) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __NodeManager_init_unchained(namespaceManager, minStakeAmount_);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Dtn.OWNER_ROLE, msg.sender);
    }

    function __NodeManager_init_unchained(address namespaceManager, uint256 minStakeAmount_) internal onlyInitializing {
        NodeStorageV001 storage $ = getNodeStorageV001();
        $.namespaceManager = namespaceManager;
        $.minStakeAmount = minStakeAmount_;
    }

    function getNodeStorageV001() internal pure returns (NodeStorageV001 storage $) {
        assembly {
            $.slot := NodeStorageV001Location
        }
    }

    function registerUser(
        string memory username,
        address staker
    ) external override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        bytes32 userId = keccak256(abi.encodePacked(username));
        require(bytes($.users[userId]).length == 0, "User already exists");

        // Register the three required namespaces
        string memory nodeNamespace = string.concat("node.", username);
        string memory modelNamespace = string.concat("model.node.", username);
        string memory apiNamespace = string.concat("api.node.", username);

        INamespaceManager($.namespaceManager).registerNamespace(nodeNamespace, msg.sender);
        INamespaceManager($.namespaceManager).registerNamespace(modelNamespace, msg.sender);
        INamespaceManager($.namespaceManager).registerNamespace(apiNamespace, msg.sender);

        $.users[userId] = username;
        emit UserRegistered(userId, msg.sender, staker);
    }

    function registerNode(
        string memory username,
        string memory nodeName,
        address worker
    ) external payable override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        // require(msg.value >= $.minStakeAmount, "Insufficient stake");
        string memory parentNamespace = string.concat("node.", username);
        string memory nodeNamespace = string.concat(parentNamespace, ".", nodeName);
        bytes32 parentNamespaceId = keccak256(abi.encodePacked(parentNamespace));
        bytes32 nodeNamespaceId = keccak256(abi.encodePacked(nodeNamespace));
        console.log(nodeNamespace);
        console.log("nodeNamespaceId");
        console.logBytes32(nodeNamespaceId);
        require($.nodes[nodeNamespaceId].owner == address(0), "Node already exists");

        // Verify the caller owns the node namespace
        require(INamespaceManager($.namespaceManager).getNamespaceOwner(parentNamespaceId) == msg.sender, "Not namespace owner");

        $.nodes[nodeNamespaceId] = Node({
            owner: msg.sender,
            staker: msg.sender,
            worker: worker,
            trustNamespaces: new bytes32[](0),
            trustNamespaceExpirations: new uint256[](0),
            nodeNamespaceId: nodeNamespaceId,
            isActive: true,
            stakedAmount: msg.value,
            id: nodeNamespaceId
        });

        emit NodeRegistered(nodeNamespaceId, msg.sender, worker);
    }

    function _clearNodeNamespaces(bytes32 nodeId) internal {
        NodeStorageV001 storage $ = getNodeStorageV001();
        bytes32[] storage existingNamespaces = $.nodes[nodeId].trustNamespaces;
        for (uint256 i = 0; i < existingNamespaces.length; i++) {
            bytes32 namespaceId = existingNamespaces[i];
            $.nodeHasTrustNamespace[nodeId][namespaceId] = false;
            $.nodeTrustNamespaceExpiration[nodeId][namespaceId] = 0;
        }
        delete $.nodes[nodeId].trustNamespaces;
        delete $.nodes[nodeId].trustNamespaceExpirations;
    }

    function _verifyNamespaceSignature(
        bytes32 nodeId,
        string memory namespace,
        bytes memory signature
    ) internal view returns (bytes32) {
        bytes32 namespaceId = keccak256(abi.encodePacked(namespace));
        address namespaceOwner = INamespaceManager(getNodeStorageV001().namespaceManager).getNamespaceOwner(namespaceId);
        require(namespaceOwner != address(0), "Namespace does not exist");

        // Verify EIP712 signature
        bytes32 structHash = keccak256(abi.encode(
            NAMESPACE_ASSIGNMENT_TYPEHASH,
            nodeId,
            keccak256(bytes(namespace)),
            block.timestamp + 365 days // Default expiration 1 year
        ));

        bytes32 hash = keccak256(abi.encodePacked(
            "\x19\x01",
            keccak256(abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                keccak256("DeepTrust Network"),
                keccak256("1"),
                block.chainid,
                address(this)
            )),
            structHash
        ));

        address signer = hash.recover(signature);
        require(signer == namespaceOwner, "Invalid signature");
        return namespaceId;
    }

    function _addNamespaceToNode(
        bytes32 nodeId,
        bytes32 namespaceId,
        uint256 expiration
    ) internal {
        NodeStorageV001 storage $ = getNodeStorageV001();
        $.nodes[nodeId].trustNamespaces.push(namespaceId);
        $.nodes[nodeId].trustNamespaceExpirations.push(expiration);
        $.nodeHasTrustNamespace[nodeId][namespaceId] = true;
        $.nodeTrustNamespaceExpiration[nodeId][namespaceId] = expiration;
    }

    function updateNodeNamespaces(
        bytes32 nodeId,
        string[] calldata namespaces,
        uint256[] calldata namespaceExpirations,
        bytes[] calldata namespaceSignatures
    ) external override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].staker == msg.sender, "Not node staker");
        require(namespaces.length == namespaceSignatures.length, "Invalid signatures length");

        // Clear existing namespaces
        _clearNodeNamespaces(nodeId);

        // Add new namespaces
        for (uint256 i = 0; i < namespaces.length; i++) {
            bytes32 namespaceId = _verifyNamespaceSignature(nodeId, namespaces[i], namespaceSignatures[i]);
            _addNamespaceToNode(nodeId, namespaceId, namespaceExpirations[i]);
        }

        emit NodeNamespacesUpdated(nodeId, namespaces);
    }

    function setNodeStatus(bytes32 nodeId, bool isActive) external override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].owner == msg.sender, "Not node staker");
        
        $.nodes[nodeId].isActive = isActive;
        emit NodeStatusUpdated(nodeId, isActive);
    }

    function getNode(bytes32 nodeId) external view override returns (NodeData memory) {
        Node storage node = getNodeStorageV001().nodes[nodeId];
        return NodeData({
            owner: node.owner,
            staker: node.staker,
            worker: node.worker,
            trustNamespaces: node.trustNamespaces,
            trustNamespaceExpirations: node.trustNamespaceExpirations,
            nodeNamespaceId: node.nodeNamespaceId,
            isActive: node.isActive,
            stakedAmount: node.stakedAmount,
            id: node.id
        });
    }

    function setNodeModels(bytes32 nodeId, bytes32[] calldata modelIds) external override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].owner == msg.sender, "Not node owner");
        require($.nodes[nodeId].isActive, "Node is not active");

        // Clear existing models
        bytes32[] storage existingModels = $.nodeModels[nodeId];
        for (uint256 i = 0; i < existingModels.length; i++) {
            bytes32 modelId = existingModels[i];
            delete $.nodeServesModel[nodeId][modelId];
            delete $.modelToNode[modelId][nodeId];
            
            // Remove node from model's node list
            bytes32[] storage nodeList = $.modelToNodeList[modelId];
            for (uint256 j = 0; j < nodeList.length; j++) {
                if (nodeList[j] == nodeId) {
                    // Replace with last element and pop
                    nodeList[j] = nodeList[nodeList.length - 1];
                    nodeList.pop();
                    break;
                }
            }
        }
        delete $.nodeModels[nodeId];

        // Add new models
        for (uint256 i = 0; i < modelIds.length; i++) {
            bytes32 modelId = modelIds[i];
            $.nodeModels[nodeId].push(modelId);
            $.nodeServesModel[nodeId][modelId] = true;
            $.modelToNode[modelId][nodeId] = true;
            $.modelToNodeList[modelId].push(nodeId);
        }

        emit NodeModelsUpdated(nodeId, modelIds);
    }

    function getNodesServingModel(bytes32 modelId) external view override returns (bytes32[] memory) {
        return getNodeStorageV001().modelToNodeList[modelId];
    }

    function removeModelsFromNode(bytes32 nodeId, bytes32[] calldata modelIds) external override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].owner == msg.sender, "Not node owner");

        bytes32[] storage nodeModels = $.nodeModels[nodeId];
        
        // Remove each model from the node's model list and the modelToNode mapping
        for (uint256 i = 0; i < modelIds.length; i++) {
            bytes32 modelId = modelIds[i];
            require($.nodeServesModel[nodeId][modelId], "Model not assigned to node");
            
            // Remove from nodeServesModel mapping
            $.nodeServesModel[nodeId][modelId] = false;
            
            // Remove from modelToNode mapping
            delete $.modelToNode[modelId][nodeId];
            
            // Remove from modelToNodeList
            bytes32[] storage nodeList = $.modelToNodeList[modelId];
            for (uint256 j = 0; j < nodeList.length; j++) {
                if (nodeList[j] == nodeId) {
                    // Replace with last element and pop
                    nodeList[j] = nodeList[nodeList.length - 1];
                    nodeList.pop();
                    break;
                }
            }
            
            // Remove from nodeModels array
            for (uint256 j = 0; j < nodeModels.length; j++) {
                if (nodeModels[j] == modelId) {
                    // Replace with last element and pop
                    nodeModels[j] = nodeModels[nodeModels.length - 1];
                    nodeModels.pop();
                    break;
                }
            }
        }

        emit NodeModelsUpdated(nodeId, nodeModels);
    }

    function nodeHasTrustNamespace(bytes32 nodeId, bytes32 namespaceId) external view override returns (bool) {
        return getNodeStorageV001().nodeHasTrustNamespace[nodeId][namespaceId];
    }

    function nodeTrustNamespaceExpiration(bytes32 nodeId, bytes32 namespaceId) external view override returns (uint256) {
        return getNodeStorageV001().nodeTrustNamespaceExpiration[nodeId][namespaceId];
    }

    function nodeServesModel(bytes32 nodeId, bytes32 modelId) external view override returns (bool) {
        return getNodeStorageV001().nodeServesModel[nodeId][modelId];
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override view {
        require(hasRole(Dtn.OWNER_ROLE, msg.sender), "Not authorized");
    }

    function getNodeModels(bytes32 nodeId) external view override returns (bytes32[] memory) {
        return getNodeStorageV001().nodeModels[nodeId];
    }

    function getUserId(string calldata username) external view returns (bytes32) {
        NodeStorageV001 storage $ = getNodeStorageV001();
        bytes32 userId = keccak256(abi.encodePacked(username));
        return bytes($.users[userId]).length != 0 ? userId : bytes32(0);
    }

    function getUserName(bytes32 userId) external view returns (string memory) {
        return getNodeStorageV001().users[userId];
    }
}