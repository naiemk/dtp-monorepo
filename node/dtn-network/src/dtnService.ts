import type { RequestReader } from "./requestReader";
import type { ResponseGenerator } from "./responseGenerator";
import type { NodeConfig } from "./types";
import { Logger, LogLevel } from "./logger";
import path from "path";
import fs from "fs";

export class DtnService {
    private lastRequestIdx: number = 0;
    private lastResponseIdx: number = 0;
    private logger: Logger;

    constructor(
        private readonly config: NodeConfig,
        private readonly requestReader: RequestReader,
        private readonly responseGenerator: ResponseGenerator,
        logLevel: LogLevel = LogLevel.INFO,
    ) {
        this.loadStats();
        this.logger = new Logger(logLevel);
    }

    async processRequests() {
        this.logger.info(`DTN Service: Starting request processing - Last Request Index: ${this.lastRequestIdx}, Last Response Index: ${this.lastResponseIdx}`);
        
        const { requestIds, relevantRequests, newLastRequestIdx, newLastResponseIdx } = await this.requestReader.fetchRelevantRequests(
            this.lastRequestIdx, this.lastResponseIdx);
        
        const totalRequestsRead = newLastRequestIdx - this.lastRequestIdx;
        const relevantRequestsCount = requestIds.length;
        
        this.logger.info(`DTN Service: Request processing summary:`);
        this.logger.info(`  - Total requests read: ${totalRequestsRead}`);
        this.logger.info(`  - Relevant requests found: ${relevantRequestsCount}`);
        this.logger.info(`  - Processing ${relevantRequestsCount} requests...`);
        
        let processedCount = 0;
        for (let i = 0; i < requestIds.length; i++) {
            const requestId = requestIds[i]!;
            const request = relevantRequests[i]!;
            
            this.logger.debug(`DTN Service: Processing request ${i + 1}/${relevantRequestsCount} - ID: ${requestId}`);
            await this.responseGenerator.generateResponse(requestId, request);
            processedCount++;
        }
        
        this.logger.info(`DTN Service: Request processing completed - ${processedCount} requests processed successfully`);
        this.logger.debug(`DTN Service: Updated indices - Last Request Index: ${this.lastRequestIdx}, Last Response Index: ${this.lastResponseIdx}`);
        this.updateStats(newLastRequestIdx, newLastResponseIdx);
    }

    private loadStats() {
        const statsFile = path.join(this.config.local.cacheDir, "stats.json");
        
        // Create cache directory if it doesn't exist
        const cacheDir = path.dirname(statsFile);
        if (!fs.existsSync(cacheDir)) {
            fs.mkdirSync(cacheDir, { recursive: true });
        }
        
        if (fs.existsSync(statsFile)) {
            const stats = JSON.parse(fs.readFileSync(statsFile, "utf8"));
            this.lastRequestIdx = stats.lastRequestIdx;
            this.lastResponseIdx = stats.lastResponseIdx;
        } else {
            // Initialize with default values if file doesn't exist
            this.lastRequestIdx = 0;
            this.lastResponseIdx = 0;
            // Create the file with default values
            fs.writeFileSync(statsFile, JSON.stringify({ 
                lastRequestIdx: this.lastRequestIdx, 
                lastResponseIdx: this.lastResponseIdx 
            }));
        }
    }

    private updateStats(newLastRequestIdx: number, newLastResponseIdx: number) {
        this.lastRequestIdx = newLastRequestIdx;
        this.lastResponseIdx = newLastResponseIdx;
        const statsFile = path.join(this.config.local.cacheDir, "stats.json");
        fs.writeFileSync(statsFile, JSON.stringify({ lastRequestIdx: this.lastRequestIdx, lastResponseIdx: this.lastResponseIdx }));
    }
}