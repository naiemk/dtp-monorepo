// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library NamespaceUtils {
    /**
     * @notice The resource is the last word int the namespace string separated by a dot
     * @param namespace The namespace to extract the resource from
     * @return The namespace
     * @return The resource name
     */
    function extractResourceNamespace(string memory namespace
    ) internal pure returns (string memory, string memory) {
                bytes memory namespaceBytes = bytes(namespace);
        uint256 length = namespaceBytes.length;
        uint256 lastDotPos;
        require(length != 0, "no namespace");

        // Use assembly to efficiently find the last dot position
        assembly {
            // Start from the end of the string (accounting for the 32-byte offset)
            let ptr := add(add(namespaceBytes, 0x20), sub(length, 1))
            
            // Loop backwards until we find a dot or reach the start
            for { let i := length } gt(i, 0) { i := sub(i, 1) } {
                if eq(byte(0, mload(ptr)), 0x2e) {
                    lastDotPos := i
                    break
                }
                ptr := sub(ptr, 1)
            }
        }
        require(lastDotPos != 0, "bad namespace");

        // Create the namespace and resource parts using efficient memory copies
        bytes memory namespacePart = new bytes(lastDotPos - 1);
        bytes memory resourcePart = new bytes(length - lastDotPos);
        //return (string(namespacePart), string(resourcePart));

        assembly {
            // Copy namespace part (everything before the dot)
            let nsDestPtr := add(namespacePart, 0x20)
            let nsSourcePtr := add(namespaceBytes, 0x20)
            mstore(nsDestPtr, mload(nsSourcePtr))
            
            // Copy resource part (everything after the dot)
            let resDestPtr := add(resourcePart, 0x20)
            let resSourcePtr := add(add(namespaceBytes, 0x20), lastDotPos)
            mstore(resDestPtr, mload(resSourcePtr))
        }


        //emit Portito(string(namespacePart), string(resourcePart));
        return (string(namespacePart), string(resourcePart));
    }

    function testGasUsage(string memory namespace) public pure returns (string memory, string memory) {
        return extractResourceNamespace(namespace);
    }
}
