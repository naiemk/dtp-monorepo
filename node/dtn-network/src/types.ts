import { ethers } from "ethers";

export interface CustomModelConfig {
    name: string;
    api: string;
}

export interface ModelApiConfig {
    specs: string;
    docs: string;
}

export interface ModelConfig {
    name: string;
    priceMinPerByteIn: number;
    priceMaxPerByteOut: number;
    host: string;
}

export interface IpfsConfig {
    apiKey: string;
    secretKey: string;
    gateway?: string;
}

export interface NodeConfig {
    local: {
        cacheDir: string;
    }
    keys: {
        ownerPrivateKey: string;
        workerPrivateKey: string;
    };
    network: {
        rpcUrl: string;
        chainId: number;
        nodeManagerAddress: string;
        modelManagerAddress: string;
        routerAddress: string;
    };
    ipfs: IpfsConfig;
    modelApis: { [key: string]: ModelApiConfig };
    customModels: CustomModelConfig[];
    node: {
        username: string;
        nodeName: string;
        worker: string;
    };
    models: ModelConfig[];
    trustNamespaces: string[];
    maxLookBackRequests?: number; // Maximum number of requests to process in a single call
}

// /**
//  * Represents different types of AI call responses
//  */
// export enum CallType {
//     IPFS = 0,      // Response will be stored on IPFS
//     DIRECT = 1     // Response will be returned directly
// }

// /**
//  * Represents different aggregation types for multiple responses
//  */
// export enum AggregationType {
//     ANY = 0,
//     ALL = 1,
//     SELECT_BEST = 2,
//     VOTE = 3,
//     RANK = 4
// }

// /**
//  * Represents the status of an AI response
//  */
// export enum ResponseStatus {
//     NA = 0,
//     SUCCESS = 1,
//     FAILURE = 2
// }

// /**
//  * Structure for AI request parameters
//  */
// export interface DtnRequest {
//     call: string;                    // Encoded call data (hex string)
//     calltype: CallType;              // Type of response expected
//     feePerByteReq: bigint;           // Fee per byte for request size
//     feePerByteRes: bigint;           // Fee per byte for response size
//     totalFeePerRes: bigint;          // Maximum total fee for response
// }

// /**
//  * Structure for routing configuration
//  */
// export interface DtnRouting {
//     trustNamespaceIds: string[];     // Array of trust namespace IDs (hex strings)
//     trustedNodeIds: string[];        // Array of trusted node IDs (hex strings)
//     redundancy: number;              // How many nodes will answer the same request
//     confidenceLevel: number;         // 0 - 10 confidence level
//     aggregationType: AggregationType; // Type of aggregation for multiple responses
// }

// /**
//  * Structure for AI response
//  */
// export interface DtnResponse {
//     status: ResponseStatus;          // Response status code
//     message: string;                 // Additional message or error details
//     response: string;                // The actual response data
//     nodeId: string;                  // ID of the node that provided the response (hex string)
//     timestamp: bigint;               // When the response was provided
// }

// /**
//  * Callback structure for handling AI responses
//  */
// export interface DtnCallback {
//     success: string;                 // Function selector for successful response (hex string)
//     failure: string;                 // Function selector for failed response (hex string)
//     target: string;                  // Contract address to call back (hex string)
// }

// /**
//  * Structure for a complete request as stored in the router contract
//  */
// export interface Request {
//     sessionId: bigint;               // Session ID for the request
//     user: string;                    // Address of the user making the request (hex string)
//     completed: boolean;              // Whether the request has been completed
//     modelId: string;                 // ID of the AI model to use (hex string)
//     routing: DtnRouting;             // Routing configuration for the request
//     request: DtnRequest;             // The actual AI request parameters
//     callback: DtnCallback;           // Callback configuration for handling responses
//     callbackGas: bigint;             // Gas limit for callback execution
//     responseCount: bigint;           // Number of responses received so far
//     finalResponse: DtnResponse;      // Final aggregated response (if completed)
// }

/**
 * Structure for a request as returned by the router contract's getRequest method
 */
export interface RouterRequest {
    sessionId: bigint;
    user: string;
    completed: boolean;
    modelId: string;
    routing: {
        trustNamespaceIds: string[];
        trustedNodeIds: string[];
        redundancy: number;
        confidenceLevel: number;
        aggregationType: number;
    };
    request: {
        call: string;
        extraParams: string;
        calltype: number;
        feePerByteReq: bigint;
        feePerByteRes: bigint;
        totalFeePerRes: bigint;
    };
    callback: {
        suscess: string;
        failure: string;
        target: string;
    };
    callbackGas: bigint;
    responseCount: bigint;
    finalResponse: {
        status: number;
        message: string;
        response: string;
        nodeId: string;
        timestamp: bigint;
    };
}

export function namespaceToId(namespace: string): string {
    return ethers.solidityPackedKeccak256(['string'], [namespace]);
}