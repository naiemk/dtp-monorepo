// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../core/multiowner-base.sol";
import "./isession-manager.sol";
import "hardhat/console.sol";

/**
 * @title SessionManager
 * @notice SessionManager is responsible for managing sessions
 */
contract SessionManagerUpgradeable is Initializable, MultiOwnerBase, ISessionManager {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:dtn.storage.sessionmanager.001
    struct SessionManagerStorageV001 {
        uint sessionCount;
        mapping(address => uint[]) userSessionIds;
        mapping(uint => Session) sessions;
        address feeToken;
        address feeTarget;
        uint feeBalance;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.sessionmanager.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RouterStorageV001Location = 0xf2c05596afc0fa7a667b407040331ebc39d72b2fe94f39b136657de5e1b94f00;

    error InsufficientBalance(uint sessionId, uint required, uint available);
    error InvalidSession(uint sessionId);
    error Unauthorized(address caller, address owner);
    error InvalidAmount();
    error TransferFailed();

    event SessionStarted(uint indexed sessionId, address indexed owner, uint balance);
    event SessionCharged(uint indexed sessionId, uint amount, address indexed to);
    event SessionClosed(uint indexed sessionId, uint remainingBalance);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize(address _feeToken, address _feeTarget, address owner) public virtual initializer {
        // require(_feeTarget == address(this), "Use session manager as fee target");
        __SessionManager_init(_feeToken, _feeTarget);
        __MultiOwnerBase_init(owner);
    }

    function __SessionManager_init(address _feeToken, address _feeTarget) internal onlyInitializing {
        SessionManagerStorageV001 storage $ = _getStorage();
        $.feeToken = _feeToken;
        $.feeTarget = _feeTarget;
    }

    function _getStorage() private pure returns (SessionManagerStorageV001 storage $) {
        assembly {
            $.slot := RouterStorageV001Location
        }
    }

    function setFeeTarget(address _feeTarget) external onlyOwner {
        SessionManagerStorageV001 storage $ = _getStorage();
        $.feeTarget = _feeTarget;
    }

    function sync(address token) internal returns (uint) {
        SessionManagerStorageV001 storage $ = _getStorage();
        uint currentBalance = IERC20(token).balanceOf(address(this));
        uint amount = currentBalance - $.feeBalance;
        $.feeBalance = currentBalance;
        return amount;
    }

    function sendToken(address token, address to, uint amount) internal {
        SessionManagerStorageV001 storage $ = _getStorage();
        $.feeBalance -= amount;
        IERC20(token).safeTransfer(to, amount);
    }

    function startUserSession(address owner) external virtual onlyDtn returns (uint) {
        SessionManagerStorageV001 storage $ = _getStorage();
        uint amount = sync($.feeToken);
        if (amount == 0) revert InvalidAmount();
        return _startSession(owner, amount);
    }

    function closeUserSession(uint sessionId, address owner) external virtual onlyDtn override {
        Session memory session = getSessionById(sessionId);
        if (session.owner != owner) revert Unauthorized(msg.sender, session.owner);
        uint remainingBalance = _closeSession(sessionId);
        
        if (remainingBalance > 0) {
            SessionManagerStorageV001 storage $ = _getStorage();
            sendToken($.feeToken, msg.sender, remainingBalance);
        }
    }

    function chargeUserSession(uint sessionId, uint amount, address to) external virtual override onlyDtn {
        _chargeSession(sessionId, amount, to);
    }

    function _startSession(address owner, uint balance) internal returns (uint) {
        SessionManagerStorageV001 storage $ = _getStorage();
        uint sessionId = ++$.sessionCount;
        
        $.sessions[sessionId] = Session({
            owner: owner,
            balance: balance
        });
        
        $.userSessionIds[owner].push(sessionId);
        
        emit SessionStarted(sessionId, owner, balance);
        return sessionId;
    }

    function _chargeSession(uint sessionId, uint amount, address to) internal {
        SessionManagerStorageV001 storage $ = _getStorage();
        Session storage session = $.sessions[sessionId];
        
        if (session.owner == address(0)) revert InvalidSession(sessionId);
        if (session.balance < amount) {
            revert InsufficientBalance(sessionId, amount, session.balance);
        }
        
        session.balance -= amount;
        sendToken($.feeToken, to, amount);
        
        emit SessionCharged(sessionId, amount, to);
    }

    function _closeSession(uint sessionId) internal returns (uint) {
        SessionManagerStorageV001 storage $ = _getStorage();
        Session storage session = $.sessions[sessionId];
        
        if (session.owner == address(0)) revert InvalidSession(sessionId);
        
        uint remainingBalance = session.balance;
        delete $.sessions[sessionId];
        
        uint[] storage userSessions = $.userSessionIds[session.owner];
        for (uint i = 0; i < userSessions.length; i++) {
            if (userSessions[i] == sessionId) {
                userSessions[i] = userSessions[userSessions.length - 1];
                userSessions.pop();
                break;
            }
        }
        
        emit SessionClosed(sessionId, remainingBalance);
        return remainingBalance;
    }

    function getSessionById(uint sessionId) public view returns (Session memory) {
        return _getStorage().sessions[sessionId];
    }

    function getUserSessionIds(address user) public view returns (uint[] memory) {
        return _getStorage().userSessionIds[user];
    }

    function getUserSessions(address user) public view returns (Session[] memory) {
        uint[] memory sessionIds = getUserSessionIds(user);
        Session[] memory sessions = new Session[](sessionIds.length);
        for (uint i = 0; i < sessionIds.length; i++) {
            sessions[i] = getSessionById(sessionIds[i]);
        }
        return sessions;
    }

    function getFeeToken() public view returns (address) {
        return _getStorage().feeToken;
    }

    function getFeeTarget() public view returns (address) {
        return _getStorage().feeTarget;
    }
}
