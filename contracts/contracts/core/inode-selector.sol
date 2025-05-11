// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INodeSelector {
    function selectNodes(bytes32 requestId) external;
}
