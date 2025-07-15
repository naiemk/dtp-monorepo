import { describe, it, expect, beforeEach, mock } from "bun:test";
import { ethers } from "ethers";
import { RequestParser } from "../src/RequestParser";
import type { NodeConfig, RouterRequest } from "../src/types";

// Mock the ethers.Contract constructor
const mockGetModelAPI = mock(() => Promise.resolve({
    apiNamespaceId: "test-namespace",
    apiName: "test-api",
    apiId: "test-api-id",
    specs: "string, uint64, uint64 -> bytes",
    docs: "Test API documentation"
}));

const mockContract = {
    getModelAPI: mockGetModelAPI
};

mock.module("ethers", () => ({
    ...ethers,
    Contract: mock(() => mockContract)
}));

const minimalRequestFields = {
    calltype: 0,
    feePerByteReq: 0n,
    feePerByteRes: 0n,
    totalFeePerRes: 0n
};

describe("RequestParser", () => {
    let requestParser: RequestParser;
    let mockConfig: NodeConfig;

    beforeEach(() => {
        mockConfig = {
            local: { cacheDir: "/tmp" },
            keys: { ownerPrivateKey: "0x", workerPrivateKey: "0x" },
            network: { rpcUrl: "", chainId: 0, nodeManagerAddress: "0x", modelManagerAddress: "0x", routerAddress: "0x" },
            ipfs: { apiKey: "", secretKey: "" },
            modelApis: {},
            customModels: [],
            node: { username: "", nodeName: "", worker: "" },
            models: [],
            trustNamespaces: []
        };
        requestParser = new RequestParser(mockConfig);
    });

    describe("parseRouterRequest", () => {
        it("should parse simple parameters without placeholders", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve({
                apiNamespaceId: "test-namespace",
                apiName: "test-api",
                apiId: "test-api-id",
                specs: "string, uint64, uint64 -> bytes",
                docs: "Test API documentation"
            }));
            const call = ethers.AbiCoder.defaultAbiCoder().encode(["string", "uint64", "uint64"], ["Test", 1n, 2n]);
            const routerRequest: Partial<RouterRequest> = {
                modelId: "test-model-id",
                request: { call, extraParams: "0x", ...minimalRequestFields }
            };
            const result = await requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest);
            expect(result).toEqual({
                requestId: "test-request-id",
                model: "test-model-id",
                call: { parameters: ["Test", 1n, 2n], types: ["string", "uint64", "uint64"] }
            });
        });

        it("should parse parameters with placeholder substitution", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve({
                apiNamespaceId: "test-namespace",
                apiName: "test-api",
                apiId: "test-api-id",
                specs: "string, bool -> bytes",
                docs: "Test API documentation"
            }));
            const randomAddress = "0x1234567890123456789012345678901234567890";
            const call = ethers.AbiCoder.defaultAbiCoder().encode(["string", "bool"], ["This {0} is {1:uint} and {0} then {2:address}?", false]);
            const extraParams = ethers.AbiCoder.defaultAbiCoder().encode(["string", "uint", "address"], ["mystr", 12, randomAddress]);
            const routerRequest: Partial<RouterRequest> = {
                modelId: "test-model-id",
                request: { call, extraParams, ...minimalRequestFields }
            };
            const result = await requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest);
            expect(result).toEqual({
                requestId: "test-request-id",
                model: "test-model-id",
                call: { parameters: [`This mystr is 12 and mystr then ${randomAddress}?`, false], types: ["string", "bool"] }
            });
        });

        it("should handle array parameters with placeholders", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve({
                apiNamespaceId: "test-namespace",
                apiName: "test-api",
                apiId: "test-api-id",
                specs: "string[], uint256 -> bytes",
                docs: "Test API documentation"
            }));
            const call = ethers.AbiCoder.defaultAbiCoder().encode(["string[]", "uint256"], [["Hello {0}", "World {1:uint}"], 100n]);
            const extraParams = ethers.AbiCoder.defaultAbiCoder().encode(["string", "uint"], ["Alice", 42]);
            const routerRequest: Partial<RouterRequest> = {
                modelId: "test-model-id",
                request: { call, extraParams, ...minimalRequestFields }
            };
            const result = await requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest);
            expect(result).toEqual({
                requestId: "test-request-id",
                model: "test-model-id",
                call: { parameters: [["Hello Alice", "World 42"], 100n], types: ["string[]", "uint256"] }
            });
        });

        it("should handle multiple placeholders in same string", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve({
                apiNamespaceId: "test-namespace",
                apiName: "test-api",
                apiId: "test-api-id",
                specs: "string, uint256 -> bytes",
                docs: "Test API documentation"
            }));
            const call = ethers.AbiCoder.defaultAbiCoder().encode(["string", "uint256"], ["Hello {0}, you are {1} years old and live at {2:address}", 100n]);
            const extraParams = ethers.AbiCoder.defaultAbiCoder().encode(["string", "string", "address"], ["Alice", "25", "0x1234567890123456789012345678901234567890"]);
            const routerRequest: Partial<RouterRequest> = {
                modelId: "test-model-id",
                request: { call, extraParams, ...minimalRequestFields }
            };
            const result = await requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest);
            expect(result).toEqual({
                requestId: "test-request-id",
                model: "test-model-id",
                call: { parameters: ["Hello Alice, you are 25 years old and live at 0x1234567890123456789012345678901234567890", 100n], types: ["string", "uint256"] }
            });
        });

        it("should handle empty extra parameters", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve({
                apiNamespaceId: "test-namespace",
                apiName: "test-api",
                apiId: "test-api-id",
                specs: "uint256, bool -> bytes",
                docs: "Test API documentation"
            }));
            const call = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "bool"], [123n, true]);
            const routerRequest: Partial<RouterRequest> = {
                modelId: "test-model-id",
                request: { call, extraParams: "0x", ...minimalRequestFields }
            };
            const result = await requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest);
            expect(result).toEqual({
                requestId: "test-request-id",
                model: "test-model-id",
                call: { parameters: [123n, true], types: ["uint256", "bool"] }
            });
        });

        it("should handle placeholders with default string type", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve({
                apiNamespaceId: "test-namespace",
                apiName: "test-api",
                apiId: "test-api-id",
                specs: "string, uint256 -> bytes",
                docs: "Test API documentation"
            }));
            const call = ethers.AbiCoder.defaultAbiCoder().encode(["string", "uint256"], ["Hello {0}, you are {1} years old", 100n]);
            const extraParams = ethers.AbiCoder.defaultAbiCoder().encode(["string", "string"], ["Alice", "25"]);
            const routerRequest: Partial<RouterRequest> = {
                modelId: "test-model-id",
                request: { call, extraParams, ...minimalRequestFields }
            };
            const result = await requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest);
            expect(result).toEqual({
                requestId: "test-request-id",
                model: "test-model-id",
                call: { parameters: ["Hello Alice, you are 25 years old", 100n], types: ["string", "uint256"] }
            });
        });

        it("should throw error when model API is not found", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve(null as any));
            const routerRequest: Partial<RouterRequest> = {
                modelId: "non-existent-model",
                request: { call: "0x", extraParams: "0x", ...minimalRequestFields }
            };
            await expect(requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest))
                .rejects.toThrow("Model API not found for model non-existent-model");
        });
    });

    describe("getApiResponseType", () => {
        it("should return the correct response type", async () => {
            mockGetModelAPI.mockReturnValueOnce(Promise.resolve({
                apiNamespaceId: "test-namespace",
                apiName: "test-api",
                apiId: "test-api-id",
                specs: "string, uint64, uint64 -> bytes",
                docs: "Test API documentation"
            }));
            const call = ethers.AbiCoder.defaultAbiCoder().encode(["string", "uint64", "uint64"], ["test", 1n, 2n]);
            const routerRequest: Partial<RouterRequest> = {
                modelId: "test-model-id",
                request: { call, extraParams: "0x", ...minimalRequestFields }
            };
            await requestParser.parseRouterRequest("test-request-id", routerRequest as RouterRequest);
            const responseType = requestParser.getApiResponseType("test-model-id");
            expect(responseType).toBe("bytes");
        });
        it("should throw error when model API is not cached", () => {
            expect(() => requestParser.getApiResponseType("non-cached-model"))
                .toThrow("Model API not found for model non-cached-model");
        });
    });
}); 