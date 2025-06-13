// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISessionManager {
    struct Session {
        address owner;
        uint balance;
    }

    function getFeeToken() external view returns (address);

    function getFeeTarget() external view returns (address);

    function startUserSession(address owner) external returns (uint256 sessionId);

    function closeUserSession(uint256 sessionId, address owner) external;

    function getSessionById(uint256 sessionId) external view returns (Session memory);

    function chargeUserSession(uint256 sessionId, uint256 amount, address to) external;
}
