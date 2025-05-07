// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../model/model-manager.sol";
import "../core/trust.sol";
import "../node/node-manager.sol";

/**
 * @title Router
 * @notice Router is the interface for dApps
 */
contract RouterUpgradeable is 
    Initializable, 
    ModelManagerUpgradeable, 
    TrustManagerUpgradeable,
    NodeManagerUpgradeable 
{
    /// @custom:storage-location erc7201:dtn.storage.router.001
    struct RouterStorageV001 {
        // No additional storage needed - using ModelManager's storage
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.router.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RouterStorageV001Location = 0xd9df4050ae7b51269371916df4148c5d25559acd8ad82e2b2cc4c87cd91c7e00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 minAuthoredStake,
        uint256 minNodeStake
    ) public initializer {
        __ModelManager_init();
        __TrustManager_init(minAuthoredStake);
        __NodeManager_init_unchained(minNodeStake);
        __Router_init_unchained();
        
        // Setup initial roles
        _setupRole(Dtn.OWNER_ROLE, msg.sender);
        _setRoleAdmin(Dtn.SYSTEM_ADMIN_ROLE, Dtn.OWNER_ROLE);
        _setRoleAdmin(Dtn.TRUST_ADMIN_ROLE, Dtn.SYSTEM_ADMIN_ROLE);
        _setRoleAdmin(Dtn.GENERAL_ADMIN_ROLE, Dtn.SYSTEM_ADMIN_ROLE);
    }

    function __Router_init_unchained() internal onlyInitializing {
        // No additional initialization needed
    }

    function getRouterStorageV001() internal pure returns (RouterStorageV001 storage $) {
        assembly {
            $.slot := RouterStorageV001Location
        }
    }
}
