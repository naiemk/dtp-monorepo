#!/bin/bash

# DTN Network Node Build Script
# This script builds the Docker image for the DTN network node

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
DOCKERFILE="Dockerfile.prod"

echo -e "${BLUE}🔨 DTN Network Node Build Script${NC}"
echo "=================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "Dockerfile.prod" ]; then
    echo -e "${RED}❌ Dockerfile.prod not found. Please run this script from the node/dtn-network directory.${NC}"
    exit 1
fi

# Clean up any existing containers with the same name
echo -e "${YELLOW}🧹 Cleaning up existing containers...${NC}"
docker rm -f dtn-node-test 2>/dev/null || true

# Build the Docker image
echo -e "${YELLOW}🏗️  Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
docker build -f ${DOCKERFILE} -t ${IMAGE_NAME}:${IMAGE_TAG} .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker image built successfully!${NC}"
    echo -e "${BLUE}📦 Image: ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
    
    # Show image info
    echo -e "${YELLOW}📊 Image details:${NC}"
    docker images ${IMAGE_NAME}:${IMAGE_TAG}
else
    echo -e "${RED}❌ Failed to build Docker image${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Build completed successfully!${NC}"
echo -e "${BLUE}💡 Run './scripts/test.sh' to test the container${NC}" 