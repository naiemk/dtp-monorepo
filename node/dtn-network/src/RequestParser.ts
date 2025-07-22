import { AbiCoder, ethers } from "ethers";
import type { NodeConfig, RouterRequest } from "./types";
import type { AiRequest } from "./aiClient";
import { Logger, LogLevel } from "./logger";
import { ERROR_CODES } from "./errors";

interface ModelApi {
    apiNamespaceId: string;
    apiName: string;
    apiId: string;
    specs: string;
    docs: string;
}

interface ModelManagerContract {
    getModelAPI(modelId: string): Promise<ModelApi>;
}

// Custom error for ABI decoding
export class AbiDecodeError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'AbiDecodeError';
    }
}

export class RequestParser {
    private modelManagerContract: ModelManagerContract | undefined;
    private modelAPIs: { [modelId: string]: ModelApi } = {};
    private provider: ethers.JsonRpcProvider | undefined;
    private logger: Logger;

    constructor(private readonly config: NodeConfig, logLevel: LogLevel = LogLevel.INFO) {
        this.logger = new Logger(logLevel);
        this.provider = new ethers.JsonRpcProvider(config.network.rpcUrl);
        this.modelManagerContract = new ethers.Contract(
            config.network.modelManagerAddress,
            [
                "function getModelAPI(bytes32 modelId) view returns (tuple(bytes32 apiNamespaceId,string apiName,bytes32 apiId,string specs,string docs))"
            ],
            this.provider
        ) as unknown as ModelManagerContract;
    }

    async parseRouterRequest(requestId: string, request: RouterRequest): Promise<AiRequest> {
        // Get the model API specification
        let modelApi = this.modelAPIs[request.modelId];
        if (!modelApi) {
            this.logger.debug(`Getting model API for model ${request.modelId} from model manager contract ${this.config.network.modelManagerAddress}`);
            modelApi = await this.modelManagerContract!.getModelAPI(request.modelId);
            if (!modelApi) {
                throw new Error(`Model API not found for model ${request.modelId}`);
            }
            this.modelAPIs[request.modelId] = modelApi;
            this.logger.debug(`Received model API for model ${request.modelId}: ${JSON.stringify(modelApi)}`);
        }

        // Parse the model API specs to get parameter types
        const apiParameterTypes = modelApi.specs.split('->')[0]!.replace(/\s/g, "").split(",");
        const call = request.request.call;
        const extraParams = request.request.extraParams;

        let modelParams;
        try {
            // Decode the main call parameters
            modelParams = AbiCoder.defaultAbiCoder().decode(apiParameterTypes, call);
        } catch (err) {
            this.logger.error(`ABI decode error for call: ${err}`);
            throw new AbiDecodeError(`${ERROR_CODES.P0011.code}: ${ERROR_CODES.P0011.message}`);
        }
        this.logger.debug(`Model params: ${JSON.stringify(modelParams)}`);
        
        // Extract parameter types from decoded values that contain placeholders
        const extractedParameterTypes: string[] = [];
        
        // Process all decoded parameters to extract types
        modelParams.forEach(param => this.extractTypesFromValue(param, extractedParameterTypes));
        
        let extraModelParams: any[] = [];
        if (extractedParameterTypes.length > 0) {
            try {
                // Decode the extra parameters using the extracted parameter types
                extraModelParams = AbiCoder.defaultAbiCoder().decode(extractedParameterTypes, extraParams);
            } catch (err) {
                this.logger.error(`ABI decode error for extraParams: ${err}`);
                throw new AbiDecodeError(`${ERROR_CODES.P0011.code}: ${ERROR_CODES.P0011.message}`);
            }
        }
        
        // Apply placeholder replacement to all parameters
        const processedParams = modelParams.map(param => this.replacePlaceholders(param, extraModelParams));
        
        // Create the formatted call object
        const formattedCall = {
            parameters: processedParams,
            types: apiParameterTypes,
        };
        
        this.logger.debug(`Formatted call: ${JSON.stringify(formattedCall)}`);
        
        return {
            requestId: requestId,
            model: request.modelId,
            call: formattedCall
        };
    }

    getApiResponseType(modelId: string): string {
        const modelApi = this.modelAPIs[modelId];
        if (!modelApi) {
            throw new Error(`Model API not found for model ${modelId}`);
        }
        return modelApi.specs.split('->')[1]!.replace(/\s/g, "");
    }

    /**
     * Replace placeholders in the original values with the decoded extra parameters
     */
    private replacePlaceholders(value: any, extraModelParams: any[]): any {
        if (typeof value === 'string') {
            // Replace placeholders like {0}, {1:bytes32}, etc. with actual values
            return value.replace(/\{(\d+)(?::([^}]+))?\}/g, (match, indexStr) => {
                const index = parseInt(indexStr);
                if (index < extraModelParams.length) {
                    return String(extraModelParams[index]);
                }
                return match; // Keep original if index out of bounds
            });
        } else if (Array.isArray(value)) {
            // Recursively process array elements
            return value.map(v => this.replacePlaceholders(v, extraModelParams));
        }
        return value;
    }

    /**
     * Extract parameter types from decoded values that contain placeholders
     */
    private extractTypesFromValue(value: any, extractedParameterTypes: string[]): void {
        if (typeof value === 'string') {
            // Find all placeholders like {0}, {1:bytes32}, etc.
            const placeholderRegex = /\{(\d+)(?::([^}]+))?\}/g;
            let match;
            while ((match = placeholderRegex.exec(value)) !== null) {
                const index = parseInt(match[1]!);
                const type = match[2] ? match[2] : 'string'; // Default to string if no type specified
                
                // Ensure we have enough slots in the array
                while (extractedParameterTypes.length <= index) {
                    extractedParameterTypes.push('string');
                }
                extractedParameterTypes[index] = type;
            }
        } else if (Array.isArray(value)) {
            // Recursively process array elements
            value.forEach(v => this.extractTypesFromValue(v, extractedParameterTypes));
        }
    }
}