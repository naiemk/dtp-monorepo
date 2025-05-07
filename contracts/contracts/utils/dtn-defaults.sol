// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DtnDefaults {
    struct DtnRouting {
        string trustNamespaceId;
    }

    function defaultRoutingSystemValidatedAny() internal pure returns (DtnRouting memory) {
        return DtnRouting({
            trustNamespaceId: "system.routing.validated.any"
        });
    }

    uint256 public constant ROUTING_SYSTEM_VALIDATED_ANY_CONSTANT = 1;
}