// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../model/model-manager.sol";

/**
 * @title Router
 * @notice Router is the interface for dApps
 */
contract RouterUpgradeable is Initializable, ModelManagerUpgradeable {
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

    function initialize() public initializer {
        __ModelManager_init();
        __Router_init_unchained();
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
