// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./inode-manager.sol";
import "../core/dtn.sol";

/**
 * @title NodeManager
 * @notice Implementation of node management functionality for DeepTrust Network
 */
contract NodeManagerUpgradeable is 
    INodeManager,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /// @custom:storage-location erc7201:dtn.storage.node.001
    struct NodeStorageV001 {
        mapping(bytes32 => Node) nodes;
        mapping(bytes32 => ModelConfig[]) nodeModels;
        uint256 minStakeAmount;
    }

    bytes32 private constant NodeStorageV001Location = 
        bytes32(uint256(keccak256("dtn.storage.node.001")) - 1) & ~bytes32(uint256(0xff));

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 minStakeAmount_) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __NodeManager_init_unchained(minStakeAmount_);
    }

    function __NodeManager_init_unchained(uint256 minStakeAmount_) internal onlyInitializing {
        NodeStorageV001 storage $ = getNodeStorageV001();
        $.minStakeAmount = minStakeAmount_;
    }

    function getNodeStorageV001() internal pure returns (NodeStorageV001 storage $) {
        assembly {
            $.slot := NodeStorageV001Location
        }
    }

    function registerNode(
        bytes32 nodeId,
        address worker,
        string[] calldata namespaces,
        bytes[] calldata namespaceSignatures
    ) external payable whenNotPaused nonReentrant {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require(msg.value >= $.minStakeAmount, "Insufficient stake");
        require($.nodes[nodeId].staker == address(0), "Node already exists");
        require(namespaces.length == namespaceSignatures.length, "Invalid signatures length");

        // Verify namespace signatures
        for (uint256 i = 0; i < namespaces.length; i++) {
            require(_verifyNamespaceSignature(namespaces[i], namespaceSignatures[i]), "Invalid signature");
        }

        $.nodes[nodeId] = Node({
            staker: msg.sender,
            worker: worker,
            namespaces: namespaces,
            isActive: true,
            stakedAmount: msg.value,
            responseRate: 10000,
            validAnswerRate: 10000,
            complainRate: 0
        });

        emit NodeRegistered(nodeId, msg.sender, worker);
    }

    function updateNodeNamespaces(
        bytes32 nodeId,
        string[] calldata namespaces,
        bytes[] calldata namespaceSignatures
    ) external whenNotPaused {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].staker == msg.sender, "Not node staker");
        require(namespaces.length == namespaceSignatures.length, "Invalid signatures length");

        // Verify namespace signatures
        for (uint256 i = 0; i < namespaces.length; i++) {
            require(_verifyNamespaceSignature(namespaces[i], namespaceSignatures[i]), "Invalid signature");
        }

        $.nodes[nodeId].namespaces = namespaces;
        emit NodeNamespacesUpdated(nodeId, namespaces);
    }

    function setNodeStatus(bytes32 nodeId, bool isActive) external whenNotPaused {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].staker == msg.sender, "Not node staker");
        
        $.nodes[nodeId].isActive = isActive;
        emit NodeStatusUpdated(nodeId, isActive);
    }

    function setNodeModels(bytes32 nodeId, ModelConfig[] calldata models) external whenNotPaused {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].staker == msg.sender, "Not node staker");
        
        $.nodeModels[nodeId] = models;
        emit NodeModelsUpdated(nodeId, models);
    }

    function updateNodeScores(
        bytes32 nodeId,
        uint256 responseRate,
        uint256 validAnswerRate,
        uint256 complainRate
    ) external whenNotPaused {
        require(hasRole(Dtn.TRUST_ADMIN_ROLE, msg.sender), "Not authorized");
        require(responseRate <= 10000 && validAnswerRate <= 10000 && complainRate <= 10000, "Invalid score range");

        NodeStorageV001 storage $ = getNodeStorageV001();
        Node storage node = $.nodes[nodeId];
        
        node.responseRate = responseRate;
        node.validAnswerRate = validAnswerRate;
        node.complainRate = complainRate;

        emit NodeScoresUpdated(nodeId, responseRate, validAnswerRate, complainRate);
    }

    function getNode(bytes32 nodeId) external view returns (Node memory) {
        return getNodeStorageV001().nodes[nodeId];
    }

    function getNodeModels(bytes32 nodeId) external view returns (ModelConfig[] memory) {
        return getNodeStorageV001().nodeModels[nodeId];
    }

    function selectNodes(
        bytes32 modelNamespace,
        uint256 quality,
        uint256 maxPrice
    ) external view returns (bytes32[] memory) {
        // Implementation of node selection algorithm
        // This is a placeholder - actual implementation would need to consider:
        // - Node scores
        // - Price constraints
        // - Quality requirements
        // - Load balancing
        // Returns array of selected node IDs
        return new bytes32[](0);
    }

    function _verifyNamespaceSignature(
        string memory namespace,
        bytes memory signature
    ) internal pure returns (bool) {
        // Implementation of namespace signature verification
        // This is a placeholder - actual implementation would need to:
        // - Recover signer from signature
        // - Verify signer is authorized for namespace
        return true;
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(hasRole(Dtn.OWNER_ROLE, msg.sender), "Not authorized");
    }
}