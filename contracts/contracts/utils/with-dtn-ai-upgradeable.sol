// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDtnAi} from "./idtn-ai.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title WithDtnAi
 * @notice Implement this interface to use DtnAI
 */
abstract contract WithDtnAiUpgradeable is Initializable {

    struct WithDtnAiStorage {
        IDtnAi ai;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.withdtnai.001")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant WithDtnAiStorageLocation =
        0x120a853abbe723116a3ebafd26371681971b14dbea103ee376d65bbb8d134e00;

    function getWithDtnAiStorage() internal view returns (WithDtnAiStorage storage $) {
        assembly {
            $.slot := WithDtnAiStorageLocation
        }
    }

    function __WithDtnAi_init(address router) internal onlyInitializing {
        WithDtnAiStorage storage $ = getWithDtnAiStorage();
        $.ai = IDtnAi(router);
    }

    modifier onlyDtn() {
        WithDtnAiStorage storage $ = getWithDtnAiStorage();
        require(msg.sender == address($.ai), "Only Dtn can call this function");
        _;
    }

    function setAi(address _ai) internal {
        WithDtnAiStorage storage $ = getWithDtnAiStorage();
        $.ai = IDtnAi(_ai);
    }

    function ai() internal view returns (IDtnAi) {
        WithDtnAiStorage storage $ = getWithDtnAiStorage();
        return $.ai;
    }
}
