import type { ethers } from "ethers";

/**
 * Helper to estimate gas, add buffer, and send contract transaction
 */
export async function sendWithGasEstimate<ParamsType extends any[]>(
    contract: ethers.Contract,
    methodName: string,
    args: ParamsType,
    gasMultiplier: number = 1.5
): Promise<any> {
    if (!contract[methodName]) {
        throw new Error(`Method ${methodName} not found on contract`);
    }
    const gasEstimate = await contract[methodName].estimateGas(...args);
    console.log(`Gas estimate: ${gasEstimate}`);
    const gasLimit = BigInt(Math.floor(Number(gasEstimate) * gasMultiplier));
    return (contract[methodName] as any)(...args, { gasLimit });
}

/**
 * Helper to stringify JSON objects with bigint fields by converting bigints to strings.
 */
export function jsonStringifyWithBigInt(obj: any, space?: number): string {
    return JSON.stringify(obj, (_key, value) =>
        typeof value === 'bigint' ? `"${value.toString()}"` : value,
        space);
} 

export function parseBinaryData(data: string): Buffer {
    return Buffer.from(data, 'base64');
}