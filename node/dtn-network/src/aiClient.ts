import { namespaceToId, type NodeConfig, type RouterRequest } from "./types";
import { Logger, LogLevel } from "./logger";

export interface AiResponse {
    requestId: string;
    data: string;
    datatype: string;
    error: string | null;
}

export interface AiRequest {
    requestId: string;
    model: string;
    call: {
        parameters: any[];
        types: string[];
    }; // JSON object for the call data
}

export class AiClient {
    private logger: Logger;

    constructor(private readonly host: string, logLevel: LogLevel = LogLevel.INFO) {
        this.logger = new Logger(logLevel);
    }

    async request(request: AiRequest): Promise<AiResponse> {
        this.logger.debug(`AI client request to ${this.host}: ${JSON.stringify(request)}`);
        const response = await fetch(this.host, {
            method: "POST",
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ ...request }),
        });
        
        if (!response.ok) {
            throw new Error(`AI client request failed: ${response.status} ${response.statusText}`);
        }
        
        return await response.json() as AiResponse;
    }
}

export function createAiClient(config: NodeConfig, modelId: string): AiClient {
    const modelConfig = config.node.models.find(m => namespaceToId(m.name) === modelId);
    if (!modelConfig) {
        throw new Error(`Model ${modelId} not found in config`);
    }
    return new AiClient(modelConfig.host);
}