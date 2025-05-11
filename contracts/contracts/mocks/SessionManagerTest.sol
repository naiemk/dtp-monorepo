// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../session/session-manager.sol";

contract SessionManagerTest is SessionManagerUpgradeable {
    function initialize(address _feeToken, address _feeTarget) public override {
        __SessionManager_init(_feeToken, _feeTarget);
    }
} 