import { IpfsClient, type PinataConfig } from '../src/ipfsClient';

// Example configuration
const pinataConfig: PinataConfig = {
    apiKey: process.env.PINATA_API_KEY || 'your-api-key',
    secretKey: process.env.PINATA_SECRET_KEY || 'your-secret-key',
    gateway: 'https://gateway.pinata.cloud'
};

async function demonstrateBinaryStorage() {
    const ipfsClient = new IpfsClient(pinataConfig);

    try {
        console.log('Testing IPFS connection...');
        const isConnected = await ipfsClient.isConnected();
        console.log('IPFS connected:', isConnected);

        if (!isConnected) {
            console.error('Failed to connect to IPFS. Check your API keys.');
            return;
        }

        // 1. Store string data
        console.log('\n1. Storing string data...');
        const stringData = 'Hello, DTN Network!';
        const stringCid = await ipfsClient.store(stringData, {
            filename: 'hello.txt',
            contentType: 'text/plain',
            metadata: { category: 'greeting' }
        });
        console.log('String CID:', stringCid);

        // 2. Store JSON data
        console.log('\n2. Storing JSON data...');
        const jsonData = {
            message: 'Hello from DTN',
            timestamp: new Date().toISOString(),
            version: '1.0.0'
        };
        const jsonCid = await ipfsClient.storeJson(jsonData, {
            filename: 'data.json',
            metadata: { category: 'configuration' }
        });
        console.log('JSON CID:', jsonCid);

        // 3. Store binary data (Buffer)
        console.log('\n3. Storing binary data (Buffer)...');
        const binaryData = Buffer.from([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // "Hello" in hex
        const binaryCid = await ipfsClient.store(binaryData, {
            filename: 'hello.bin',
            contentType: 'application/octet-stream',
            metadata: { category: 'binary', encoding: 'hex' }
        });
        console.log('Binary CID:', binaryCid);

        // 4. Store image data (simulated)
        console.log('\n4. Storing image data...');
        // Create a simple 1x1 pixel PNG image buffer
        const pngHeader = Buffer.from([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
            0x49, 0x48, 0x44, 0x52, // IHDR
            0x00, 0x00, 0x00, 0x01, // width: 1
            0x00, 0x00, 0x00, 0x01, // height: 1
            0x08, 0x02, 0x00, 0x00, 0x00, // bit depth, color type, compression, filter, interlace
            0x90, 0x77, 0x53, 0xDE, // CRC
            0x00, 0x00, 0x00, 0x0C, // IDAT chunk length
            0x49, 0x44, 0x41, 0x54, // IDAT
            0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, // compressed data
            0x00, 0x00, 0x00, 0x00, // IEND chunk length
            0x49, 0x45, 0x4E, 0x44, // IEND
            0xAE, 0x42, 0x60, 0x82  // CRC
        ]);
        
        const imageCid = await ipfsClient.storeImage(pngHeader, 'png', {
            filename: 'pixel.png',
            metadata: { category: 'image', dimensions: '1x1' }
        });
        console.log('Image CID:', imageCid);

        // 5. Store file from filesystem (if available)
        console.log('\n5. Storing file from filesystem...');
        try {
            const fs = await import('fs/promises');
            // Create a temporary file for demonstration
            const tempFile = '/tmp/dtn-example.txt';
            await fs.writeFile(tempFile, 'This is a test file for DTN Network');
            
            const fileCid = await ipfsClient.storeFile(tempFile, {
                metadata: { category: 'file', source: 'filesystem' }
            });
            console.log('File CID:', fileCid);
            
            // Clean up
            await fs.unlink(tempFile);
        } catch (error) {
            console.log('File storage skipped (filesystem not available):', error);
        }

        // 6. Retrieve and verify data
        console.log('\n6. Retrieving and verifying data...');
        
        // Retrieve string data
        const retrievedString = await ipfsClient.retrieve(stringCid);
        console.log('Retrieved string:', retrievedString);
        console.log('String match:', retrievedString === stringData);

        // Retrieve JSON data
        const retrievedJson = await ipfsClient.retrieve(jsonCid);
        const parsedJson = JSON.parse(retrievedJson);
        console.log('Retrieved JSON:', parsedJson);
        console.log('JSON match:', JSON.stringify(parsedJson) === JSON.stringify(jsonData));

        // Retrieve binary data
        const retrievedBinary = await ipfsClient.retrieveBinary(binaryCid);
        console.log('Retrieved binary:', retrievedBinary);
        console.log('Binary match:', retrievedBinary.equals(binaryData));

        // 7. Get CID information
        console.log('\n7. Getting CID information...');
        const cidInfo = await ipfsClient.getCidInfo(stringCid);
        console.log('CID Info:', cidInfo);

        // 8. Get gateway URLs
        console.log('\n8. Gateway URLs:');
        console.log('String data URL:', ipfsClient.getGatewayUrl(stringCid));
        console.log('JSON data URL:', ipfsClient.getGatewayUrl(jsonCid));
        console.log('Binary data URL:', ipfsClient.getGatewayUrl(binaryCid));
        console.log('Image URL:', ipfsClient.getGatewayUrl(imageCid));

        console.log('\n✅ All binary storage examples completed successfully!');

    } catch (error) {
        console.error('❌ Error in binary storage demonstration:', error);
    }
}

// Define AI response types
type TextResponse = {
    type: 'text';
    data: string;
    requestId: string;
};

type JsonResponse = {
    type: 'json';
    data: Record<string, any>;
    requestId: string;
};

type ImageResponse = {
    type: 'image';
    data: Buffer;
    requestId: string;
};

type AIResponse = TextResponse | JsonResponse | ImageResponse;

// Example of storing AI model responses
async function demonstrateAIResponseStorage() {
    const ipfsClient = new IpfsClient(pinataConfig);

    console.log('\n=== AI Response Storage Examples ===');

    // Simulate different types of AI responses
    const aiResponses: AIResponse[] = [
        {
            type: 'text',
            data: 'This is a text response from an AI model.',
            requestId: 'req-001'
        },
        {
            type: 'json',
            data: {
                answer: 'The answer is 42',
                confidence: 0.95,
                model: 'gpt-4',
                tokens: 150
            },
            requestId: 'req-002'
        },
        {
            type: 'image',
            data: Buffer.from('fake-image-data'), // In real scenario, this would be actual image data
            requestId: 'req-003'
        }
    ];

    for (const response of aiResponses) {
        try {
            console.log(`\nStoring ${response.type} response for ${response.requestId}...`);
            
            let cid: string;
            
            switch (response.type) {
                case 'text':
                    cid = await ipfsClient.store(response.data, {
                        filename: `ai-response-${response.requestId}.txt`,
                        contentType: 'text/plain',
                        metadata: {
                            requestId: response.requestId,
                            type: 'ai-response',
                            model: 'gpt-4'
                        }
                    });
                    break;
                    
                case 'json':
                    cid = await ipfsClient.storeJson(response.data, {
                        filename: `ai-response-${response.requestId}.json`,
                        metadata: {
                            requestId: response.requestId,
                            type: 'ai-response',
                            model: 'gpt-4'
                        }
                    });
                    break;
                    
                case 'image':
                    cid = await ipfsClient.store(response.data, {
                        filename: `ai-response-${response.requestId}.png`,
                        contentType: 'image/png',
                        metadata: {
                            requestId: response.requestId,
                            type: 'ai-response',
                            model: 'dall-e-3'
                        }
                    });
                    break;
                    
                default:
                    throw new Error(`Unknown response type: ${(response as any).type}`);
            }
            
            console.log(`✅ Stored ${response.type} response with CID: ${cid}`);
            console.log(`   Gateway URL: ${ipfsClient.getGatewayUrl(cid)}`);
            
        } catch (error) {
            console.error(`❌ Failed to store ${response.type} response:`, error);
        }
    }
}

// Run examples
if (require.main === module) {
    demonstrateBinaryStorage()
        .then(() => demonstrateAIResponseStorage())
        .catch(console.error);
}

export { demonstrateBinaryStorage, demonstrateAIResponseStorage }; 