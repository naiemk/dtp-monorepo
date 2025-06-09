// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./inode-manager.sol";
import "../core/dtn.sol";
import "../core/inamespace-manager.sol";

/**
 * @title NodeManager
 * @notice Implementation of node management functionality for DeepTrust Network
 */
abstract contract NodeManagerUpgradeable is 
    INodeManager,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSA for bytes32;

    /// @custom:storage-location erc7201:dtn.storage.node.001
    struct NodeStorageV001 {
        address namespaceManager;
        mapping(bytes32 => string) users;
        mapping(bytes32 => Node) nodes;
        mapping(bytes32 => bytes32[]) assignedNamespaces;
        mapping(bytes32 => mapping(bytes32 => uint256)) assignedNamespaceExpiration;
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
        _disableInitializers();
    }

    function initialize(address namespaceManager, uint256 minStakeAmount_) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __NodeManager_init_unchained(namespaceManager, minStakeAmount_);
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
        require(msg.value >= $.minStakeAmount, "Insufficient stake");
        string memory parentNamespace = string.concat("node.", username);
        string memory nodeNamespace = string.concat(parentNamespace, ".", nodeName);
        bytes32 parentNamespaceId = keccak256(abi.encodePacked(parentNamespace));
        bytes32 nodeNamespaceId = keccak256(abi.encodePacked(nodeNamespace));
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

    function updateNodeNamespaces(
        bytes32 nodeId,
        string[] calldata namespaces,
        uint256[] calldata namespaceExpirations,
        bytes[] calldata namespaceSignatures
    ) external override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].staker == msg.sender, "Not node staker");
        require(namespaces.length == namespaceSignatures.length, "Invalid signatures length");

        // Verify namespace signatures
        for (uint256 i = 0; i < namespaces.length; i++) {
            bytes32 namespaceId = keccak256(abi.encodePacked(namespaces[i]));
            address namespaceOwner = INamespaceManager($.namespaceManager).getNamespaceOwner(namespaceId);
            require(namespaceOwner != address(0), "Namespace does not exist");

            // Verify EIP712 signature
            bytes32 structHash = keccak256(abi.encode(
                NAMESPACE_ASSIGNMENT_TYPEHASH,
                nodeId,
                keccak256(bytes(namespaces[i])),
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

            address signer = hash.recover(namespaceSignatures[i]);
            require(signer == namespaceOwner, "Invalid signature");

            // Add namespace to node's trust namespaces
            $.nodes[nodeId].trustNamespaces.push(namespaceId);
            $.nodes[nodeId].trustNamespaceExpirations.push(namespaceExpirations[i]);
        }

        emit NodeNamespacesUpdated(nodeId, namespaces);
    }

    function setNodeStatus(bytes32 nodeId, bool isActive) external override {
        NodeStorageV001 storage $ = getNodeStorageV001();
        require($.nodes[nodeId].owner == msg.sender, "Not node staker");
        
        $.nodes[nodeId].isActive = isActive;
        emit NodeStatusUpdated(nodeId, isActive);
    }

    function getNode(bytes32 nodeId) external view override returns (Node memory) {
        return getNodeStorageV001().nodes[nodeId];
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal override view {
        require(hasRole(Dtn.OWNER_ROLE, msg.sender), "Not authorized");
    }
}