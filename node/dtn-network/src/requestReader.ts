import { Logger, LogLevel } from "./logger";
import { namespaceToId, type ModelConfig, type NodeConfig, type RouterRequest } from "./types";
import { ethers } from "ethers";

const MAX_LOOK_BACK_REQUESTS = 1000;

// Router contract interface
interface RouterContract {
    getPendingRequestsLength(): Promise<bigint>;
    getPendingRequests(from: bigint, to: bigint): Promise<string[]>;
    getCompletedRequestsLength(): Promise<bigint>;
    getCompletedRequests(from: bigint, to: bigint): Promise<string[]>;
    getRequest(requestId: string): Promise<RouterRequest>;
}

/**
 * This class reads queries from chain, and filters then based on the 
 * node's configuration taking in the account the following criterias:
 * 1- Do we serve the requested model?
 * 2- Do we belong to the relevant security namespace?
 * 3- Is the offered price within our range?
 */
export class RequestReader {
    private provider: ethers.JsonRpcProvider | undefined;
    private routerContract: RouterContract | undefined;
    private nodeId: string | undefined;
    private cachedPendingRequestsLength: number = 0;
    private cachedCompletedRequestsLength: number = 0;
    private models: Map<string, ModelConfig> = new Map();
    private logger: Logger;

    constructor(
        private readonly config: NodeConfig,
        logLevel: LogLevel = LogLevel.INFO,
    ) {
        this.logger = new Logger(logLevel);
        this.provider = new ethers.JsonRpcProvider(config.network.rpcUrl);
        this.routerContract = new ethers.Contract(
            config.network.routerAddress,
            [
                "function getPendingRequestsLength() view returns (uint256)",
                "function getPendingRequests(uint256 from, uint256 to) view returns (bytes32[])",
                "function getCompletedRequestsLength() view returns (uint256)",
                "function getCompletedRequests(uint256 from, uint256 to) view returns (bytes32[])",
                "function getRequest(bytes32 requestId) view returns (tuple(uint256 sessionId, address user, bool completed, bytes32 modelId, tuple(bytes32[] trustNamespaceIds, bytes32[] trustedNodeIds, uint32 redundancy, uint8 confidenceLevel, uint8 aggregationType) routing, tuple(bytes call, bytes extraParams, uint8 calltype, uint256 feePerByteReq, uint256 feePerByteRes, uint256 totalFeePerRes) request, tuple(bytes4 suscess, bytes4 failure, address target) callback, uint256 callbackGas, uint256 responseCount, tuple(uint8 status, string message, string response, bytes32 nodeId, uint256 timestamp) finalResponse))"
            ],
            this.provider
        ) as unknown as RouterContract;

        // Calculate node ID from worker address
        this.nodeId = namespaceToId(`node.${this.config.node.username}.${this.config.node.nodeName}`);
        this.models = new Map(this.config.node.models.map(model => [namespaceToId(model.name), model]));
        this.logger.info(`RequestReader: Initialized with node ID ${this.nodeId}`);
        this.logger.info(`RequestReader: Serving models: ${Array.from(this.models.keys()).join(", ")}`);
    }

    /**
     * Get a specific request by ID
     * @param requestId The ID of the request to fetch
     * @returns The request details
     */
    async getRequest(requestId: string): Promise<RouterRequest> {
        if (!this.routerContract) {
            throw new Error("RequestReader not properly initialized");
        }
        return await this.routerContract.getRequest(requestId);
    }

    /**
     * Fetch all the pending requests from dtp router, and
     * filter them based on the node's configuration.
     * @param lastRequestIdx - The index of the first request to fetch
     * @param lastResponseIdx - The index of the first response to fetch
     */
    async fetchRelevantRequests(lastRequestIdx: number, lastResponseIdx: number): Promise<{
        requestIds: string[];
        relevantRequests: RouterRequest[];
        newLastRequestIdx: number;
        newLastResponseIdx: number;
    }> {
        if (!this.provider || !this.routerContract || !this.nodeId) {
            throw new Error("RequestReader not properly initialized");
        }

        // Check if there are new pending requests
        const pendingRequestsLength = await this.routerContract.getPendingRequestsLength();
        const pendingRequests: string[] = [];
        
        if (pendingRequestsLength > this.cachedPendingRequestsLength) {
            // Only fetch new requests if there are actually new ones
            const from = BigInt(Math.max(lastRequestIdx, this.cachedPendingRequestsLength));
            const to = pendingRequestsLength;
            
            if (from < to) {
                // Apply maxLookBackRequests limit if configured
                const maxLookBack = this.config.maxLookBackRequests || MAX_LOOK_BACK_REQUESTS;
                const actualFrom = Math.max(Number(from), Number(to) - maxLookBack);
                
                const requestIds = await this.routerContract.getPendingRequests(
                    BigInt(actualFrom), 
                    to
                );
                pendingRequests.push(...requestIds);
            }
            
            // Cache the new length on success
            this.cachedPendingRequestsLength = Number(pendingRequestsLength);
        }

        // Check if there are new completed requests
        const completedRequestsLength = await this.routerContract.getCompletedRequestsLength();
        const completedRequests: string[] = [];
        
        if (completedRequestsLength > this.cachedCompletedRequestsLength) {
            // Only fetch new completed requests if there are actually new ones
            const from = BigInt(Math.max(lastResponseIdx, this.cachedCompletedRequestsLength));
            const to = completedRequestsLength;
            
            if (from < to) {
                // Apply maxLookBackRequests limit if configured
                const maxLookBack = this.config.maxLookBackRequests || MAX_LOOK_BACK_REQUESTS;
                const actualFrom = Math.max(Number(from), Number(to) - maxLookBack);
                
                const requestIds = await this.routerContract.getCompletedRequests(
                    BigInt(actualFrom), 
                    to
                );
                completedRequests.push(...requestIds);
            }
            
            // Cache the new length on success
            this.cachedCompletedRequestsLength = Number(completedRequestsLength);
        }

        // 3. Filter and return the requests that are not yet responded and match 
        // the node's configuration
        const relevantRequests: RouterRequest[] = [];
        const requestIds: string[] = [];

        for (const requestId of pendingRequests) {
            try {
                const request = await this.routerContract.getRequest(requestId);
                this.logger.debug(`Request: ${request.request}`);
                this.logger.debug(`ExtraParams: ${request.request.extraParams}`);
                
                // Skip if request is already completed
                if (request.completed) {
                    continue;
                }

                // Check if we can serve this request
                if (await this.canServeRequest(request)) {
                    relevantRequests.push(request);
                    requestIds.push(requestId);
                }
            } catch (error) {
                console.error(`Error processing request ${requestId}:`, error);
                // continue;
                throw error;
            }
        }

        return {
            requestIds,
            relevantRequests,
            newLastRequestIdx: Number(pendingRequestsLength),
            newLastResponseIdx: Number(completedRequestsLength)
        };
    }

    /**
     * Check if this node can serve the given request based on configuration
     */
    private async canServeRequest(request: RouterRequest): Promise<boolean> {
        if (!this.nodeId) {
            throw new Error("Node ID is not set");
        }

        // 1. Check if we serve the requested model
        const servesModel = this.servesModel(request.modelId);
        if (!servesModel) {
            this.logger.debug(`Node ${this.nodeId} does not serve model ${request.modelId}`);
            return false;
        }

        // 2. Check if we belong to the relevant trust namespace
        const hasTrustNamespace = this.hasRequiredTrustNamespace(
            request.routing.trustNamespaceIds,
            request.routing.trustedNodeIds
        );
        if (!hasTrustNamespace) {
            this.logger.debug(`Node ${this.nodeId} does not belong to the relevant trust namespace ${request.routing.trustNamespaceIds}`);
            return false;
        }

        // 3. Check if the offered price is within our range
        const priceInRange = this.isPriceInRange(request);
        if (!priceInRange) {
            this.logger.debug(`Price for request ${request.sessionId} not in range. Offerred ${request.request.feePerByteReq}`);
            return false;
        }

        return true;
    }

    /**
     * Check if this node serves the requested model based on config
     */
    private servesModel(modelId: string): boolean {
        return this.models.has(modelId);
    }

    /**
     * Check if this node has the required trust namespace based on config
     */
    private hasRequiredTrustNamespace(
        trustNamespaceIds: string[], 
        trustedNodeIds: string[]
    ): boolean {
        if (!this.nodeId) {
            throw new Error("Node ID is not set");
        }

        // If specific trusted nodes are specified, check if we're one of them
        if (trustedNodeIds.length > 0) {
            if (trustedNodeIds.includes(this.nodeId)) {
                return true;
            }
        }

        // Check if we have ALL the trust namespaces in the request
        // Convert our trust namespaces to their hash values for comparison
        const ourTrustNamespaceHashes = this.config.node.trustNamespaces.map(namespace => namespaceToId(namespace));

        for (const namespaceId of trustNamespaceIds) {
            if (ourTrustNamespaceHashes.includes(namespaceId)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check if the offered price is within our configured range
     */
    private isPriceInRange(request: RouterRequest): boolean {
        const modelConfig = this.models.get(request.modelId);

        if (!modelConfig) {
            return false;
        }

        return request.request.feePerByteReq >= BigInt(modelConfig.priceMinPerByteIn) &&
            request.request.feePerByteRes >= BigInt(modelConfig.priceMinPerByteOut);
    }
}
