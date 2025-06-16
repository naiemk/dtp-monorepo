// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./dtn.sol";

/**
 * @title TrustManagerUpgradeable
 * @notice Manages trust namespaces and their associated functionality
 */
contract TrustManagerUpgradeable is /* Initializable, */ AccessControlUpgradeable {
    /// @custom:storage-location erc7201:dtn.storage.trust.001
    struct TrustStorageV001 {
        mapping(bytes32 => Dtn.TrustNamespace) trustNamespaces;
        uint256 minAuthoredStake;
        string[] namespaceList;
    }

        // keccak256(abi.encode(uint256(keccak256("dtn.storage.trust.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TrustStorageV001Location = 0xad4fe8e5c0444567eeb89b13bf7f7573d4552b43fd078ed93e20764d22767d00; // Calculate proper storage location

    event TrustNamespaceRegistered(string namespace, address owner, string namespaceType);
    event TrustNamespaceDeleted(string namespace);
    
    error InsufficientStake(uint256 provided, uint256 required);
    error InvalidNamespace(string namespace);
    error UnauthorizedAccess();

    function __TrustManager_init(uint256 _minAuthoredStake) internal onlyInitializing {
        __AccessControl_init();
        TrustStorageV001 storage $ = getTrustStorageV001();
        $.minAuthoredStake = _minAuthoredStake;
    }

    function registerAuthoredTrustNamespace(string memory namespace, address nodeSelector) external payable {
        TrustStorageV001 storage $ = getTrustStorageV001();
        // require(msg.value >= $.minAuthoredStake, "Insufficient stake");
        require(Dtn.isAuthoredNamespace(namespace), "Invalid authored namespace prefix");
        
        $.trustNamespaces[keccak256(abi.encode(namespace))] = Dtn.TrustNamespace({
            owner: msg.sender,
            stake: msg.value,
            isActive: true,
            namespacePrefix: Dtn.TRUST_AUTHORED_PREFIX,
            nodeSelector: nodeSelector
        });
        $.namespaceList.push(namespace);
        
        emit TrustNamespaceRegistered(namespace, msg.sender, Dtn.TRUST_AUTHORED_PREFIX);
    }

    function registerVerifiedTrustNamespace(string memory namespace, address owner, address nodeSelector) external {
        require(hasRole(Dtn.SYSTEM_ADMIN_ROLE, msg.sender), "Caller is not system admin");
        require(Dtn.isVerifiedNamespace(namespace), "Invalid verified namespace prefix");
        
        TrustStorageV001 storage $ = getTrustStorageV001();
        $.trustNamespaces[keccak256(abi.encode(namespace))] = Dtn.TrustNamespace({
            owner: owner,
            stake: 0,
            isActive: true,
            namespacePrefix: Dtn.TRUST_VERIFIED_PREFIX,
            nodeSelector: nodeSelector
        });
        $.namespaceList.push(namespace);
        
        emit TrustNamespaceRegistered(namespace, owner, Dtn.TRUST_VERIFIED_PREFIX);
    }

    function registerDtnTrustNamespace(string memory namespace, address owner, address nodeSelector) external {
        require(hasRole(Dtn.TRUST_ADMIN_ROLE, msg.sender), "Caller is not trust admin");
        require(Dtn.isDtnNamespace(namespace), "Invalid DTP namespace prefix");
        
        TrustStorageV001 storage $ = getTrustStorageV001();
        $.trustNamespaces[keccak256(abi.encode(namespace))] = Dtn.TrustNamespace({
            owner: owner,
            stake: 0,
            isActive: true,
            namespacePrefix: Dtn.TRUST_DTP_PREFIX,
            nodeSelector: nodeSelector
        });
        $.namespaceList.push(namespace);
        
        emit TrustNamespaceRegistered(namespace, owner, Dtn.TRUST_DTP_PREFIX);
    }

    function deleteTrustNamespace(string memory namespace) external {
        require(hasRole(Dtn.TRUST_ADMIN_ROLE, msg.sender), "Caller is not trust admin");
        
        TrustStorageV001 storage $ = getTrustStorageV001();
        require($.trustNamespaces[keccak256(abi.encode(namespace))].isActive, "Namespace not found or already deleted");
        
        $.trustNamespaces[keccak256(abi.encode(namespace))].isActive = false;
        
        // If authored namespace, return stake to owner
        if (Dtn.isAuthoredNamespace(namespace)) {
            payable($.trustNamespaces[keccak256(abi.encode(namespace))].owner).transfer($.trustNamespaces[keccak256(abi.encode(namespace))].stake);
        }
        
        emit TrustNamespaceDeleted(namespace);
    }

    function listTrustNamespaces() external view returns (string[] memory) {
        return getTrustStorageV001().namespaceList;
    }

    function getTrustStorageV001() internal pure returns (TrustStorageV001 storage $) {
        assembly {
            $.slot := TrustStorageV001Location
        }
    }
} 