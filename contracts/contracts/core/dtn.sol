// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Dtn
 * @notice Common types and data structures
 */

library Dtn {
    // Admin role definitions
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant SYSTEM_ADMIN_ROLE = keccak256("SYSTEM_ADMIN_ROLE");
    bytes32 public constant TRUST_ADMIN_ROLE = keccak256("TRUST_ADMIN_ROLE");
    bytes32 public constant GENERAL_ADMIN_ROLE = keccak256("GENERAL_ADMIN_ROLE");

    // Trust namespace prefixes
    string internal constant TRUST_AUTHORED_PREFIX = "trust.authored.";
    string internal constant TRUST_VERIFIED_PREFIX = "trust.verified.";
    string internal constant TRUST_DTP_PREFIX = "trust.dtp.";

    struct TrustNamespace {
        address owner;
        uint256 stake;
        bool isActive;
        string namespacePrefix; // "authored", "verified", or "dtp"
        address nodeSelector; // The node selector contract (implements INodeSelector)
    }

    // Helper functions for namespace validation
    function isAuthoredNamespace(string memory namespace) internal pure returns (bool) {
        return startsWith(namespace, TRUST_AUTHORED_PREFIX);
    }

    function isVerifiedNamespace(string memory namespace) internal pure returns (bool) {
        return startsWith(namespace, TRUST_VERIFIED_PREFIX);
    }

    function isDtnNamespace(string memory namespace) internal pure returns (bool) {
        return startsWith(namespace, TRUST_DTP_PREFIX);
    }

    /**
     * @dev Checks if a string starts with a given prefix using assembly for gas efficiency
     * @param str The string to check
     * @param prefix The prefix to look for
     * @return bool True if str starts with prefix
     */
    function startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bool result;
        assembly {
            // Load lengths
            let strLen := mload(str)
            let prefixLen := mload(prefix)
            
            // If prefix is longer than string, result is false
            if gt(prefixLen, strLen) {
                result := 0
            }
            // Otherwise proceed with comparison
            if iszero(gt(prefixLen, strLen)) {
                let strPtr := add(str, 32)
                let prefixPtr := add(prefix, 32)
                
                // If prefix length is 32 or less, we only need one word comparison
                if lt(prefixLen, 33) {
                    // Create masks for the relevant bytes
                    let mask := not(sub(exp(256, sub(32, prefixLen)), 1))
                    
                    // Compare the masked values
                    let strWord := and(mload(strPtr), mask)
                    let prefixWord := and(mload(prefixPtr), mask)
                    
                    result := eq(strWord, prefixWord)
                }
                // For longer prefixes
                if iszero(lt(prefixLen, 33)) {
                    // Start with result as true
                    result := 1
                    
                    // Compare full words first
                    let words := div(prefixLen, 32)
                    for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                        let strWord := mload(add(strPtr, mul(i, 32)))
                        let prefixWord := mload(add(prefixPtr, mul(i, 32)))
                        
                        if iszero(eq(strWord, prefixWord)) {
                            result := 0
                            // Break the loop
                            i := words
                        }
                    }
                    
                    // If still true, compare remaining bytes if any
                    if and(result, gt(mod(prefixLen, 32), 0)) {
                        let remainder := mod(prefixLen, 32)
                        let offset := mul(words, 32)
                        let mask := not(sub(exp(256, sub(32, remainder)), 1))
                        
                        let strWord := and(mload(add(strPtr, offset)), mask)
                        let prefixWord := and(mload(add(prefixPtr, offset)), mask)
                        
                        result := eq(strWord, prefixWord)
                    }
                }
            }
        }
        return result;
    }

    // Functionalities for 'request_ai', fetch_response, and fetch_error
    // plus functionalities for fee management: feeTarget, feeToken
}