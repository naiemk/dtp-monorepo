// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";
import "../model/imodel-manager.sol";
import "../core/trust.sol";
import "../utils/idtn-ai.sol";
import "../core/multiowner-base.sol";
import "../core/iresponse-strategy.sol";
import "../node/inode-manager.sol";
import "../core/dtn.sol";
import "../session/isession-manager.sol";

/**
 * @title Router
 * @notice Router is the interface for dApps and implements AI functionality
 */
contract RouterUpgradeable is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    MultiOwnerBase,
    TrustManagerUpgradeable,
    ReentrancyGuardUpgradeable,
    IDtnAi,
    IResponseStrategy
{
    using SafeERC20 for IERC20;
    /// @custom:storage-location erc7201:dtn.storage.router.001
    struct RouterStorageV001 {
        // Request management
        address nodeManager;
        address sessionManager;
        address modelManager;
        bytes32[] requestIds;
        bytes32[] completedRequestIds;
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
    event RequestCompleted(bytes32 indexed requestId, ResponseStatus status);
    event ResponseReceived(bytes32 indexed requestId, bytes32 indexed nodeId, ResponseStatus status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // _disableInitializers();
    }

    function initialize(
        uint256 minAuthoredStake,
        address owner
    ) public initializer {
        __AccessControl_init();
        __MultiOwnerBase_init(owner);
        __TrustManager_init(minAuthoredStake);
        __Router_init_unchained();
        __ReentrancyGuard_init();

        // Setup initial roles
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(Dtn.OWNER_ROLE, owner);
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

    function feeToken() public override view returns (address) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        return ISessionManager($.sessionManager).getFeeToken();
    }

    function feeTarget() public override view returns (address) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        return ISessionManager($.sessionManager).getFeeTarget();
    }

    /**
     * @notice Calculate the model ID from the full model name (namespace.modelName)
     * @param modelFullName The full model name in format namespace.modelName
     * @return The calculated model ID
     */
    function modelId(string memory modelFullName) external pure override returns (bytes32) {
        return keccak256(abi.encodePacked(modelFullName));
    }

    function getPendingRequestsLength() public view returns (uint256) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        return $.requestIds.length;
    }

    function getPendingRequests(uint from, uint to) public view returns (bytes32[] memory) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        bytes32[] memory requests = new bytes32[](to - from);
        for (uint256 i = from; i < to; i++) {
            requests[i - from] = $.requestIds[i];
        }
        return requests;
    }

    function getCompletedRequestsLength() public view returns (uint256) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        return $.completedRequestIds.length;
    }

    function getCompletedRequests(uint from, uint to) public view returns (bytes32[] memory) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        bytes32[] memory requests = new bytes32[](to - from);
        for (uint256 i = from; i < to; i++) {
            requests[i - from] = $.completedRequestIds[i];
        }
        return requests;
    }

    function getRequest(bytes32 requestId) public view returns (Request memory) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        return $.requests[requestId];
    }

    function setDependencies(address nodeManager, address sessionManager, address modelManager, address namespaceManager) external onlyOwner {
        RouterStorageV001 storage $ = getRouterStorageV001();
        $.nodeManager = nodeManager;
        $.sessionManager = sessionManager;
        $.modelManager = modelManager;
    }

    /**
     * @notice Starts a new user session with specified token amount
     * @return sessionId Unique identifier for the created session
     */
    function startUserSession() public override returns (uint256 sessionId) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        return ISessionManager($.sessionManager).startUserSession(msg.sender);
    }

    /**
     * @notice Closes an active user session
     * @param sessionId ID of the session to close
     */
    function closeUserSession(uint256 sessionId) public override {
        RouterStorageV001 storage $ = getRouterStorageV001();
        return ISessionManager($.sessionManager).closeUserSession(sessionId, msg.sender);
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
        ISessionManager.Session memory session = ISessionManager($.sessionManager).getSessionById(sessionId);
        require(session.owner == msg.sender, "Session not related to the user");
        require(msg.value >= callbackGas, "Insufficient callback gas");
        require(IModelManager($.modelManager).modelExists(_modelId), "Model does not exist");

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
                status: ResponseStatus.SUCCESS,
                message: "",
                response: "",
                nodeId: bytes32(0),
                timestamp: block.timestamp
            })
        });
        $.requestIds.push(requestId);

        emit RequestCreated(requestId, sessionId, user);

        return requestId;
    }

    function _verifyNodeTrustNamespace(
        bytes32 nodeId,
        bytes32[] memory trustNamespaceIds,
        bytes32[] memory trustedNodeIds
    ) internal view returns (bool) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        if (trustedNodeIds.length > 0) {
            for (uint256 i = 0; i < trustedNodeIds.length; i++) {
                if (trustedNodeIds[i] == nodeId) {
                    return true;
                }
            }
        }
        for (uint256 i = 0; i < trustNamespaceIds.length; i++) {
            bytes32 namespaceId = trustNamespaceIds[i];
            if (INodeManager($.nodeManager).nodeHasTrustNamespace(nodeId, namespaceId)) {
                uint256 expiration = INodeManager($.nodeManager).nodeTrustNamespaceExpiration(nodeId, namespaceId);
                if (block.timestamp <= expiration) {
                    return true;
                }
            }
        }
        return false;
    }

    function _createResponse(
        ResponseStatus status,
        string memory message,
        bytes memory response,
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
        ResponseStatus status
    ) internal {
        // Get response strategy based on routing type
        IResponseStrategy strategy = IResponseStrategy(getResponseStrategy(requestData.routing.aggregationType));
        requestData.completed = true;
        
        // Extract final response
        IDtnAi.Response memory finalResponse = strategy.extractSingleResponse(
            requestId,
            $.responses[requestId]
        );

        // Store the final response and mark as completed
        requestData.finalResponse = finalResponse;

        console.log("Callback gas", requestData.callbackGas);
        console.log("Callback", requestData.callback.target);
        // Call callback
        if (status == ResponseStatus.SUCCESS) { // Success
            (bool success, ) = requestData.callback.target.call{gas: requestData.callbackGas}(
                abi.encodeWithSelector(requestData.callback.suscess, requestId)
            );
            require(success, "Success callback failed");
        } else { // Failure
            (bool success, ) = requestData.callback.target.call{gas: requestData.callbackGas}(
                abi.encodeWithSelector(requestData.callback.failure, requestId)
            );
            require(success, "Failure callback failed");
        }

        emit RequestCompleted(requestId, status);
    }

    function respondToRequest(
        bytes32 requestId,
        ResponseStatus status,
        string memory message,
        bytes memory response,
        bytes32 nodeId,
        uint256 requestSize,
        uint256 responseSize
    ) external nonReentrant {
        RouterStorageV001 storage $ = getRouterStorageV001();
        Request storage requestData = $.requests[requestId];
        {
        require(!requestData.completed, "Request already completed");
        require(!$.nodeResponded[requestId][nodeId], "Node already responded");
        // Get node info
        INodeManager.NodeData memory node = INodeManager($.nodeManager).getNode(nodeId);
        console.log("node.worker", node.worker);
        require(node.worker == msg.sender, "Not the node worker");
        require(node.isActive, "Node not active");
        // Verify node has required trust namespace using efficient lookup
        require(
            _verifyNodeTrustNamespace(nodeId, requestData.routing.trustNamespaceIds, requestData.routing.trustedNodeIds),
            "Node does not have required trust namespace"
        );

        // Verify node serves the requested model using efficient lookup
        require(
            INodeManager($.nodeManager).nodeServesModel(nodeId, requestData.modelId),
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
        ISessionManager($.sessionManager).chargeUserSession(requestData.sessionId, totalFee, msg.sender);

        // Create and add response
        IDtnAi.Response memory newResponse = _createResponse(status, message, response, nodeId);
        $.responses[requestId].push(newResponse);
        $.nodeResponded[requestId][nodeId] = true;
        requestData.responseCount++;

        emit ResponseReceived(requestId, nodeId, status);

        // Check if we have enough responses based on routing
        if (requestData.responseCount >= requestData.routing.redundancy) {
            _handleRequestCompletion(requestId, requestData, $, status);
            $.completedRequestIds.push(requestId);
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
        if (aggregationType == AggregationType.ANY) {
            return address(this);
        }

        revert("Response strategy not implemented");
    }

    /**
     * @notice Extracts a single response from the responses array
     * @param requestId The ID of the request
     * @param responses The array of responses
     * @return response The single response
     */
    function extractSingleResponse(
        bytes32 requestId,
        IDtnAi.Response[] memory responses
    ) public view override returns (IDtnAi.Response memory response) {
        RouterStorageV001 storage $ = getRouterStorageV001();
        Request storage _request = $.requests[requestId];
        require(_request.completed, "Request not completed");
        require(_request.responseCount == 1, "No responses found or multiple responses without aggregation");
        require($.nodeResponded[requestId][responses[0].nodeId], "Node did not respond");
        require(responses[0].status == ResponseStatus.SUCCESS, "Response status is not success");
        response = $.responses[requestId][0];
    }

    function fetchResponse(
        bytes32 requestId
    )
        external
        view
        override
        returns (IDtnAi.ResponseStatus status, string memory message, bytes memory response)
    {
        RouterStorageV001 storage $ = getRouterStorageV001();
        Request storage _request = $.requests[requestId];
        require(_request.completed, "Request not completed");

        // If we have a final response (aggregated), return it
        if (_request.finalResponse.nodeId != bytes32(0)) {
            return (
                _request.finalResponse.status,
                _request.finalResponse.message,
                _request.finalResponse.response
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
}
