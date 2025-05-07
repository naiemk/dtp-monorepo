// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./dtn.sol";

/**
 * @title TrustManagerUpgradeable
 * @notice Manages trust namespaces and their associated functionality
 */
contract TrustManagerUpgradeable is Initializable, AccessControlUpgradeable {
    /// @custom:storage-location erc7201:dtn.storage.trust.001
    struct TrustStorageV001 {
        mapping(string => Dtn.TrustNamespace) trustNamespaces;
        uint256 minAuthoredStake;
        string[] namespaceList;
    }

    bytes32 private constant TrustStorageV001Location = 0x...; // Calculate proper storage location

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

    function registerAuthoredTrustNamespace(string memory namespace) external payable {
        TrustStorageV001 storage $ = getTrustStorageV001();
        require(Dtn.isAuthoredNamespace(namespace), "Invalid authored namespace prefix");
        require(msg.value >= $.minAuthoredStake, "Insufficient stake");
        
        $.trustNamespaces[namespace] = Dtn.TrustNamespace({
            owner: msg.sender,
            stake: msg.value,
            isActive: true,
            namespaceType: "authored"
        });
        $.namespaceList.push(namespace);
        
        emit TrustNamespaceRegistered(namespace, msg.sender, "authored");
    }

    function registerVerifiedTrustNamespace(string memory namespace, address owner) external {
        require(hasRole(Dtn.SYSTEM_ADMIN_ROLE, msg.sender), "Caller is not system admin");
        require(Dtn.isVerifiedNamespace(namespace), "Invalid verified namespace prefix");
        
        TrustStorageV001 storage $ = getTrustStorageV001();
        $.trustNamespaces[namespace] = Dtn.TrustNamespace({
            owner: owner,
            stake: 0,
            isActive: true,
            namespaceType: "verified"
        });
        $.namespaceList.push(namespace);
        
        emit TrustNamespaceRegistered(namespace, owner, "verified");
    }

    function registerDtpTrustNamespace(string memory namespace, address owner) external {
        require(hasRole(Dtn.TRUST_ADMIN_ROLE, msg.sender), "Caller is not trust admin");
        require(Dtn.isDtpNamespace(namespace), "Invalid DTP namespace prefix");
        
        TrustStorageV001 storage $ = getTrustStorageV001();
        $.trustNamespaces[namespace] = Dtn.TrustNamespace({
            owner: owner,
            stake: 0,
            isActive: true,
            namespaceType: "dtp"
        });
        $.namespaceList.push(namespace);
        
        emit TrustNamespaceRegistered(namespace, owner, "dtp");
    }

    function deleteTrustNamespace(string memory namespace) external {
        require(hasRole(Dtn.TRUST_ADMIN_ROLE, msg.sender), "Caller is not trust admin");
        
        TrustStorageV001 storage $ = getTrustStorageV001();
        require($.trustNamespaces[namespace].isActive, "Namespace not found or already deleted");
        
        $.trustNamespaces[namespace].isActive = false;
        
        // If authored namespace, return stake to owner
        if (Dtn.isAuthoredNamespace(namespace)) {
            payable($.trustNamespaces[namespace].owner).transfer($.trustNamespaces[namespace].stake);
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