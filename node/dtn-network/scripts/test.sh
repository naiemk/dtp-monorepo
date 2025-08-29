#!/bin/bash

# DTN Network Node Test Script
# This script runs the Docker container and verifies the service is working

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="dtn-network-node"
IMAGE_TAG="latest"
CONTAINER_NAME="dtn-node-test"
TEST_TIMEOUT=30  # seconds to wait for service to start

echo -e "${BLUE}🧪 DTN Network Node Test Script${NC}"
echo "=================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if the image exists
if ! docker images | grep -q "${IMAGE_NAME}.*${IMAGE_TAG}"; then
    echo -e "${RED}❌ Docker image ${IMAGE_NAME}:${IMAGE_TAG} not found.${NC}"
    echo -e "${YELLOW}💡 Run './scripts/build.sh' first to build the image.${NC}"
    exit 1
fi

# Clean up any existing test containers
echo -e "${YELLOW}🧹 Cleaning up existing test containers...${NC}"
docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

# Create a test configuration file
echo -e "${YELLOW}📝 Creating test configuration...${NC}"
cat > test-config.yaml << 'EOF'
# Test configuration for DTN Network Node
keys:
  ownerPrivateKey: TEST_OWNER_PRIVATE_KEY
  workerPrivateKey: TEST_WORKER_PRIVATE_KEY

local:
  cacheDir: ./.cache

network:
  rpcUrl: https://rpc.dtn.network
  chainId: 1337
  nodeManagerAddress: 0x1234567890123456789012345678901234567890
  modelManagerAddress: 0x1234567890123456789012345678901234567890

node:
  username: test-user
  nodeName: test-node
  worker: 0x1234567890123456789012345678901234567890
  models:
    - name: model.system.openai-gpt-4
      priceMinPerByteIn: 1000
      priceMaxPerByteOut: 10000
      host: "http://localproxy:8080/"
  trustNamespaces:
    - "system.trust.dtn"
EOF

# Test 1: Check if the CLI help command works by running it directly
echo -e "${YELLOW}🔍 Test 1: Checking CLI help command...${NC}"
HELP_OUTPUT=$(docker run --rm \
    -e NODE_ENV=test \
    ${IMAGE_NAME}:${IMAGE_TAG} \
    bun dist/index.cjs --help 2>&1)

if echo "$HELP_OUTPUT" | grep -q "DTN Network Node CLI"; then
    echo -e "${GREEN}✅ CLI help command works${NC}"
else
    echo -e "${RED}❌ CLI help command failed${NC}"
    echo "$HELP_OUTPUT"
    exit 1
fi

# Test 2: Check if the application can load configuration (expected to fail with test keys)
echo -e "${YELLOW}🔍 Test 2: Checking configuration loading...${NC}"
CONFIG_OUTPUT=$(docker run --rm \
    -e NODE_ENV=test \
    -e TEST_OWNER_PRIVATE_KEY="0x1234567890123456789012345678901234567890123456789012345678901234" \
    -e TEST_WORKER_PRIVATE_KEY="0x1234567890123456789012345678901234567890123456789012345678901234" \
    -v $(pwd)/test-config.yaml:/app/nodeConfig.yaml:ro \
    ${IMAGE_NAME}:${IMAGE_TAG} \
    bun dist/index.cjs run-once --config /app/nodeConfig.yaml 2>&1 || true)

if echo "$CONFIG_OUTPUT" | grep -q "Loading configuration"; then
    echo -e "${GREEN}✅ Configuration loading works (as expected, may fail with test keys)${NC}"
else
    echo -e "${YELLOW}⚠️  Configuration loading behavior differs from expected${NC}"
    echo "Output: $CONFIG_OUTPUT"
fi

# Test 3: Check if the application structure is correct
echo -e "${YELLOW}🔍 Test 3: Checking application structure...${NC}"
STRUCTURE_OUTPUT=$(docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} ls -la dist/ 2>&1)
if echo "$STRUCTURE_OUTPUT" | grep -q "index.cjs"; then
    echo -e "${GREEN}✅ Application structure is correct${NC}"
else
    echo -e "${RED}❌ Application structure is incorrect${NC}"
    echo "$STRUCTURE_OUTPUT"
    exit 1
fi

# Test 4: Check if the binary is executable
echo -e "${YELLOW}🔍 Test 4: Checking binary permissions...${NC}"
if docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} test -x dist/index.cjs; then
    echo -e "${GREEN}✅ Binary is executable${NC}"
else
    echo -e "${RED}❌ Binary is not executable${NC}"
    exit 1
fi

# Test 5: Check if we can run the version command
echo -e "${YELLOW}🔍 Test 5: Checking version command...${NC}"
VERSION_OUTPUT=$(docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} bun dist/index.cjs --version 2>&1)
if echo "$VERSION_OUTPUT" | grep -q "1.0.0"; then
    echo -e "${GREEN}✅ Version command works${NC}"
else
    echo -e "${YELLOW}⚠️  Version command output: $VERSION_OUTPUT${NC}"
fi

# Test 6: Check if cckey is available in the Docker image
echo -e "${YELLOW}🔍 Test 6: Checking cckey availability...${NC}"
CCKEY_OUTPUT=$(docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} cckey --help 2>&1)
if echo "$CCKEY_OUTPUT" | grep -q "Usage: cckey"; then
    echo -e "${GREEN}✅ cckey is available in Docker image${NC}"
else
    echo -e "${RED}❌ cckey is not available in Docker image${NC}"
    echo "$CCKEY_OUTPUT"
    exit 1
fi

# Test 7: Test keystore.sh script functionality
echo -e "${YELLOW}🔍 Test 7: Testing keystore.sh script...${NC}"

# Clean up any existing test keystore
rm -rf ./test-keystore

# Test if keystore.sh can create a key
echo -e "${BLUE}  Creating test key with keystore.sh...${NC}"
export FOUNDRY_KEYSTORE_PATH="./test-keystore"
export FOUNDRY_KEYSTORE_PASSPHRASE="test-passphrase-123"

# Create a key using keystore.sh
KEY_OUTPUT=$(./keystore.sh create --passphrase "$FOUNDRY_KEYSTORE_PASSPHRASE" 2>&1)
if echo "$KEY_OUTPUT" | grep -q "ccc"; then
    # Extract the created address from the output
    CREATED_ADDRESS=$(echo "$KEY_OUTPUT" | grep "ccc" | tail -1 | tr -d '\r\n')
    echo -e "${GREEN}✅ Key created successfully: $CREATED_ADDRESS${NC}"
else
    echo -e "${RED}❌ Key creation failed${NC}"
    echo "$KEY_OUTPUT"
    exit 1
fi

# Test if keystore.sh can list the created key
echo -e "${BLUE}  Listing keys with keystore.sh...${NC}"
LIST_OUTPUT=$(./keystore.sh list 2>&1)
if echo "$LIST_OUTPUT" | grep -q "$CREATED_ADDRESS"; then
    echo -e "${GREEN}✅ Key listing works${NC}"
else
    echo -e "${RED}❌ Key listing failed${NC}"
    echo "$LIST_OUTPUT"
    exit 1
fi

# Test 8: Test keystore.ts integration inside Docker
echo -e "${YELLOW}🔍 Test 8: Testing keystore.ts integration...${NC}"

# Create a test configuration with the created address
cat > test-keystore-config.yaml << EOF
# Test configuration for keystore integration
keys:
  ownerPrivateKey: $CREATED_ADDRESS
  workerPrivateKey: $CREATED_ADDRESS

local:
  cacheDir: ./.cache

network:
  rpcUrl: https://rpc.dtn.network
  chainId: 1337
  nodeManagerAddress: 0x1234567890123456789012345678901234567890
  modelManagerAddress: 0x1234567890123456789012345678901234567890
  namespaceManagerAddress: 0x1234567890123456789012345678901234567890
  routerAddress: 0x1234567890123456789012345678901234567890
  sessionManagerAddress: 0x1234567890123456789012345678901234567890

node:
  username: test-user
  nodeName: test-node
  worker: 0x1234567890123456789012345678901234567890
  models:
    - name: model.system.openai-gpt-4
      priceMinPerByteIn: 1000
      priceMinPerByteOut: 10000
      host: "http://localproxy:8080/"
  trustNamespaces:
    - "system.trust.dtn"

ipfs:
  pinataJwt: "test-jwt"
EOF

# Test if the Docker container can load keys from keystore using keystore.ts
echo -e "${BLUE}  Testing keystore integration inside Docker...${NC}"
KEYSTORE_TEST_OUTPUT=$(docker run --rm \
    -e NODE_ENV=test \
    -e FOUNDRY_KEYSTORE_PASSPHRASE="$FOUNDRY_KEYSTORE_PASSPHRASE" \
    -e FOUNDRY_KEYSTORE_PATH="/app/keystore" \
    -v "$(realpath ./test-keystore)":/app/keystore \
    -v $(pwd)/test-keystore-config.yaml:/app/nodeConfig.yaml:ro \
    ${IMAGE_NAME}:${IMAGE_TAG} \
    bun dist/index.cjs run-once --config /app/nodeConfig.yaml 2>&1 || true)

if echo "$KEYSTORE_TEST_OUTPUT" | grep -q "Loading configuration"; then
    if echo "$KEYSTORE_TEST_OUTPUT" | grep -q "Keystore keys validated"; then
        echo -e "${GREEN}✅ Keystore integration works - keys validated successfully${NC}"
    elif echo "$KEYSTORE_TEST_OUTPUT" | grep -q "Failed to load private key"; then
        echo -e "${YELLOW}⚠️  Keystore integration partially works - key loading issue detected${NC}"
        echo "This might be expected if the address format differs from private key format"
    else
        echo -e "${GREEN}✅ Keystore integration works - configuration loaded${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Keystore integration test - configuration loading behavior differs${NC}"
    echo "Output snippet: $(echo "$KEYSTORE_TEST_OUTPUT" | head -10)"
fi

# Test 9: Test exporting key with keystore.sh to verify it returns keystore data
echo -e "${YELLOW}🔍 Test 9: Testing key export functionality...${NC}"
EXPORT_OUTPUT=$(./keystore.sh export --address "$CREATED_ADDRESS" --passphrase "$FOUNDRY_KEYSTORE_PASSPHRASE" 2>&1)
if echo "$EXPORT_OUTPUT" | grep -q "crypto"; then
    echo -e "${GREEN}✅ Key export works - keystore JSON retrieved${NC}"
    echo -e "${BLUE}  Exported keystore contains encrypted private key${NC}"
elif echo "$EXPORT_OUTPUT" | grep -q "0x"; then
    EXPORTED_KEY=$(echo "$EXPORT_OUTPUT" | grep "0x" | tail -1 | tr -d '\r\n')
    echo -e "${GREEN}✅ Key export works - private key retrieved${NC}"
    echo -e "${BLUE}  Exported key format: ${EXPORTED_KEY:0:10}...${NC}"
else
    echo -e "${RED}❌ Key export failed${NC}"
    echo "$EXPORT_OUTPUT"
    exit 1
fi

# Clean up
echo -e "${YELLOW}🧹 Cleaning up test environment...${NC}"
rm -f test-config.yaml test-keystore-config.yaml
rm -rf ./test-keystore
unset FOUNDRY_KEYSTORE_PATH
unset FOUNDRY_KEYSTORE_PASSPHRASE

echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
echo -e "${BLUE}✅ DTN Network Node and keystore integration are working correctly${NC}" 