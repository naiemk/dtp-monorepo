// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./idtn-ai.sol";

library DtnDefaults {
    function defaultRoutingSystemValidatedAny() internal pure returns (IDtnAi.DtnRouting memory) {
        bytes32[] memory namespaces = new bytes32[](1);
        namespaces[0] = keccak256(abi.encode("system.routing.validated.any"));
        
        return IDtnAi.DtnRouting({
            trustNamespaceIds: namespaces,
            redundancy: 1,
            confidenceLevel: 8,
            aggregationType: IDtnAi.AggregationType.ANY
        });
    }

    uint256 public constant ROUTING_SYSTEM_VALIDATED_ANY_CONSTANT = 1;
}