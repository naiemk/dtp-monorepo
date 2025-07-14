#!/bin/bash

# DTN AI Server Docker Build Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="dtn-openai-proxy"
TAG="latest"
CONTAINER_NAME="dtn-ai-server"

echo -e "${GREEN}Building DTN AI Server Docker Image...${NC}"

# Check if OPENAI_API_KEY is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${YELLOW}Warning: OPENAI_API_KEY environment variable is not set${NC}"
    echo -e "${YELLOW}You can set it with: export OPENAI_API_KEY=your_api_key${NC}"
fi

# Build the Docker image
echo -e "${GREEN}Building image: ${IMAGE_NAME}:${TAG}${NC}"
docker build -t ${IMAGE_NAME}:${TAG} .

# Check if build was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Show image size
    echo -e "${GREEN}Image size:${NC}"
    docker images ${IMAGE_NAME}:${TAG} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    
    echo -e "${GREEN}To run the container:${NC}"
    echo -e "${YELLOW}docker run -d --name ${CONTAINER_NAME} -p 8026:8026 -e OPENAI_API_KEY=your_api_key ${IMAGE_NAME}:${TAG}${NC}"
    echo -e "${GREEN}Or use docker-compose:${NC}"
    echo -e "${YELLOW}OPENAI_API_KEY=your_api_key docker-compose up -d${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi 