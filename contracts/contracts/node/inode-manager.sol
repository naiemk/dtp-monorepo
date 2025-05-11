// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../core/dtn.sol";

/**
 * @title INodeManager
 * @notice Interface for node management in the DeepTrust Network
 */
interface INodeManager {
    /// @notice Struct to store node details
    struct Node {
        address staker;          // Address of the node staker
        address worker;          // Address of the node worker
        string[] namespaces;     // List of namespaces supported by the node
        bool isActive;           // Node activation status
        uint256 stakedAmount;    // Amount staked by the node
        uint256 responseRate;    // Node response rate score (0-10000)
        uint256 validAnswerRate; // Valid answer rate score (0-10000)
        uint256 complainRate;    // Complain rate score (0-10000)
    }

    /// @notice Struct to store model serving configuration
    struct ModelConfig {
        bytes32 modelNamespaceId; // The namespace id of the model group
        bytes32 modelId;
        string modelName;
        uint256 requestPricePerByte;
        uint256 responsePricePerByte;
    }

    /// @notice Emitted when a new node is registered
    event NodeRegistered(bytes32 indexed nodeId, address indexed staker, address worker);
    
    /// @notice Emitted when a node's status is updated
    event NodeStatusUpdated(bytes32 indexed nodeId, bool isActive);
    
    /// @notice Emitted when node namespaces are updated
    event NodeNamespacesUpdated(bytes32 indexed nodeId, string[] namespaces);
    
    /// @notice Emitted when node models are updated
    event NodeModelsUpdated(bytes32 indexed nodeId, ModelConfig[] models);
    
    /// @notice Emitted when node scores are updated
    event NodeScoresUpdated(
        bytes32 indexed nodeId, 
        uint256 responseRate, 
        uint256 validAnswerRate, 
        uint256 complainRate
    );

    /// @notice Register a new node
    function registerNode(
        bytes32 nodeId,
        address worker,
        string[] calldata namespaces,
        bytes[] calldata namespaceSignatures
    ) external payable;

    /// @notice Update node namespaces
    function updateNodeNamespaces(
        bytes32 nodeId,
        string[] calldata namespaces,
        bytes[] calldata namespaceSignatures
    ) external;

    /// @notice Set node activation status
    function setNodeStatus(bytes32 nodeId, bool isActive) external;

    /// @notice Set models served by the node
    function setNodeModels(bytes32 nodeId, ModelConfig[] calldata models) external;

    /// @notice Update node scores
    function updateNodeScores(
        bytes32 nodeId,
        uint256 responseRate,
        uint256 validAnswerRate,
        uint256 complainRate
    ) external;

    /// @notice Get node details
    function getNode(bytes32 nodeId) external view returns (Node memory);

    /// @notice Get node models configuration
    function getNodeModels(bytes32 nodeId) external view returns (ModelConfig[] memory);

    /// @notice Select nodes for a given model namespace
    function selectNodes(
        bytes32 modelNamespace,
        uint256 quality,
        uint256 maxPrice
    ) external view returns (bytes32[] memory);
}