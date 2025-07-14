#!/bin/bash

# DTN Full Node Docker Start/Stop Script
# This script starts or stops the docker-compose services with proper environment loading

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [start|stop|restart|status]"
    echo ""
    echo "Commands:"
    echo "  start   - Start all docker-compose services"
    echo "  stop    - Stop all docker-compose services"
    echo "  restart - Restart all docker-compose services"
    echo "  status  - Show status of all services"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 stop"
    echo "  $0 restart"
    echo "  $0 status"
}

# Function to check prerequisites
check_prerequisites() {
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

    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found. Please run generate-compose.py first"
        exit 1
    fi

    # Check if .env file exists
    if [ ! -f ".env" ]; then
        print_error ".env file not found"
        exit 1
    fi
}

# Function to load environment variables
load_env() {
    print_status "Loading environment variables from .env file..."
    
    if [ -f ".env" ]; then
        # Export all variables from .env file
        set -a  # automatically export all variables
        source .env
        set +a  # stop automatically exporting
        
        print_success "Environment variables loaded"
    else
        print_error ".env file not found"
        exit 1
    fi
}

# Function to start services
start_services() {
    print_status "Starting docker-compose services..."
    
    # Load environment variables
    load_env
    
    # Start services in detached mode
    docker-compose -f docker-compose/docker-compose.yml up -d
    
    if [ $? -eq 0 ]; then
        print_success "Services started successfully"
        print_status "Use '$0 status' to check service status"
        print_status "Use 'docker-compose -f docker-compose/docker-compose.yml logs -f' to view logs"
    else
        print_error "Failed to start services"
        exit 1
    fi
}

# Function to stop services
stop_services() {
    print_status "Stopping docker-compose services..."
    
    # Load environment variables
    load_env
    
    # Stop services
    docker-compose -f docker-compose/docker-compose.yml down
    
    if [ $? -eq 0 ]; then
        print_success "Services stopped successfully"
    else
        print_error "Failed to stop services"
        exit 1
    fi
}

# Function to restart services
restart_services() {
    print_status "Restarting docker-compose services..."
    
    # Load environment variables
    load_env
    
    # Restart services
    docker-compose -f docker-compose/docker-compose.yml restart
    
    if [ $? -eq 0 ]; then
        print_success "Services restarted successfully"
        print_status "Use '$0 status' to check service status"
    else
        print_error "Failed to restart services"
        exit 1
    fi
}

# Function to show service status
show_status() {
    print_status "Checking service status..."
    
    # Load environment variables
    load_env
    
    # Show service status
    docker-compose -f docker-compose/docker-compose.yml ps
}

# Main script logic
main() {
    # Check if command is provided
    if [ $# -eq 0 ]; then
        print_error "No command specified"
        show_usage
        exit 1
    fi

    # Check prerequisites
    check_prerequisites

    # Parse command
    case "$1" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_status
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 