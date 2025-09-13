import { PinataSDK } from 'pinata';

export interface PinataConfig {
    pinataJwt?: string;
    gateway?: string;
}

export interface StoreOptions {
    filename?: string;
    contentType?: string;
    metadata?: Record<string, any>;
}

export class IpfsClient {
    private pinata: InstanceType<typeof PinataSDK>;
    private config: PinataConfig;

    constructor(_config: PinataConfig, private nodeId: string) {
        this.config = {
            pinataJwt: process.env[_config.pinataJwt!] || _config.pinataJwt,
            gateway: _config.gateway || 'https://gateway.pinata.cloud'
        };
        // Prefer JWT if provided, else fallback to API/Secret
        if (!this.config.pinataJwt) {
            throw new Error('Pinata config must include pinataJwt');
        }
        this.pinata = new PinataSDK({
            pinataJwt: this.config.pinataJwt,
            pinataGateway: this.config.gateway
        });
        
    }

    /**
     * Store string or binary data on IPFS
     */
    async store(data: string | Buffer | Uint8Array, options: StoreOptions = {}): Promise<string> {
        let file: File;
        let filename: string;
        let contentType: string;
        if (typeof data === 'string') {
            filename = options.filename || 'data.json';
            contentType = options.contentType || 'application/json';
            file = new File([data], filename, { type: contentType });
        } else if (data instanceof Buffer || data instanceof Uint8Array) {
            filename = options.filename || 'data.bin';
            contentType = options.contentType || 'application/octet-stream';
            file = new File([data], filename, { type: contentType });
        } else {
            throw new Error('Unsupported data type. Must be string, Buffer, or Uint8Array');
        }
        // Metadata: keyvalues must be Record<string, string>
        const keyvalues: Record<string, string> = {
            source: 'dtn-network',
            nodeId: String(this.nodeId),
            timestamp: new Date().toISOString(),
            contentType: contentType,
            size: String((typeof data === 'string') ? Buffer.byteLength(data, 'utf-8') : (data as Buffer | Uint8Array).length),
            ...Object.fromEntries(Object.entries(options.metadata || {}).map(([k, v]) => [k, String(v)]))
        };
        const metadata = {
            name: options.filename || `dtn-data-${Date.now()}`,
            keyvalues
        };
        // Upload using Pinata SDK
        const upload = await this.pinata.upload.file(file, { metadata });
        return upload.cid;
    }

    /**
     * Retrieve data from IPFS as string
     */
    async retrieve(cid: string): Promise<string> {
        // Use direct IPFS gateway instead of Pinata SDK due to URL construction issues
        const response = await fetch(`${this.config.gateway}/ipfs/${cid}`);
        if (!response.ok) {
            throw new Error(`Failed to retrieve data: ${response.statusText}`);
        }
        return await response.text();
    }

    /**
     * Retrieve data from IPFS as binary buffer
     */
    async retrieveBinary(cid: string): Promise<Buffer> {
        // Use direct IPFS gateway instead of Pinata SDK due to URL construction issues
        const response = await fetch(`${this.config.gateway}/ipfs/${cid}`);
        if (!response.ok) {
            throw new Error(`Failed to retrieve data: ${response.statusText}`);
        }
        const arrayBuffer = await response.arrayBuffer();
        return Buffer.from(arrayBuffer);
    }

    /**
     * Store a file from the local filesystem
     */
    async storeFile(filePath: string, options?: StoreOptions): Promise<string> {
        const fs = await import('fs/promises');
        const dataBuffer = await fs.readFile(filePath);
        const filename = options?.filename || filePath.split('/').pop() || 'file';
        return this.store(dataBuffer, {
            ...options,
            filename
        });
    }

    /**
     * Store JSON data with proper content type
     */
    async storeText(data: string, options?: StoreOptions): Promise<string> {
        return this.store(data, {
            ...options,
            filename: options?.filename || 'data.txt',
            contentType: 'text/plain; charset=utf-8'
        });
    }

    /**
     * Store JSON data with proper content type
     */
    async storeJson(data: any, options?: StoreOptions): Promise<string> {
        const jsonString = JSON.stringify(data, null, 2);
        return this.store(jsonString, {
            ...options,
            filename: options?.filename || 'data.json',
            contentType: 'application/json'
        });
    }

    /**
     * Store image data with proper content type
     */
    async storeImage(imageBuffer: Buffer, format: 'png' | 'jpg' | 'jpeg' | 'gif' | 'webp', options?: StoreOptions): Promise<string> {
        const contentType = `image/${format}`;
        return this.store(imageBuffer, {
            ...options,
            filename: options?.filename || `image.${format}`,
            contentType
        });
    }

    /**
     * Check if the IPFS client is connected and working
     */
    async isConnected(): Promise<boolean> {
        try {
            await this.pinata.gateways.get('bafkreigh2akiscaildc6wq6j5g6z2w5v6z3v6z3v6z3v6z3v6z3v6z3v6z3');
            return true;
        } catch (error) {
            console.error('IPFS client not connected:', error);
            // Try fallback to direct gateway
            try {
                const response = await fetch(`${this.config.gateway}/ipfs/bafkreigh2akiscaildc6wq6j5g6z2w5v6z3v6z3v6z3v6z3v6z3v6z3v6z3`);
                return response.ok;
            } catch (fallbackError) {
                console.error('Fallback gateway also failed:', fallbackError);
                return false;
            }
        }
    }

    /**
     * Get information about a CID without downloading the content
     */
    async getCidInfo(cid: string): Promise<any> {
        return { cid, gatewayUrl: this.getGatewayUrl(cid) };
    }

    /**
     * Unpin a CID from Pinata (optional cleanup method)
     */
    async unpin(cid: string): Promise<boolean> {
        try {
            await this.pinata.keys.revoke([cid]);
            return true;
        } catch (error) {
            console.error('Error unpinning CID:', error);
            return false;
        }
    }

    /**
     * Get the gateway URL for a CID
     */
    getGatewayUrl(cid: string): string {
        return `${this.config.gateway}/ipfs/${cid}`;
    }
}