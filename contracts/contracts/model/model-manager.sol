// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title SessionManager
 * @notice SessionManager is responsible for managing sessions
 */
abstract contract ModelManagerUpgradeable {
    /// @custom:storage-location erc7201:dtn.storage.modelmanager.001
    struct SessionManagerStorageV001 {
        uint sessionCount;
        mapping(address => uint[]) userSessionIds;
        mapping(uint => Session) sessions;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.modelmanager.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ModelStorageV001Location = 0x317ad3d122488b64c2d86bf285bd2d0e9a7289d8b50201f32d6abb04fde8a300;

    function __ModelManager_init() internal {
    }

    function __ModelManager_init_unchained() internal {}

    function getModelStorageV001() internal view returns (ModelManagerStorageV001 storage) {
        assembly {
            storage := ModelStorageV001Location
        }
    }

    // TODO: Implement session management:
    // - startSession
    // - chargeSession
    // - closeSession
    // - getSessionById
    // - getUserSessionIds
}
