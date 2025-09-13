import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import type { PinataConfig } from "../src/ipfsClient";
import { IpfsClient } from "../src/ipfsClient";
import dotenv from "dotenv";
dotenv.config({ path: './localConfig/.env' });

const PINATA_JWT = process.env.PINATA_JWT_TOKEN;

const config: PinataConfig = {
    pinataJwt: PINATA_JWT,
    gateway: 'https://gateway.pinata.cloud',
};

describe("IpfsClient Integration", () => {
    let client: IpfsClient;
    let cids: string[] = [];
    const nodeId = "integration-test-node";

    beforeAll(() => {
        if (!PINATA_JWT ) {
            console.log('Skipping IPFS integration tests - PINATA_JWT_TOKEN not configured');
            return;
        }
        client = new IpfsClient(config, nodeId);
    });

    afterAll(async () => {
        for (const cid of cids) {
            try { await client.unpin(cid); } catch {}
        }
    });

    it("should write and read text data to IPFS", async () => {
        if (!PINATA_JWT ) {
            console.log('Skipping test - PINATA_JWT_TOKEN not configured');
            return;
        }
        try {
            const text = "Hello, IPFS! Integration test.";
            const cid = await client.store(text, { filename: "test.txt", contentType: "text/plain" });
            cids.push(cid);
            const retrieved = await client.retrieve(cid);
            expect(retrieved).toBe(text);
            console.log("Text CID:", cid);
        } catch (error) {
            if (error instanceof Error && (error.message?.includes('Authentication failed') || error.message?.includes('Not Authorized'))) {
                console.log('Skipping test - Invalid Pinata JWT token');
                return;
            }
            throw error;
        }
    }, 30000);

    it("should write and read binary data to IPFS", async () => {
        if (!PINATA_JWT || PINATA_JWT === 'your_pinata_jwt_token_here') {
            console.log('Skipping test - PINATA_JWT_TOKEN not configured');
            return;
        }
        try {
            const buffer = Buffer.from([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
            const cid = await client.store(buffer, { filename: "test.bin", contentType: "application/octet-stream" });
            cids.push(cid);
            const retrieved = await client.retrieveBinary(cid);
            expect(Buffer.compare(buffer, retrieved)).toBe(0);
            console.log("Binary CID:", cid);
        } catch (error) {
            if (error instanceof Error && (error.message?.includes('Authentication failed') || error.message?.includes('Not Authorized'))) {
                console.log('Skipping test - Invalid Pinata JWT token');
                return;
            }
            throw error;
        }
    }, 30000);
}); 