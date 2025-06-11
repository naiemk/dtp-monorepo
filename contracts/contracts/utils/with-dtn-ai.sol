// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDtnAi} from "./idtn-ai.sol";

/**
 * @title WithDtnAi
 * @notice Implement this interface to use DtnAI
 */
abstract contract WithDtnAi  {
    IDtnAi public ai;

    modifier onlyDtn() {
        require(msg.sender == address(ai), "Only Dtn can call this function");
        _;
    }

    function setAi(address _ai) internal {
        ai = IDtnAi(_ai);
    }
}