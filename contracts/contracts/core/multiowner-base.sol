// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract MultiOwnerBase is OwnableUpgradeable {
    error NotDtnContract(address _dtnContract);

    /// @custom:storage-location erc7201:dtn.core.multiownerbase.001
    struct MultiOwnerBaseStorageV001 {
        mapping(address => bool) dtnContracts;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.core.multiownerbase.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MultiOwnerBaseStorageV001Location = 0x9042a41a974b9fb065efd30b036d9f6283b7b2827a70d0d1b892f50c78b11e00;

    modifier onlyDtn() {
        MultiOwnerBaseStorageV001 storage $ = getMultiOwnerBaseStorageV001();
        if (!$.dtnContracts[msg.sender]) {
            revert NotDtnContract(msg.sender);
        }
        _;
    }

    function getMultiOwnerBaseStorageV001() internal pure returns (MultiOwnerBaseStorageV001 storage $) {
        assembly {
            $.slot := MultiOwnerBaseStorageV001Location
        }
    }

    function __MultiOwnerBase_init(address _owner) internal onlyInitializing {
        __Ownable_init(_owner);
    }

    function __MultiOwnerBase_init_unchained() internal onlyInitializing {
    }

    function addDtnContracts(address[] memory _dtnContracts) external onlyOwner {
        MultiOwnerBaseStorageV001 storage $ = getMultiOwnerBaseStorageV001();
        for (uint256 i = 0; i < _dtnContracts.length; i++) {
            $.dtnContracts[_dtnContracts[i]] = true;
        }
    }

    function removeDtnContracts(address _dtnContract) external onlyOwner {
        MultiOwnerBaseStorageV001 storage $ = getMultiOwnerBaseStorageV001();
        delete $.dtnContracts[_dtnContract];
    }
}