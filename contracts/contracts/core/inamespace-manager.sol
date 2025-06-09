// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INamespaceManager {
    struct NamespaceConfig {
        address owner;
        bytes32 namespaceId;
        string namespace;
    }

    function getNamespaceOwner(bytes32 namespaceId) external view returns (address);

    function registerNamespace(string memory namespace, address owner) external;
}