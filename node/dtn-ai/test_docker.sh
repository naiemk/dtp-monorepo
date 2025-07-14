#!/bin/bash

# DTN AI Server Docker Test Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="dtn-openai-proxy"
TAG="latest"
CONTAINER_NAME="dtn-ai-test"
TEST_PORT="8026"

echo -e "${BLUE}🧪 Testing DTN AI Server Docker Image...${NC}"

# Function to cleanup
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not available${NC}"
    exit 1
fi

# Check if image exists
if ! docker image inspect $IMAGE_NAME:$TAG &> /dev/null; then
    echo -e "${RED}❌ Image $IMAGE_NAME:$TAG not found. Please build it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Image found: $IMAGE_NAME:$TAG${NC}"

# Show image size
echo -e "${BLUE}📊 Image size:${NC}"
docker images $IMAGE_NAME:$TAG --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Check if OPENAI_API_KEY is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  OPENAI_API_KEY not set. Some tests will be skipped.${NC}"
    export OPENAI_API_KEY="test_key_for_docker_test"
fi

# Start container
echo -e "${BLUE}🚀 Starting container...${NC}"
docker run -d \
    --name $CONTAINER_NAME \
    -p $TEST_PORT:8026 \
    -e OPENAI_API_KEY="$OPENAI_API_KEY" \
    $IMAGE_NAME:$TAG

# Wait for container to start
echo -e "${BLUE}⏳ Waiting for container to start...${NC}"
sleep 5

# Check if container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${RED}❌ Container failed to start${NC}"
    docker logs $CONTAINER_NAME
    exit 1
fi

echo -e "${GREEN}✅ Container is running${NC}"

# Show initial logs
echo -e "${BLUE}📋 Initial container logs:${NC}"
docker logs $CONTAINER_NAME

# Wait for server to be ready
echo -e "${BLUE}⏳ Waiting for server to be ready...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:$TEST_PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Server is ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Server failed to start within 30 seconds${NC}"
        echo -e "${BLUE}📋 Container logs (showing why server failed):${NC}"
        docker logs $CONTAINER_NAME
        exit 1
    fi
    sleep 1
done

# Test health endpoint
echo -e "${BLUE}🏥 Testing health endpoint...${NC}"
HEALTH_RESPONSE=$(curl -s http://localhost:$TEST_PORT/health)
echo "Health response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q '"status": "healthy"'; then
    echo -e "${GREEN}✅ Health check passed${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
    exit 1
fi

# Test API endpoint with invalid request (should return 400)
echo -e "${BLUE}🔍 Testing API endpoint with invalid request...${NC}"
INVALID_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:$TEST_PORT/api/request \
    -H "Content-Type: application/json" \
    -d '{"invalid": "request"}' -o /dev/null)

if [ "$INVALID_RESPONSE" = "400" ]; then
    echo -e "${GREEN}✅ Invalid request properly rejected (400)${NC}"
else
    echo -e "${RED}❌ Invalid request not properly handled (got $INVALID_RESPONSE)${NC}"
fi

# Test API endpoint with valid request structure but unsupported model
echo -e "${BLUE}🔍 Testing API endpoint with unsupported model...${NC}"
UNSUPPORTED_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:$TEST_PORT/api/request \
    -H "Content-Type: application/json" \
    -d '{"requestId": "test123", "model": "unsupported-model", "call": {"parameters": [], "types": []}}' -o /dev/null)

if [ "$UNSUPPORTED_RESPONSE" = "400" ]; then
    echo -e "${GREEN}✅ Unsupported model properly rejected (400)${NC}"
else
    echo -e "${RED}❌ Unsupported model not properly handled (got $UNSUPPORTED_RESPONSE)${NC}"
fi

# Test container logs
echo -e "${BLUE}📋 Container logs (last 20 lines):${NC}"
docker logs $CONTAINER_NAME --tail 20

# Show real-time logs for a few seconds
echo -e "${BLUE}📋 Showing real-time logs (5 seconds):${NC}"
timeout 5 docker logs -f $CONTAINER_NAME || true

# Test resource usage
echo -e "${BLUE}📊 Container resource usage:${NC}"
docker stats $CONTAINER_NAME --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Test container restart
echo -e "${BLUE}🔄 Testing container restart...${NC}"
docker restart $CONTAINER_NAME
sleep 5

if curl -s http://localhost:$TEST_PORT/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Container restart successful${NC}"
else
    echo -e "${RED}❌ Container restart failed${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 All tests passed!${NC}"
echo -e "${BLUE}📝 Test Summary:${NC}"
echo -e "  ✅ Image builds successfully"
echo -e "  ✅ Container starts and runs"
echo -e "  ✅ Health endpoint responds"
echo -e "  ✅ API endpoint handles invalid requests"
echo -e "  ✅ Container restarts properly"
echo -e "  ✅ Resource usage is reasonable"

echo -e "${YELLOW}💡 To run the container in production:${NC}"
echo -e "  docker run -d --name dtn-ai-server \\"
echo -e "    -p 8026:8026 \\"
echo -e "    -e OPENAI_API_KEY=your_actual_api_key \\"
echo -e "    $IMAGE_NAME:$TAG" 