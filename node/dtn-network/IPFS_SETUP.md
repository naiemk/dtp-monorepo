# IPFS Setup Guide

This guide explains how to set up IPFS functionality for the DTN Network Node using Pinata.

## Overview

The DTN Network Node uses IPFS to store AI responses when the request type is set to IPFS. We use Pinata as the IPFS service provider for reliable and fast IPFS storage. The IPFS client supports both string and binary data storage, making it versatile for various types of content.

## Setup Instructions

### 1. Create a Pinata Account

1. Go to [Pinata](https://pinata.cloud) and create an account
2. Verify your email address
3. Complete any required verification steps

### 2. Get Your API Keys

1. Log in to your Pinata dashboard
2. Go to the "API Keys" section
3. Create a new API key with the following permissions:
   - `pinFileToIPFS` - To upload files to IPFS
   - `unpin` - To remove files from IPFS (optional)
   - `pinList` - To list your pinned files
4. Copy both the API Key and Secret Key

### 3. Configure Your Node

1. Copy `example-config.yaml` to `config.yaml`
2. Update the IPFS configuration section:

```yaml
ipfs:
  apiKey: "YOUR_PINATA_API_KEY"
  secretKey: "YOUR_PINATA_SECRET_KEY"
  gateway: "https://gateway.pinata.cloud" # Optional
```

### 4. Install Dependencies

```bash
cd node/dtn-network
bun install
```

## Usage

The IPFS client is automatically used by the ResponseGenerator when processing requests with `calltype: 0` (IPFS). The client will:

1. Store AI responses on IPFS via Pinata
2. Return the CID (Content Identifier) as the response
3. Allow retrieval of stored data using the CID

## API Methods

### Store Data

#### String Data
```typescript
const ipfsClient = new IpfsClient(config.ipfs);
const cid = await ipfsClient.store("Your text data here");
console.log("Stored with CID:", cid);
```

#### Binary Data (Buffer/Uint8Array)
```typescript
const binaryData = Buffer.from([0x48, 0x65, 0x6c, 0x6c, 0x6f]); // "Hello"
const cid = await ipfsClient.store(binaryData, {
    filename: 'data.bin',
    contentType: 'application/octet-stream'
});
```

#### JSON Data
```typescript
const jsonData = { message: "Hello", timestamp: new Date().toISOString() };
const cid = await ipfsClient.storeJson(jsonData, {
    filename: 'data.json'
});
```

#### Image Data
```typescript
const imageBuffer = Buffer.from('image-data'); // Your image buffer
const cid = await ipfsClient.storeImage(imageBuffer, 'png', {
    filename: 'image.png'
});
```

#### File from Filesystem
```typescript
const cid = await ipfsClient.storeFile('/path/to/your/file.txt', {
    metadata: { source: 'filesystem' }
});
```

### Retrieve Data

#### As String
```typescript
const data = await ipfsClient.retrieve(cid);
console.log("Retrieved data:", data);
```

#### As Binary Buffer
```typescript
const binaryData = await ipfsClient.retrieveBinary(cid);
console.log("Retrieved binary data:", binaryData);
```

### Advanced Features

#### Check Connection
```typescript
const isConnected = await ipfsClient.isConnected();
console.log("IPFS connected:", isConnected);
```

#### Get CID Information
```typescript
const info = await ipfsClient.getCidInfo(cid);
console.log("CID info:", info);
```

#### Unpin Data (Cleanup)
```typescript
const success = await ipfsClient.unpin(cid);
console.log("Unpinned:", success);
```

#### Get Gateway URL
```typescript
const url = ipfsClient.getGatewayUrl(cid);
console.log("Gateway URL:", url);
```

## Store Options

The `store` method accepts optional configuration:

```typescript
interface StoreOptions {
    filename?: string;           // Custom filename
    contentType?: string;        // MIME type
    metadata?: Record<string, any>; // Additional metadata
}
```

Example:
```typescript
const cid = await ipfsClient.store(data, {
    filename: 'custom-name.json',
    contentType: 'application/json',
    metadata: {
        category: 'ai-response',
        model: 'gpt-4',
        timestamp: new Date().toISOString()
    }
});
```

## Binary Data Support

The enhanced IPFS client supports various data types:

### Supported Input Types
- **String**: UTF-8 encoded text
- **Buffer**: Node.js Buffer for binary data
- **Uint8Array**: Typed array for binary data
- **Objects**: Automatically converted to JSON

### Content Type Detection
- **String**: Defaults to `application/json`
- **Buffer/Uint8Array**: Defaults to `application/octet-stream`
- **Custom**: Can be specified via `contentType` option

### Use Cases
- **Text Responses**: AI model text outputs
- **JSON Data**: Structured data and configurations
- **Images**: AI-generated images (DALL-E, Stable Diffusion)
- **Documents**: PDFs, documents, or other files
- **Binary Data**: Any binary content

## Error Handling

The IPFS client includes comprehensive error handling:

- Network errors are caught and logged
- Invalid CIDs are handled gracefully
- Authentication failures are reported clearly
- All errors include descriptive messages
- Type validation for input data

## Security Considerations

1. **API Keys**: Never commit your Pinata API keys to version control
2. **Environment Variables**: Consider using environment variables for sensitive data
3. **Rate Limits**: Be aware of Pinata's rate limits for your plan
4. **Data Privacy**: Ensure sensitive data is properly encrypted before storing on IPFS
5. **Content Validation**: Validate content before storing to prevent malicious uploads

## Troubleshooting

### Common Issues

1. **Authentication Error**: Check your API key and secret key
2. **Network Error**: Verify your internet connection and Pinata's status
3. **Rate Limit**: Upgrade your Pinata plan or implement rate limiting
4. **CID Not Found**: The CID may have been unpinned or doesn't exist
5. **Type Error**: Ensure data types match expected formats

### Debug Mode

Enable debug logging by setting the log level in your configuration:

```typescript
// Add to your configuration
debug: true
```

## Examples

See `examples/binary-storage-example.ts` for comprehensive examples of:
- String data storage
- Binary data storage
- JSON data storage
- Image data storage
- File system integration
- AI response storage patterns

Run the examples:
```bash
cd node/dtn-network
bun run examples/binary-storage-example.ts
```

## Alternative IPFS Providers

While Pinata is recommended, you can modify the `IpfsClient` class to use other IPFS providers:

- **Infura IPFS**: Use Infura's IPFS API
- **Web3.Storage**: Use Protocol Labs' Web3.Storage
- **Local IPFS**: Run your own IPFS node

## Support

For issues related to:
- **Pinata**: Contact Pinata support
- **DTN Network**: Check the project documentation
- **IPFS Protocol**: Visit the IPFS documentation 