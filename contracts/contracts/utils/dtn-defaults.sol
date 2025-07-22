// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./idtn-ai.sol";

library DtnDefaults {
    function defaultRoutingSystemValidatedAny() internal pure returns (IDtnAi.DtnRouting memory) {
        bytes32[] memory namespaces = new bytes32[](1);
        namespaces[0] = keccak256(abi.encode("trust.system.authored"));
        
        return IDtnAi.DtnRouting({
            trustNamespaceIds: namespaces,
            trustedNodeIds: new bytes32[](0),
            redundancy: 1,
            confidenceLevel: 8,
            aggregationType: IDtnAi.AggregationType.ANY
        });
    }

    function defaultCustomNodesValidatedAny(bytes32[] memory customNodes) internal pure returns (IDtnAi.DtnRouting memory) {
        bytes32[] memory namespaces = new bytes32[](0);
        
        return IDtnAi.DtnRouting({
            trustNamespaceIds: namespaces,
            trustedNodeIds: customNodes,
            redundancy: 1,
            confidenceLevel: 8,
            aggregationType: IDtnAi.AggregationType.ANY
        });
    }

    function singleArray(bytes32 value) internal pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](1);
        array[0] = value;
        return array;
    }

    function singleArray(string memory value) internal pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](1);
        array[0] = keccak256(abi.encode(value));
        return array;
    }

    uint256 public constant ROUTING_SYSTEM_VALIDATED_ANY_CONSTANT = 1;
}