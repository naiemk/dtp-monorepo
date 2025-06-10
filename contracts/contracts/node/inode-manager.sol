// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../core/dtn.sol";
import "../model/imodel-manager.sol";

/**
 * @title INodeManager
 * @notice Interface for node management in the DeepTrust Network
 */
interface INodeManager {
    /// @notice Struct to store node details
    struct Node {
        address owner;           // Address of the node owner
        address staker;          // Address of the node staker
        address worker;          // Address of the node worker
        bytes32[] trustNamespaces; // List of namespaces supported by the node
        uint256[] trustNamespaceExpirations; // List of namespace expiration times
        bytes32 nodeNamespaceId; // Node namespace ID
        bool isActive;           // Node activation status
        uint256 stakedAmount;    // Amount staked by the node
        bytes32 id;              // Node ID
    }

    /// @notice Flattened node data for external returns
    struct NodeData {
        address owner;
        address staker;
        address worker;
        bytes32[] trustNamespaces;
        uint256[] trustNamespaceExpirations;
        bytes32 nodeNamespaceId;
        bool isActive;
        uint256 stakedAmount;
        bytes32 id;
    }

    /// @notice Emitted when a new user is registered
    event UserRegistered(bytes32 indexed userId, address indexed owner, address staker);

    /// @notice Emitted when a new node is registered
    event NodeRegistered(bytes32 indexed nodeId, address indexed staker, address worker);
    
    /// @notice Emitted when a node's status is updated
    event NodeStatusUpdated(bytes32 indexed nodeId, bool isActive);
    
    /// @notice Emitted when node namespaces are updated
    event NodeNamespacesUpdated(bytes32 indexed nodeId, string[] namespaces);
    
    /// @notice Emitted when node models are updated
    event NodeModelsUpdated(bytes32 indexed nodeId, bytes32[] modelIds);
    
    /// @notice Emitted when node scores are updated
    event NodeScoresUpdated(
        bytes32 indexed nodeId, 
        uint256 responseRate, 
        uint256 validAnswerRate, 
        uint256 complainRate
    );

    /**
     * @notice Register a new user. It will also register three namespaces:
     * "node.userid", "model.node.userid", "api.node.userid"
     * @param namespace The namespace of the user
     * @param staker The address of the staker
     */
    function registerUser(
        string memory namespace,
        address staker
    ) external;

    /// @notice Register a new node
    function registerNode(
        string memory username,
        string memory nodeName,
        address worker
    ) external payable;

    /**
     * @notice Update node namespaces. Namespace owners must sign the namespaces.
     * For example, if a node is part of a proprietory trusted group, the group
     * owner will sign the namespaces.
     * @param nodeId The node id
     * @param namespaces The namespaces to update
     * @param namespaceSignatures The signatures of the namespaces
     */
    function updateNodeNamespaces(
        bytes32 nodeId,
        string[] calldata namespaces,
        uint256[] calldata namespaceExpirations,
        bytes[] calldata namespaceSignatures
    ) external;

    /// @notice Set models served by the node
    function setNodeModels(bytes32 nodeId, bytes32[] calldata modelIds) external;

    /// @notice Get node details
    function getNode(bytes32 nodeId) external view returns (NodeData memory);

    /// @notice Get node models configuration
    function getNodeModels(bytes32 nodeId) external view returns (bytes32[] memory);

    /// @notice Get all nodes serving a specific model
    function getNodesServingModel(bytes32 modelId) external view returns (bytes32[] memory);

    /// @notice Remove models from a node
    function removeModelsFromNode(bytes32 nodeId, bytes32[] calldata modelIds) external;

    /// @notice Set node active status
    function setNodeStatus(bytes32 nodeId, bool isActive) external;

    /// @notice Check if a node has a specific trust namespace
    function nodeHasTrustNamespace(bytes32 nodeId, bytes32 namespaceId) external view returns (bool);

    /// @notice Get the expiration time for a node's trust namespace
    function nodeTrustNamespaceExpiration(bytes32 nodeId, bytes32 namespaceId) external view returns (uint256);

    /// @notice Check if a node serves a specific model
    function nodeServesModel(bytes32 nodeId, bytes32 modelId) external view returns (bool);
}