import { ethers } from "ethers";
import { AiClient, createAiClient, type AiRequest } from "./aiClient";
import { IpfsClient } from "./ipfsClient";
import { namespaceToId, type NodeConfig, type RouterRequest } from "./types";
import type { RequestParser } from "./RequestParser";
import { AbiDecodeError } from "./RequestParser";
import { AbiCoder } from "ethers";
import { Logger, LogLevel } from "./logger";
import { parseBinaryData, sendWithGasEstimate } from "./EthersUtils";
import { keystoreManager } from "./keystore";

type RespondToRequestParams = [
    requestId: string,
    status: number,
    message: string,
    response: string,
    nodeId: string,
    requestSize: bigint,
    responseSize: bigint,
]

export class ResponseGenerator {
    private provider: ethers.JsonRpcProvider | undefined;
    private wallet: ethers.Wallet | undefined;
    private routerContract: ethers.Contract | undefined;
    private sessionManagerContract: ethers.Contract | undefined;
    private nodeId: string | undefined;
    private models: Map<string, string> | undefined;
    private ipfsClient: IpfsClient | undefined;
    private logger: Logger;

    constructor(private readonly config: NodeConfig, private readonly requestParser: RequestParser, logLevel: LogLevel = LogLevel.INFO) {
        this.logger = new Logger(logLevel);
        this.provider = new ethers.JsonRpcProvider(config.network.rpcUrl);
        
        this.nodeId = namespaceToId(`node.${this.config.node.username}.${this.config.node.nodeName}`);
        this.models = new Map(this.config.node.models.map(m => [namespaceToId(m.name), m.name]));
    }

    /**
     * Initialize wallet with private key from keystore
     */
    private async initializeWallet(): Promise<void> {
        try {
            const privateKey = await keystoreManager.loadPrivateKey(this.config.keys.workerPrivateKey);
            this.wallet = new ethers.Wallet(privateKey, this.provider);

            this.logger.info(`ResponseGenerator: Initializing router contract with address ${this.config.network.routerAddress}`);
            this.logger.info(`ResponseGenerator: Using worker address ${this.wallet.address}`);

            // Initialize router contract
            const contractRaw = new ethers.Contract(
                this.config.network.routerAddress,
                [
                    "function respondToRequest(bytes32 requestId, uint8 status, string message, bytes response, bytes32 nodeId, uint256 requestSize, uint256 responseSize) external"
                ],
                this.wallet
            );
            this.routerContract = contractRaw;

            // Initialize session manager contract for balance checks
            this.sessionManagerContract = new ethers.Contract(
                this.config.network.sessionManagerAddress,
                [
                    "function getSessionById(uint256 sessionId) view returns (tuple(address owner, uint256 balance))"
                ],
                this.provider
            ); 

            // Initialize IPFS client
            this.ipfsClient = new IpfsClient(this.config.ipfs, this.nodeId!);
        } catch (error) {
            throw new Error(`Failed to initialize wallet: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    async generateResponse(requestId: string, request: RouterRequest) {
        // Ensure wallet is initialized before processing
        if (!this.wallet) {
            await this.initializeWallet();
        }
        
        if (!this.provider || !this.wallet || !this.routerContract || !this.nodeId || !this.ipfsClient) {
            throw new Error("ResponseGenerator not properly initialized");
        }

        const aiClient = createAiClient(this.config, request.modelId);

        try {
            // 1. Send the request to the AI client
            this.logger.debug(`Processing request ${requestId} for model ${request.modelId}`);
            
            let parsedRequest: Partial<AiRequest>|undefined;
            try { 
                parsedRequest = await this.requestParser.parseRouterRequest(requestId, request);
            } catch (error) {
                if ((error as any) instanceof AbiDecodeError) {
                    this.logger.debug(`Abi decode error for request ${requestId}:`, (error as AbiDecodeError).message);
                    await this.recordErrorResponse(requestId, (error as AbiDecodeError).message, request, false);
                    return;
                } else {
                    throw error;
                }
            }
            
            // Send request to AI client
            const aiResponse = await aiClient.request({
                requestId: requestId,
                model: this.modelLookup(request.modelId),
                call: parsedRequest!.call!
            });
            
            if (aiResponse.error) {
                console.info(`AI client error for request ${requestId}:`, aiResponse.error);
                await this.recordErrorResponse(requestId, aiResponse.error, request, true);
                return;
            }

            // 2. Handle response based on call type
            let finalResponse: string;
            let responseSize: bigint;

            const responseType = this.requestParser.getApiResponseType(request.modelId);
            const isIPFS = request.request.calltype === BigInt(0);
            if (isIPFS) { // IPFS
                // Get the response type (bytes / string)
                // Store response on IPFS and get CID
                const data = responseType === 'bytes' ? parseBinaryData(aiResponse.data) : aiResponse.data;
                const ipfsCid = await this.storeOnIPFS(data, requestId);
                finalResponse = ipfsCid;
                responseSize = BigInt(aiResponse.data.length);
            } else { // DIRECT
                // Use response directly
                finalResponse = aiResponse.data;
                responseSize = BigInt(finalResponse.length);
            }

            // 3. Calculate request size
            const requestSize = BigInt(request.request.call.length / 2); // Hex string length / 2 = bytes

            // Normalize the sizes to ensure fee calculation stays within limits
            const { normalizedRequestSize, normalizedResponseSize } = this.normalizeDataSizeForFee(
                requestSize,
                responseSize,
                request.request.feePerByteReq,
                request.request.feePerByteRes,
                request.request.totalFeePerRes
            );

            // Check if the session balance is sufficient for the total fee
            const totalFee = normalizedRequestSize * request.request.feePerByteReq + 
                           normalizedResponseSize * request.request.feePerByteRes;
            
            const sessionBalance = await this.getSessionBalance(request.sessionId);
            
            if (sessionBalance < totalFee) {
                this.logger.warn(`Insufficient session balance for request ${requestId}. Required: ${totalFee}, Available: ${sessionBalance}`);
                // Let's just use whatever that is available
                // await this.recordErrorResponse(requestId, "Insufficient session balance", request, true);
                // return;
            }

            // 4. Record successful response on-chain
            await this.recordSuccessResponse(
                requestId,
                finalResponse,
                normalizedRequestSize,
                normalizedResponseSize,
                isIPFS ? "string" : responseType
            );

            console.log(`Successfully processed request ${requestId}`);

        } catch (error) {
            console.error(`Error processing request ${requestId}:`, error);
            throw error;
        }
    }

    private async storeOnIPFS(data: string | Buffer, requestId: string): Promise<string> {
        if (!this.ipfsClient) {
            throw new Error("IPFS client not initialized");
        }
        
        try {
            let cid: string;
            // Handle different data types
            if (typeof data === 'string') {
                // Store as JSON string
                console.log(`Storing data as string for request ${requestId}`);
                cid = await this.ipfsClient.storeText(data, {
                    filename: `response-${requestId}`,
                    metadata: {
                        requestId,
                        dataType: 'string',
                        timestamp: new Date().toISOString()
                    }
                });
            } else if (data instanceof Buffer || data instanceof Uint8Array) {
                // Store as binary data
                console.log(`Storing data as binary data for request ${requestId}`);
                cid = await this.ipfsClient.store(data, {
                    filename: `response-${requestId}`,
                    contentType: 'application/octet-stream',
                    metadata: {
                        requestId,
                        dataType: 'binary',
                        size: data.length,
                        timestamp: new Date().toISOString()
                    }
                });
            } else {
                throw new Error(`Invalid data type: ${typeof data}`);
            }
            console.log(`Data stored on IPFS with CID: ${cid} for request ${requestId}`);
            return cid;
        } catch (error) {
            console.error(`Failed to store data on IPFS for request ${requestId}:`, error);
            throw error;
        }
    }

    private async recordSuccessResponse(
        requestId: string,
        response: string,
        requestSize: bigint,
        responseSize: bigint,
        responseType: string,
    ): Promise<void> {
        if (!this.routerContract || !this.nodeId) {
            throw new Error("Router contract or node ID not initialized");
        }
        const responseData = AbiCoder.defaultAbiCoder().encode(
            [responseType],
            [response]
        );

        try {
            const txResponse = await sendWithGasEstimate<RespondToRequestParams>(
                this.routerContract,
                "respondToRequest",
                [
                requestId,
                1, // ResponseStatus.SUCCESS
                "", // Empty message for success
                responseData,
                this.nodeId,
                requestSize,
                0n, // responseSize
                ]
            );
            console.log(`Recording success response for request ${requestId}, tx: ${txResponse.hash}`);
            const receipt = await txResponse.wait();
            console.log(`Success response recorded for request ${requestId}, gas used: ${receipt?.gasUsed}`);
        } catch (error) {
            console.error(`Failed to record success response for request ${requestId}:`, error);
            throw error;
        }
    }

    private async recordErrorResponse(
        requestId: string,
        errorMessage: string,
        request: RouterRequest,
        aiProcessed: boolean,
    ): Promise<void> {
        if (!this.routerContract || !this.nodeId) {
            throw new Error("Router contract or node ID not initialized");
        }

        // Sanitize and truncate error message for contract
        let safeMessage = errorMessage;
        if (typeof safeMessage !== 'string') {
            safeMessage = String(safeMessage);
        }
        // Only keep the first 100 characters (adjust as needed for your contract)
        if (safeMessage.length > 100) {
            safeMessage = safeMessage.slice(0, 97) + '...';
        }

        this.logger.debug(`Recording error response for request ${requestId}: ${safeMessage}`);
        try {
            const requestSize = BigInt(request.request.call.length / 2);
            const responseSize = BigInt(0); // No response for error

            // Normalize sizes for consistency (even though response size is 0)
            const { normalizedRequestSize, normalizedResponseSize } = this.normalizeDataSizeForFee(
                aiProcessed ? requestSize : BigInt(0),
                responseSize,
                request.request.feePerByteReq,
                request.request.feePerByteRes,
                request.request.totalFeePerRes
            );

            const txResponse = await sendWithGasEstimate<RespondToRequestParams>(
                this.routerContract,
                "respondToRequest",
                [
                requestId,
                2, // ResponseStatus.FAILURE
                safeMessage,
                "0x", // Empty response for failure
                this.nodeId,
                normalizedRequestSize,
                normalizedResponseSize
                ]
            );
            console.log(`Recording error response for request ${requestId}, tx: ${txResponse.hash}`);
            const receipt = await txResponse.wait();
            console.log(`Error response recorded for request ${requestId}, gas used: ${receipt?.gasUsed}`);
        } catch (error) {
            console.error(`Failed to record error response for request ${requestId}:`, error);
            throw error;
        }
    }

    private modelLookup(modelId: string): string {
        const model = this.models?.get(modelId);
        if (!model) {
            throw new Error(`Model ${modelId} not found in config`);
        }
        return model;
    }

    /**
     * Gets the session balance by calling the session manager contract directly
     * @param sessionId - The session ID to check
     * @returns The session balance
     */
    private async getSessionBalance(sessionId: bigint): Promise<bigint> {
        if (!this.sessionManagerContract) {
            throw new Error("Session manager contract not initialized");
        }

        try {
            // Call the session manager's getSessionById function directly
            const session = await this.sessionManagerContract!.getSessionById!(sessionId);
            return session.balance;
        } catch (error) {
            this.logger.error(`Failed to get session balance for session ${sessionId}:`, error);
            // Return 0 if we can't get the balance, which will trigger the insufficient balance check
            return BigInt(0);
        }
    }

    /**
     * Normalizes request and response sizes to ensure the total fee calculation
     * stays within the allowed limit (totalFeePerRes).
     * 
     * @param requestSize - Original request size in bytes
     * @param responseSize - Original response size in bytes
     * @param feePerByteReq - Fee per byte for request
     * @param feePerByteRes - Fee per byte for response
     * @param totalFeePerRes - Maximum total fee allowed
     * @returns Object containing normalized request and response sizes
     */
    private normalizeDataSizeForFee(
        requestSize: bigint,
        responseSize: bigint,
        feePerByteReq: bigint,
        feePerByteRes: bigint,
        totalFeePerRes: bigint
    ): { normalizedRequestSize: bigint; normalizedResponseSize: bigint } {
        // Calculate the total fee with current sizes
        const totalFee = requestSize * feePerByteReq + responseSize * feePerByteRes;
        
        // If we're already within the limit, return original sizes
        if (totalFee <= totalFeePerRes) {
            return {
                normalizedRequestSize: requestSize,
                normalizedResponseSize: responseSize
            };
        }

        // Calculate how much we need to reduce
        const excessFee = totalFee - totalFeePerRes;
        
        // If feePerByteRes is 0, we can only reduce request size
        if (feePerByteRes === BigInt(0)) {
            if (feePerByteReq === BigInt(0)) {
                // Both fees are 0, return original sizes
                return {
                    normalizedRequestSize: requestSize,
                    normalizedResponseSize: responseSize
                };
            }
            
            // Only reduce request size
            const requestSizeReduction = excessFee / feePerByteReq;
            const normalizedRequestSize = requestSize > requestSizeReduction 
                ? requestSize - requestSizeReduction 
                : BigInt(0);
            
            return {
                normalizedRequestSize,
                normalizedResponseSize: responseSize
            };
        }

        // If feePerByteReq is 0, we can only reduce response size
        if (feePerByteReq === BigInt(0)) {
            const responseSizeReduction = excessFee / feePerByteRes;
            const normalizedResponseSize = responseSize > responseSizeReduction 
                ? responseSize - responseSizeReduction 
                : BigInt(0);
            
            return {
                normalizedRequestSize: requestSize,
                normalizedResponseSize
            };
        }

        // Both fees are non-zero, distribute reduction proportionally
        // Calculate the ratio of response fee to total fee
        const responseFeeRatio = (responseSize * feePerByteRes) / totalFee;
        const requestFeeRatio = BigInt(1) - responseFeeRatio;
        
        // Distribute the excess fee reduction proportionally
        const responseFeeReduction = (excessFee * responseFeeRatio) / feePerByteRes;
        const requestFeeReduction = (excessFee * requestFeeRatio) / feePerByteReq;
        
        // Apply reductions with safety checks
        const normalizedResponseSize = responseSize > responseFeeReduction 
            ? responseSize - responseFeeReduction 
            : BigInt(0);
        const normalizedRequestSize = requestSize > requestFeeReduction 
            ? requestSize - requestFeeReduction 
            : BigInt(0);
        
        return {
            normalizedRequestSize,
            normalizedResponseSize
        };
    }
}