import axios from 'axios';

export interface PinataConfig {
    apiKey: string;
    secretKey: string;
    gateway?: string;
}

export interface StoreOptions {
    filename?: string;
    contentType?: string;
    metadata?: Record<string, any>;
}

export class IpfsClient {
    private config: PinataConfig;
    private baseUrl = 'https://api.pinata.cloud';

    constructor(config: PinataConfig) {
        this.config = {
            ...config,
            gateway: config.gateway || 'https://gateway.pinata.cloud'
        };
    }

    /**
     * Store string data on IPFS
     */
    async store(data: string, options?: StoreOptions): Promise<string>;
    
    /**
     * Store binary data on IPFS
     */
    async store(data: Buffer | Uint8Array, options?: StoreOptions): Promise<string>;
    
    /**
     * Store data on IPFS (implementation)
     */
    async store(data: string | Buffer | Uint8Array, options: StoreOptions = {}): Promise<string> {
        try {
            let dataBuffer: Buffer;
            let filename: string;
            let contentType: string;

            // Handle different input types
            if (typeof data === 'string') {
                dataBuffer = Buffer.from(data, 'utf-8');
                filename = options.filename || 'data.json';
                contentType = options.contentType || 'application/json';
            } else if (data instanceof Buffer) {
                dataBuffer = data;
                filename = options.filename || 'data.bin';
                contentType = options.contentType || 'application/octet-stream';
            } else if (data instanceof Uint8Array) {
                dataBuffer = Buffer.from(data);
                filename = options.filename || 'data.bin';
                contentType = options.contentType || 'application/octet-stream';
            } else {
                throw new Error('Unsupported data type. Must be string, Buffer, or Uint8Array');
            }
            
            // Create form data for Pinata API
            const formData = new FormData();
            formData.append('file', new Blob([dataBuffer], { type: contentType }), filename);
            
            // Add metadata
            const metadata = {
                name: options.filename || `dtn-data-${Date.now()}`,
                keyvalues: {
                    source: 'dtn-network',
                    timestamp: new Date().toISOString(),
                    contentType: contentType,
                    size: dataBuffer.length,
                    ...options.metadata
                }
            };
            formData.append('pinataMetadata', JSON.stringify(metadata));
            
            // Upload to Pinata
            const response = await axios.post(`${this.baseUrl}/pinning/pinFileToIPFS`, formData, {
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`,
                    'Content-Type': 'multipart/form-data'
                }
            });
            
            // Return the IPFS hash (CID)
            return response.data.IpfsHash;
        } catch (error) {
            console.error('Error storing data on IPFS via Pinata:', error);
            throw new Error(`Failed to store data on IPFS: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    /**
     * Retrieve data from IPFS as string
     */
    async retrieve(cid: string): Promise<string> {
        try {
            // Retrieve data from Pinata gateway
            const response = await axios.get(`${this.config.gateway}/ipfs/${cid}`, {
                responseType: 'arraybuffer'
            });
            
            // Convert buffer to string
            return Buffer.from(response.data).toString('utf-8');
        } catch (error) {
            console.error('Error retrieving data from IPFS via Pinata:', error);
            throw new Error(`Failed to retrieve data from IPFS: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    /**
     * Retrieve data from IPFS as binary buffer
     */
    async retrieveBinary(cid: string): Promise<Buffer> {
        try {
            // Retrieve data from Pinata gateway
            const response = await axios.get(`${this.config.gateway}/ipfs/${cid}`, {
                responseType: 'arraybuffer'
            });
            
            // Return as buffer
            return Buffer.from(response.data);
        } catch (error) {
            console.error('Error retrieving binary data from IPFS via Pinata:', error);
            throw new Error(`Failed to retrieve binary data from IPFS: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    /**
     * Store a file from the local filesystem
     */
    async storeFile(filePath: string, options?: StoreOptions): Promise<string> {
        try {
            const fs = await import('fs/promises');
            const dataBuffer = await fs.readFile(filePath);
            const filename = options?.filename || filePath.split('/').pop() || 'file';
            
            return this.store(dataBuffer, {
                ...options,
                filename
            });
        } catch (error) {
            console.error('Error storing file on IPFS:', error);
            throw new Error(`Failed to store file on IPFS: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
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
            // Test connection by getting user data from Pinata
            await axios.get(`${this.baseUrl}/data/testAuthentication`, {
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`
                }
            });
            return true;
        } catch (error) {
            console.error('IPFS client not connected:', error);
            return false;
        }
    }

    /**
     * Get information about a CID without downloading the content
     */
    async getCidInfo(cid: string): Promise<any> {
        try {
            // Get metadata from Pinata
            const response = await axios.get(`${this.baseUrl}/pinning/pinList?hashContains=${cid}`, {
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`
                }
            });
            
            const pin = response.data.rows.find((p: any) => p.ipfs_pin_hash === cid);
            if (!pin) {
                throw new Error('CID not found in Pinata');
            }
            
            return {
                cid: pin.ipfs_pin_hash,
                size: pin.size,
                name: pin.metadata?.name,
                timestamp: pin.date_pinned,
                type: 'file',
                metadata: pin.metadata?.keyvalues
            };
        } catch (error) {
            console.error('Error getting CID info:', error);
            throw new Error(`Failed to get CID info: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    /**
     * Unpin a CID from Pinata (optional cleanup method)
     */
    async unpin(cid: string): Promise<boolean> {
        try {
            await axios.delete(`${this.baseUrl}/pinning/unpin/${cid}`, {
                headers: {
                    'Authorization': `Bearer ${this.config.apiKey}`
                }
            });
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