import { ethers } from "ethers";
import { createAiClient } from "./aiClient";
import { IpfsClient } from "./ipfsClient";
import type { NodeConfig, RouterRequest } from "./types";
import type { RequestParser } from "./RequestParser";
import { AbiCoder } from "ethers";

// Router contract interface for responding to requests
interface RouterContract {
    respondToRequest(
        requestId: string,
        status: number,
        message: string,
        response: string,
        nodeId: string,
        requestSize: bigint,
        responseSize: bigint
    ): Promise<ethers.ContractTransactionResponse>;
}

export class ResponseGenerator {
    private provider: ethers.JsonRpcProvider | undefined;
    private wallet: ethers.Wallet | undefined;
    private routerContract: RouterContract | undefined;
    private nodeId: string | undefined;
    private ipfsClient: IpfsClient | undefined;

    constructor(private readonly config: NodeConfig, private readonly requestParser: RequestParser) {
        this.provider = new ethers.JsonRpcProvider(config.network.rpcUrl);
        const privateKey = process.env[config.keys.workerPrivateKey];
        if (!privateKey) {
            throw new Error("Worker private key is not set");
        }
        this.wallet = new ethers.Wallet(privateKey, this.provider);
        
        // Initialize router contract
        this.routerContract = new ethers.Contract(
            config.network.routerAddress,
            [
                "function respondToRequest(bytes32 requestId, uint8 status, string message, string response, bytes32 nodeId, uint256 requestSize, uint256 responseSize) external"
            ],
            this.wallet
        ) as unknown as RouterContract;

        // Initialize IPFS client
        this.ipfsClient = new IpfsClient(config.ipfs);

        // Calculate node ID from worker address
        this.nodeId = ethers.keccak256(ethers.toUtf8Bytes(this.config.node.worker));
    }

    async generateResponse(requestId: string, request: RouterRequest) {
        if (!this.provider || !this.wallet || !this.routerContract || !this.nodeId || !this.ipfsClient) {
            throw new Error("ResponseGenerator not properly initialized");
        }

        const aiClient = createAiClient(this.config, request.modelId);

        try {
            // 1. Send the request to the AI client
            console.log(`Processing request ${requestId} for model ${request.modelId}`);
            
            // Send request to AI client
            const aiResponse = await aiClient.request(
                await this.requestParser.parseRouterRequest(requestId, request));
            
            if (aiResponse.error) {
                console.info(`AI client error for request ${requestId}:`, aiResponse.error);
                await this.recordErrorResponse(requestId, aiResponse.error, request);
                return;
            }

            // 2. Handle response based on call type
            let finalResponse: string;
            let responseSize: bigint;

            const responseType = this.requestParser.getApiResponseType(request.modelId);
            if (request.request.calltype === 0) { // IPFS
                // Get the response type (bytes / string)
                // Store response on IPFS and get CID
                const ipfsCid = await this.storeOnIPFS(aiResponse.data, requestId, responseType);
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
                responseType
            );

            console.log(`Successfully processed request ${requestId}`);

        } catch (error) {
            console.error(`Error processing request ${requestId}:`, error);
            await this.recordErrorResponse(requestId, error instanceof Error ? error.message : "Unknown error", request);
        }
    }

    private async storeOnIPFS(data: string | Buffer | Uint8Array | object, requestId: string, responseType: string): Promise<string> {
        if (responseType !== "bytes" && responseType !== "string") {
            throw new Error("Invalid response type (only bytes or string are supported for IPFS)");
        }

        if (!this.ipfsClient) {
            throw new Error("IPFS client not initialized");
        }
        
        try {
            console.log(`Storing data on IPFS for request ${requestId}...`);
            
            let cid: string;
            
            // Handle different data types
            if (typeof data === 'string') {
                // Store as JSON string
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
                cid = await this.ipfsClient.store(data, {
                    filename: `response-${requestId}.bin`,
                    contentType: 'application/octet-stream',
                    metadata: {
                        requestId,
                        dataType: 'binary',
                        size: data.length,
                        timestamp: new Date().toISOString()
                    }
                });
            } else if (typeof data === 'object') {
                // Store as JSON object
                cid = await this.ipfsClient.storeJson(data, {
                    filename: `response-${requestId}.json`,
                    metadata: {
                        requestId,
                        dataType: 'object',
                        timestamp: new Date().toISOString()
                    }
                });
            } else {
                // Convert to string and store
                cid = await this.ipfsClient.store(String(data), {
                    filename: `response-${requestId}.txt`,
                    contentType: 'text/plain',
                    metadata: {
                        requestId,
                        dataType: 'text',
                        timestamp: new Date().toISOString()
                    }
                });
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
            const txResponse = await this.routerContract.respondToRequest(
                requestId,
                1, // ResponseStatus.SUCCESS
                "", // Empty message for success
                responseData,
                this.nodeId,
                requestSize,
                responseSize
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
        request: RouterRequest
    ): Promise<void> {
        if (!this.routerContract || !this.nodeId) {
            throw new Error("Router contract or node ID not initialized");
        }

        try {
            const requestSize = BigInt(request.request.call.length / 2);
            const responseSize = BigInt(0); // No response for error

            const txResponse = await this.routerContract.respondToRequest(
                requestId,
                2, // ResponseStatus.FAILURE
                errorMessage,
                "", // Empty response for failure
                this.nodeId,
                requestSize,
                responseSize
            );

            console.log(`Recording error response for request ${requestId}, tx: ${txResponse.hash}`);
            const receipt = await txResponse.wait();
            console.log(`Error response recorded for request ${requestId}, gas used: ${receipt?.gasUsed}`);
        } catch (error) {
            console.error(`Failed to record error response for request ${requestId}:`, error);
            throw error;
        }
    }
}