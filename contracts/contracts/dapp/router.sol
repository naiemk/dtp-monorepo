// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../model/model-manager.sol";
import "../core/trust.sol";
import "../node/node-manager.sol";
import "../utils/idtn-ai.sol";
import "../session/session-manager.sol";

/**
 * @title Router
 * @notice Router is the interface for dApps and implements AI functionality
 */
contract RouterUpgradeable is 
    Initializable, 
    ModelManagerUpgradeable, 
    TrustManagerUpgradeable,
    NodeManagerUpgradeable,
    SessionManagerUpgradeable,
    IDtnAi 
{
    /// @custom:storage-location erc7201:dtn.storage.router.001
    struct RouterStorageV001 {
        // Request management
        mapping(bytes32 => Request) requests;
        mapping(bytes32 => Response) responses;
    }

    struct Request {
        uint256 sessionId;
        address user;
        bool completed;
        Response response;
    }

    struct Response {
        uint256 status;
        string message;
        string response;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.router.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RouterStorageV001Location = 0xd9df4050ae7b51269371916df4148c5d25559acd8ad82e2b2cc4c87cd91c7e00;

    // Events
    event RequestCreated(bytes32 indexed requestId, uint256 indexed sessionId, address indexed user);
    event RequestCompleted(bytes32 indexed requestId, uint256 status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 minAuthoredStake,
        uint256 minNodeStake,
        address feeToken,
        address feeTarget
    ) public initializer {
        __ModelManager_init();
        __TrustManager_init(minAuthoredStake);
        __NodeManager_init_unchained(minNodeStake);
        __SessionManager_init(feeToken, feeTarget);
        __Router_init_unchained();
        
        // Setup initial roles
        _setupRole(Dtn.OWNER_ROLE, msg.sender);
        _setRoleAdmin(Dtn.SYSTEM_ADMIN_ROLE, Dtn.OWNER_ROLE);
        _setRoleAdmin(Dtn.TRUST_ADMIN_ROLE, Dtn.SYSTEM_ADMIN_ROLE);
        _setRoleAdmin(Dtn.GENERAL_ADMIN_ROLE, Dtn.SYSTEM_ADMIN_ROLE);
    }

    function __Router_init_unchained() internal onlyInitializing {
        // No additional initialization needed
    }

    function getRouterStorageV001() internal pure returns (RouterStorageV001 storage $) {
        assembly {
            $.slot := RouterStorageV001Location
        }
    }

    /**
     * @notice Starts a new user session with specified token amount
     * @param amount Amount of tokens to allocate for the session
     * @return sessionId Unique identifier for the created session
     */
    function startUserSession(uint256 amount) public override returns (uint256 sessionId) {
        return SessionManagerUpgradeable._startUserSession(amount);
    }

    /**
     * @notice Closes an active user session
     * @param sessionId ID of the session to close
     */
    function closeUserSession(uint256 sessionId) public override {
        return SessionManagerUpgradeable._closeUserSession(sessionId);
    }



    // IDtnAi Implementation
    function request(
        uint256 sessionId,
        bytes32 modelId,
        IDtnAi.DtnRouting memory routingSystem,
        IDtnAi.DtnRequest memory dtnRequest,
        IDtnAi.CallBack memory callback,
        address user,
        uint256 callbackGas
    ) external payable override returns (bytes32) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        
        // Verify session using SessionManager's getSessionById
        Session memory session = getSessionById(sessionId);
        require(session.owner == msg.sender, "Session not related to the user");
        require(msg.value >= callbackGas, "Insufficient callback gas");

        // TODO: Validate model, and router

        bytes32 requestId = keccak256(abi.encodePacked(
            block.timestamp,
            sessionId,
            user,
            msg.sender
        ));

        $.requests[requestId] = Request({
            sessionId: sessionId,
            user: user,
            completed: false,
            response: Response({
                status: 0,
                message: "",
                response: ""
            })
        });

        // Charge the session for the request
        // TODO: Charge is requested by the node
        // chargeUserSession(sessionId, callbackGas);

        emit RequestCreated(requestId, sessionId, user);

        // TODO: Assign one or multiple nodes to the request
        // the node selection algo is based on the routing namespaces
        // We use the first trust namespace in the routing that implements
        // an algorithm to select the nodes
        // turstNamespace.nodeSelector.selectNodes(requestId);
        return requestId;
    }

    function fetchResponse(bytes32 requestId) external override view returns (
        uint256 status,
        string memory message,
        string memory response
    ) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        Response storage _response = $.responses[requestId];
        return (_response.status, _response.message, _response.response);
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal override view {
        require(hasRole(Dtn.OWNER_ROLE, msg.sender), "Not authorized");
    }
}
