import { ethers } from "ethers";
import { AiClient, createAiClient, type AiRequest } from "./aiClient";
import { IpfsClient } from "./ipfsClient";
import { namespaceToId, type NodeConfig, type RouterRequest } from "./types";
import type { RequestParser } from "./RequestParser";
import { AbiDecodeError } from "./RequestParser";
import { AbiCoder } from "ethers";
import { Logger, LogLevel } from "./logger";
import { parseBinaryData, sendWithGasEstimate } from "./EthersUtils";

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
    private nodeId: string | undefined;
    private models: Map<string, string> | undefined;
    private ipfsClient: IpfsClient | undefined;
    private logger: Logger;

    constructor(private readonly config: NodeConfig, private readonly requestParser: RequestParser, logLevel: LogLevel = LogLevel.INFO) {
        this.logger = new Logger(logLevel);
        this.provider = new ethers.JsonRpcProvider(config.network.rpcUrl);
        const privateKey = process.env[config.keys.workerPrivateKey];
        if (!privateKey) {
            throw new Error("Worker private key is not set");
        }
        this.wallet = new ethers.Wallet(privateKey, this.provider);

        this.logger.info(`ResponseGenerator: Initializing router contract with address ${config.network.routerAddress}`);
        this.logger.info(`ResponseGenerator: Using worker address ${this.wallet?.address}`);

        // Initialize router contract
        const contractRaw = new ethers.Contract(
            config.network.routerAddress,
            [
                "function respondToRequest(bytes32 requestId, uint8 status, string message, bytes response, bytes32 nodeId, uint256 requestSize, uint256 responseSize) external"
            ],
            this.wallet
        );
        this.routerContract = contractRaw; 

        this.nodeId = namespaceToId(`node.${this.config.node.username}.${this.config.node.nodeName}`);
        // Initialize IPFS client
        this.ipfsClient = new IpfsClient(config.ipfs, this.nodeId);

        // Calculate node ID from worker address
        this.models = new Map(this.config.node.models.map(m => [namespaceToId(m.name), m.name]));
    }

    async generateResponse(requestId: string, request: RouterRequest) {
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

            // 4. Record successful response on-chain
            await this.recordSuccessResponse(
                requestId,
                finalResponse,
                requestSize,
                responseSize,
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
                console.log(`Storing data as JSON string for request ${requestId}`);
                cid = await this.ipfsClient.storeJson(data, {
                    filename: `response-${requestId}.json`,
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
                responseSize
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

            const txResponse = await sendWithGasEstimate<RespondToRequestParams>(
                this.routerContract,
                "respondToRequest",
                [
                requestId,
                2, // ResponseStatus.FAILURE
                safeMessage,
                "0x", // Empty response for failure
                this.nodeId,
                aiProcessed ? requestSize : BigInt(0),
                responseSize
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
}