import type { RequestReader } from "./requestReader";
import type { ResponseGenerator } from "./responseGenerator";
import type { NodeConfig } from "./types";
import path from "path";
import fs from "fs";

export class DtnService {
    private lastRequestIdx: number = 0;
    private lastResponseIdx: number = 0;

    constructor(
        private readonly config: NodeConfig,
        private readonly requestReader: RequestReader,
        private readonly responseGenerator: ResponseGenerator,
    ) {
        this.loadStats();
    }

    async processRequests() {
        const { requestIds, relevantRequests, newLastRequestIdx, newLastResponseIdx } = await this.requestReader.fetchRelevantRequests(
            this.lastRequestIdx, this.lastResponseIdx);
        this.updateStats(newLastRequestIdx, newLastResponseIdx);
        for (let i = 0; i < requestIds.length; i++) {
            await this.responseGenerator.generateResponse(requestIds[i]!, relevantRequests[i]!);
        }
    }

    private loadStats() {
        const statsFile = path.join(this.config.local.cacheDir, "stats.json");
        if (fs.existsSync(statsFile)) {
            const stats = JSON.parse(fs.readFileSync(statsFile, "utf8"));
            this.lastRequestIdx = stats.lastRequestIdx;
            this.lastResponseIdx = stats.lastResponseIdx;
        }
    }

    private updateStats(newLastRequestIdx: number, newLastResponseIdx: number) {
        this.lastRequestIdx = newLastRequestIdx;
        this.lastResponseIdx = newLastResponseIdx;
        const statsFile = path.join(this.config.local.cacheDir, "stats.json");
        fs.writeFileSync(statsFile, JSON.stringify({ lastRequestIdx: this.lastRequestIdx, lastResponseIdx: this.lastResponseIdx }));
    }
}