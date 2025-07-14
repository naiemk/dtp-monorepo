#!/bin/bash

# DTN Full Node Docker Test Script
# This script generates docker-compose, runs it, and performs health checks on all services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to cleanup on exit
cleanup() {
    print_status "Cleaning up..."
    if [ -f "docker-compose/docker-compose.yml" ]; then
        docker-compose -f docker-compose/docker-compose.yml down --remove-orphans 2>/dev/null || true
    fi
    print_status "Cleanup complete"
}

# Set trap to cleanup on script exit
trap cleanup EXIT

echo "🧪 DTN Full Node Docker Test"
echo "============================"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running or not accessible"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose >/dev/null 2>&1; then
    print_error "docker-compose is not installed"
    exit 1
fi

# Check if Python is available
if ! command -v python3 >/dev/null 2>&1; then
    print_error "Python 3 is required but not installed"
    exit 1
fi

# Check if curl is available (needed for health endpoint checks)
if ! command -v curl >/dev/null 2>&1; then
    print_error "curl is required for health endpoint checks but not installed"
    exit 1
fi

# Check if required files exist
if [ ! -f "full_config.yaml" ]; then
    print_error "full_config.yaml not found"
    exit 1
fi

if [ ! -f "generate-compose.py" ]; then
    print_error "generate-compose.py not found"
    exit 1
fi

print_success "Prerequisites check passed"

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    print_warning ".env file not found, creating from template..."
    if [ -f "env.example" ]; then
        cp env.example .env
        print_success "Created .env file from template"
        print_warning "Please ensure .env file has proper values for testing"
    else
        print_error "env.example not found"
        exit 1
    fi
fi

# Install Python dependencies if needed
print_status "Checking Python dependencies..."
python3 -c "import yaml" 2>/dev/null || {
    print_status "Installing PyYAML..."
    pip3 install PyYAML
}

# Generate docker-compose configuration
print_status "Generating docker-compose configuration..."
python3 generate-compose.py

if [ ! -f "docker-compose/docker-compose.yml" ]; then
    print_error "Failed to generate docker-compose.yml"
    exit 1
fi

print_success "Docker-compose configuration generated"

# Parse services from docker-compose.yml
print_status "Parsing services from docker-compose.yml..."
SERVICES=($(python3 -c "
import yaml
with open('docker-compose/docker-compose.yml', 'r') as f:
    compose = yaml.safe_load(f)
    services = list(compose.get('services', {}).keys())
    print(' '.join(services))
"))

if [ ${#SERVICES[@]} -eq 0 ]; then
    print_error "No services found in docker-compose.yml"
    exit 1
fi

print_success "Found ${#SERVICES[@]} services: ${SERVICES[*]}"

# Start services
print_status "Starting services..."
docker-compose -f docker-compose/docker-compose.yml up -d

# Wait for services to start
print_status "Waiting for services to start (30 seconds)..."
sleep 30

# Function to check if service is a sidecar
is_sidecar_service() {
    local service_name=$1
    
    # Check if service has healthcheck configuration that uses /health endpoint
    local has_health_check=$(python3 -c "
import yaml
with open('docker-compose/docker-compose.yml', 'r') as f:
    compose = yaml.safe_load(f)
    service = compose['services'].get('$service_name', {})
    healthcheck = service.get('healthcheck', {})
    test_cmd = healthcheck.get('test', [])
    if test_cmd and any('/health' in str(cmd) for cmd in test_cmd):
        print('true')
    else:
        print('false')
")
    
    [ "$has_health_check" = "true" ]
}

# Function to check service health
check_service_health() {
    local service_name=$1
    local max_attempts=10
    local attempt=1
    
    print_status "Checking health for service: $service_name"
    
    while [ $attempt -le $max_attempts ]; do
        # Check if container is running
        if ! docker-compose -f docker-compose/docker-compose.yml ps $service_name | grep -q "Up"; then
            print_error "Service $service_name is not running"
            return 1
        fi
        
        # Check container health status
        health_status=$(docker-compose -f docker-compose/docker-compose.yml ps $service_name | grep -o "healthy\|unhealthy" || echo "no_health_check")
        
        if [ "$health_status" = "healthy" ]; then
            print_success "Service $service_name is healthy"
            return 0
        elif [ "$health_status" = "unhealthy" ]; then
            print_error "Service $service_name is unhealthy"
            return 1
        elif [ "$health_status" = "no_health_check" ]; then
            # Check if this is a sidecar service that should have /health endpoint
            if is_sidecar_service "$service_name"; then
                print_status "Sidecar service detected, checking /health endpoint for $service_name..."
                
                # Get service port from docker-compose
                port=$(python3 -c "
import yaml
with open('docker-compose/docker-compose.yml', 'r') as f:
    compose = yaml.safe_load(f)
    service = compose['services']['$service_name']
    if 'ports' in service and service['ports']:
        port_mapping = service['ports'][0]
        print(port_mapping.split(':')[0])
    else:
        print('')
")
                
                if [ -n "$port" ]; then
                    # Try to call the /health endpoint
                    if curl -f -s "http://localhost:$port/health" >/dev/null 2>&1; then
                        print_success "Service $service_name /health endpoint is responding on port $port"
                        return 0
                    else
                        print_warning "Service $service_name /health endpoint not responding on port $port (attempt $attempt/$max_attempts)"
                    fi
                else
                    print_warning "No port mapping found for sidecar service $service_name"
                fi
            else
                # For non-sidecar services without health checks, try to ping the service
                print_status "No health check defined for $service_name, attempting ping test..."
                
                # Get service port from docker-compose
                port=$(python3 -c "
import yaml
with open('docker-compose/docker-compose.yml', 'r') as f:
    compose = yaml.safe_load(f)
    service = compose['services']['$service_name']
    if 'ports' in service and service['ports']:
        port_mapping = service['ports'][0]
        print(port_mapping.split(':')[0])
    else:
        print('')
")
                
                if [ -n "$port" ]; then
                    # Try to connect to the service
                    if timeout 5 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
                        print_success "Service $service_name is responding on port $port"
                        return 0
                    else
                        print_warning "Service $service_name not responding on port $port (attempt $attempt/$max_attempts)"
                    fi
                else
                    # If no port mapping, just check if container is running
                    print_success "Service $service_name is running (no port check available)"
                    return 0
                fi
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_status "Waiting 10 seconds before retry... (attempt $attempt/$max_attempts)"
            sleep 10
        fi
        
        attempt=$((attempt + 1))
    done
    
    print_error "Service $service_name failed health check after $max_attempts attempts"
    return 1
}

# Check health of all services
print_status "Performing health checks on all services..."
FAILED_SERVICES=()

for service in "${SERVICES[@]}"; do
    if ! check_service_health "$service"; then
        FAILED_SERVICES+=("$service")
    fi
done

# Display test results
echo ""
echo "🧪 Test Results"
echo "==============="

if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
    print_success "All services are healthy! ✅"
    echo ""
    print_status "Services tested:"
    for service in "${SERVICES[@]}"; do
        echo "  ✅ $service"
    done
    echo ""
    print_success "Docker test completed successfully!"
    exit 0
else
    print_error "Some services failed health checks! ❌"
    echo ""
    print_status "Services status:"
    for service in "${SERVICES[@]}"; do
        if [[ " ${FAILED_SERVICES[@]} " =~ " ${service} " ]]; then
            echo "  ❌ $service (FAILED)"
        else
            echo "  ✅ $service (HEALTHY)"
        fi
    done
    echo ""
    print_error "Docker test failed!"
    print_status "Check logs with: docker-compose -f docker-compose/docker-compose.yml logs"
    exit 1
fi 