#!/bin/bash
# Mithia Server - Ubuntu Production Deployment Script
# This script automates the deployment process on Ubuntu Server

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PUBLIC_IP="184.107.141.66"
COMPOSE_FILE="docker-compose.production.yml"
ENV_FILE="stack.env.production"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Mithia Server Deployment Script${NC}"
echo -e "${BLUE}  Ubuntu Production Environment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print colored messages
print_info() {
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

# Check if running with appropriate permissions
check_permissions() {
    if [[ ! -w "." ]]; then
        print_error "No write permission in current directory"
        exit 1
    fi
    print_success "Permission check passed"
}

# Check if Docker is installed
check_docker() {
    print_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please run setup-ubuntu.sh first."
        exit 1
    fi
    print_success "Docker is installed: $(docker --version)"
}

# Check if Docker Compose is installed
check_docker_compose() {
    print_info "Checking Docker Compose installation..."
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please run setup-ubuntu.sh first."
        exit 1
    fi
    print_success "Docker Compose is installed: $(docker compose version)"
}

# Check if environment file exists
check_env_file() {
    print_info "Checking environment file..."
    if [[ ! -f "$ENV_FILE" ]]; then
        print_error "Environment file $ENV_FILE not found!"
        print_info "Creating from template..."
        if [[ -f "stack.env.example" ]]; then
            cp stack.env.example "$ENV_FILE"
            print_warning "Please edit $ENV_FILE and set secure passwords!"
            exit 1
        else
            print_error "Template file stack.env.example not found!"
            exit 1
        fi
    fi

    # Check if passwords have been changed
    if grep -q "CHANGE_THIS" "$ENV_FILE"; then
        print_error "Please change default passwords in $ENV_FILE before deploying!"
        exit 1
    fi

    print_success "Environment file configured"
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    mkdir -p rtk/logs/{login,char,map}
    mkdir -p mithia-data/database/scripts
    mkdir -p mithia-data/data/backups
    mkdir -p web/public
    mkdir -p web/nginx

    chmod -R 755 rtk
    chmod -R 755 mithia-data

    print_success "Directories created"
}

# Pull/Build Docker images
build_images() {
    print_info "Building Docker images (this may take a while)..."
    if docker compose -f "$COMPOSE_FILE" build; then
        print_success "Images built successfully"
    else
        print_error "Failed to build images"
        exit 1
    fi
}

# Start services
start_services() {
    print_info "Starting services..."
    if docker compose -f "$COMPOSE_FILE" up -d; then
        print_success "Services started"
    else
        print_error "Failed to start services"
        exit 1
    fi
}

# Wait for services to be healthy
wait_for_health() {
    print_info "Waiting for services to become healthy..."
    sleep 10

    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        local unhealthy=$(docker compose -f "$COMPOSE_FILE" ps | grep -c "unhealthy" || true)
        local starting=$(docker compose -f "$COMPOSE_FILE" ps | grep -c "health: starting" || true)

        if [[ $unhealthy -eq 0 && $starting -eq 0 ]]; then
            print_success "All services are healthy"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -ne "\r${BLUE}[INFO]${NC} Waiting... ($attempt/$max_attempts)"
        sleep 10
    done

    echo ""
    print_warning "Services may not be fully healthy yet. Check logs with: docker compose -f $COMPOSE_FILE logs"
}

# Display service status
show_status() {
    echo ""
    print_info "Service Status:"
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
}

# Display connection information
show_connection_info() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Server IP:${NC} $PUBLIC_IP"
    echo ""
    echo -e "${BLUE}Service Ports:${NC}"
    echo "  Login Server:  $PUBLIC_IP:2000"
    echo "  Char Server:   $PUBLIC_IP:2005"
    echo "  Map Server:    $PUBLIC_IP:2001"
    echo "  Web Dashboard: http://$PUBLIC_IP:8080"
    echo "  Metrics:       http://$PUBLIC_IP:9000/metrics/players"
    echo "  MySQL:         $PUBLIC_IP:3306"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View logs:     docker compose -f $COMPOSE_FILE logs -f"
    echo "  Stop services: docker compose -f $COMPOSE_FILE down"
    echo "  Restart:       docker compose -f $COMPOSE_FILE restart"
    echo "  Status:        docker compose -f $COMPOSE_FILE ps"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Test connectivity to all ports"
    echo "  2. Check logs for any errors"
    echo "  3. Configure your game client to connect to $PUBLIC_IP"
    echo "  4. Access web dashboard at http://$PUBLIC_IP:8080"
    echo ""
}

# Main deployment flow
main() {
    print_info "Starting deployment process..."
    echo ""

    check_permissions
    check_docker
    check_docker_compose
    check_env_file
    create_directories
    build_images
    start_services
    wait_for_health
    show_status
    show_connection_info

    print_success "Deployment completed successfully!"
}

# Run main function
main
