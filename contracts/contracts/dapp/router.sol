// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../model/model-manager.sol";
import "../core/trust.sol";
import "../node/node-manager.sol";
import "../utils/idtn-ai.sol";
import "../session/session-manager.sol";
import "../core/multiowner-base.sol";
import "../core/iresponse-strategy.sol";

/**
 * @title Router
 * @notice Router is the interface for dApps and implements AI functionality
 */
contract RouterUpgradeable is
    Initializable,
    MultiOwnerBase,
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
        mapping(bytes32 => IDtnAi.Response[]) responses;
        mapping(bytes32 => mapping(bytes32 => bool)) nodeResponded; // requestId => nodeId => hasResponded
    }

    struct Request {
        uint256 sessionId;
        address user;
        bool completed;
        bytes32 modelId;
        DtnRouting routing;
        DtnRequest request;
        CallBack callback;
        uint256 callbackGas;
        uint256 responseCount;
        IDtnAi.Response finalResponse;
    }

    // keccak256(abi.encode(uint256(keccak256("dtn.storage.router.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RouterStorageV001Location =
        0xd9df4050ae7b51269371916df4148c5d25559acd8ad82e2b2cc4c87cd91c7e00;

    // Events
    event RequestCreated(
        bytes32 indexed requestId,
        uint256 indexed sessionId,
        address indexed user
    );
    event RequestCompleted(bytes32 indexed requestId, uint256 status);
    event ResponseReceived(bytes32 indexed requestId, bytes32 indexed nodeId, uint256 status);

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
        __ModelManager_init(address(0)); // Initialize with null address for namespace manager
        __TrustManager_init(minAuthoredStake);
        __NodeManager_init_unchained(address(0), minNodeStake); // Initialize with null address for namespace manager
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

    function getRouterStorageV001()
        internal
        pure
        returns (RouterStorageV001 storage $)
    {
        assembly {
            $.slot := RouterStorageV001Location
        }
    }

    /**
     * @notice Starts a new user session with specified token amount
     * @param amount Amount of tokens to allocate for the session
     * @return sessionId Unique identifier for the created session
     */
    function startUserSession(
        uint256 amount
    ) public override returns (uint256 sessionId) {
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
        bytes32 _modelId,
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

        bytes32 requestId = keccak256(
            abi.encodePacked(block.timestamp, sessionId, user, msg.sender)
        );

        $.requests[requestId] = Request({
            sessionId: sessionId,
            user: user,
            completed: false,
            modelId: _modelId,
            routing: routingSystem,
            request: dtnRequest,
            callback: callback,
            callbackGas: callbackGas,
            responseCount: 0,
            finalResponse: IDtnAi.Response({
                status: 0,
                message: "",
                response: "",
                nodeId: bytes32(0),
                timestamp: block.timestamp
            })
        });

        emit RequestCreated(requestId, sessionId, user);

        return requestId;
    }

    function _verifyNodeTrustNamespace(
        bytes32 nodeId,
        bytes32[] memory trustNamespaceIds,
        bytes32[] memory trustedNodeIds
    ) internal view returns (bool) {
        if (trustedNodeIds.length > 0) {
            for (uint256 i = 0; i < trustedNodeIds.length; i++) {
                if (trustedNodeIds[i] == nodeId) {
                    return true;
                }
            }
        }
        for (uint256 i = 0; i < trustNamespaceIds.length; i++) {
            bytes32 namespaceId = trustNamespaceIds[i];
            if (NodeManagerUpgradeable(address(this)).nodeHasTrustNamespace(nodeId, namespaceId)) {
                uint256 expiration = NodeManagerUpgradeable(address(this)).nodeTrustNamespaceExpiration(nodeId, namespaceId);
                if (block.timestamp <= expiration) {
                    return true;
                }
            }
        }
        return false;
    }

    function _createResponse(
        uint256 status,
        string memory message,
        string memory response,
        bytes32 nodeId
    ) internal view returns (IDtnAi.Response memory) {
        return IDtnAi.Response({
            status: status,
            message: message,
            response: response,
            nodeId: nodeId,
            timestamp: block.timestamp
        });
    }

    function _handleRequestCompletion(
        bytes32 requestId,
        Request storage requestData,
        RouterStorageV001 storage $,
        uint256 status
    ) internal {
        // Get response strategy based on routing type
        IResponseStrategy strategy = IResponseStrategy(getResponseStrategy(requestData.routing.aggregationType));
        
        // Extract final response
        IDtnAi.Response memory finalResponse = strategy.extractSingleResponse(
            requestId,
            $.responses[requestId]
        );

        // Store the final response and mark as completed
        requestData.finalResponse = finalResponse;
        requestData.completed = true;

        // Call callback
        if (status == 0) { // Success
            (bool success, ) = requestData.callback.target.call{gas: requestData.callbackGas}(
                abi.encodeWithSelector(requestData.callback.success, requestId)
            );
            require(success, "Callback failed");
        } else { // Failure
            (bool success, ) = requestData.callback.target.call{gas: requestData.callbackGas}(
                abi.encodeWithSelector(requestData.callback.failure, requestId)
            );
            require(success, "Callback failed");
        }

        emit RequestCompleted(requestId, status);
    }

    function respondToRequest(
        bytes32 requestId,
        uint256 status,
        string memory message,
        string memory response,
        bytes32 nodeId,
        uint256 requestSize,
        uint256 responseSize
    ) external {
        RouterStorageV001 storage $ = getRouterStorageV001();
        Request storage requestData = $.requests[requestId];
        {
        require(!requestData.completed, "Request already completed");
        require(!$.nodeResponded[requestId][nodeId], "Node already responded");
        // Get node info
        NodeData memory node = this.getNode(nodeId);
        require(node.worker == msg.sender, "Not the node worker");
        require(node.isActive, "Node not active");
        // Verify node has required trust namespace using efficient lookup
        require(
            _verifyNodeTrustNamespace(nodeId, requestData.routing.trustNamespaceIds, requestData.routing.trustedNodeIds),
            "Node does not have required trust namespace"
        );

        // Verify node serves the requested model using efficient lookup
        require(
            NodeManagerUpgradeable(address(this)).nodeServesModel(nodeId, requestData.modelId),
            "Node does not serve requested model"
        );

        }


        // Calculate request fee using request-specific rate
        uint256 requestFee = requestSize * requestData.request.feePerByteReq;
        
        // Calculate response fee using response-specific rate
        uint256 responseFee = responseSize * requestData.request.feePerByteRes;
        
        // Ensure response fee doesn't exceed maximum allowed
        require(responseFee <= requestData.request.totalFeePerRes, "Response fee exceeds maximum");

        // Charge the session for both request and response fees
        uint256 totalFee = requestFee + responseFee;
        SessionManagerUpgradeable.chargeUserSession(requestData.sessionId, totalFee, msg.sender);

        // Create and add response
        IDtnAi.Response memory newResponse = _createResponse(status, message, response, nodeId);
        $.responses[requestId].push(newResponse);
        $.nodeResponded[requestId][nodeId] = true;
        requestData.responseCount++;

        emit ResponseReceived(requestId, nodeId, status);

        // Check if we have enough responses based on routing
        if (requestData.responseCount >= requestData.routing.redundancy) {
            _handleRequestCompletion(requestId, requestData, $, status);
        }
    }

    /**
     * @notice Gets the response strategy contract address for a given aggregation type
     * @param aggregationType The type of aggregation to use
     * @return The address of the response strategy contract
     */
    function getResponseStrategy(AggregationType aggregationType) internal view returns (address) {
        // TODO: Implement strategy selection based on aggregation type
        // For now, return a default strategy
        return address(0);
    }

    function fetchResponse(
        bytes32 requestId
    )
        external
        view
        override
        returns (uint256 status, string memory message, string memory response)
    {
        RouterStorageV001 storage $ = getRouterStorageV001();
        Request storage request = $.requests[requestId];
        require(request.completed, "Request not completed");

        // If we have a final response (aggregated), return it
        if (request.finalResponse.nodeId != bytes32(0)) {
            return (
                request.finalResponse.status,
                request.finalResponse.message,
                request.finalResponse.response
            );
        }

        // Otherwise, we should have exactly one response
        IDtnAi.Response[] storage responses = $.responses[requestId];
        require(responses.length == 1, "No responses found or multiple responses without aggregation");
        
        IDtnAi.Response storage singleResponse = responses[0];
        return (singleResponse.status, singleResponse.message, singleResponse.response);
    }

    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal view override {
        require(hasRole(Dtn.OWNER_ROLE, msg.sender), "Not authorized");
    }

    function getNodeModels(bytes32 nodeId) external view override returns (bytes32[] memory) {
        return NodeManagerUpgradeable.getNodeStorageV001().nodeModels[nodeId];
    }
}
