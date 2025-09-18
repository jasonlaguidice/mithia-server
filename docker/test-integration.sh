#!/bin/bash
set -e

echo "=================================="
echo "   Mithia Server Integration Test"
echo "=================================="

# Configuration
COMPOSE_FILE="docker-compose.yml"
TIMEOUT_SERVICES=60
TIMEOUT_HEALTH=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "ℹ️  $1"
}

# Cleanup function
cleanup() {
    info "Cleaning up test environment..."
    docker-compose -f $COMPOSE_FILE down -v --remove-orphans 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
}

# Set trap for cleanup on exit
trap cleanup EXIT

info "Starting microservices integration test..."
info "Using compose file: $COMPOSE_FILE"

# Test 1: Start services
echo ""
echo "Test 1: Starting Services"
echo "=========================="
info "Starting all services with docker-compose..."
docker-compose -f $COMPOSE_FILE up -d

info "Waiting $TIMEOUT_SERVICES seconds for services to initialize..."
sleep $TIMEOUT_SERVICES

# Test 2: Check container status
echo ""
echo "Test 2: Container Status"
echo "========================"
EXPECTED_SERVICES=4  # login, char, map, db
RUNNING_SERVICES=$(docker-compose -f $COMPOSE_FILE ps --services --filter "status=running" | wc -l)

if [ "$RUNNING_SERVICES" -eq "$EXPECTED_SERVICES" ]; then
    success "All $EXPECTED_SERVICES services are running"
else
    error "Only $RUNNING_SERVICES/$EXPECTED_SERVICES services are running"
fi

# List running services
info "Running services:"
docker-compose -f $COMPOSE_FILE ps --format "table"

# Test 3: Database health check
echo ""
echo "Test 3: Database Health"
echo "======================"
info "Testing database connectivity..."
for i in {1..10}; do
    if docker-compose -f $COMPOSE_FILE exec -T mithia-db mysqladmin ping -h localhost --silent 2>/dev/null; then
        success "Database is responsive (attempt $i)"
        break
    else
        if [ $i -eq 10 ]; then
            error "Database failed to respond after 10 attempts"
        fi
        info "Database not ready, waiting... (attempt $i/10)"
        sleep 3
    fi
done

# Test 4: Service network connectivity
echo ""
echo "Test 4: Inter-Service Network"
echo "============================="
info "Testing Docker network connectivity between services..."

# Test char server can reach database
if docker-compose -f $COMPOSE_FILE exec -T mithia-char ping -c 1 mithia-db >/dev/null 2>&1; then
    success "Character server can reach database"
else
    error "Character server cannot reach database"
fi

# Test char server can reach login server
if docker-compose -f $COMPOSE_FILE exec -T mithia-char ping -c 1 mithia-login >/dev/null 2>&1; then
    success "Character server can reach login server"
else
    error "Character server cannot reach login server"
fi

# Test map server can reach char server
if docker-compose -f $COMPOSE_FILE exec -T mithia-map ping -c 1 mithia-char >/dev/null 2>&1; then
    success "Map server can reach character server"
else
    error "Map server cannot reach character server"
fi

# Test 5: Configuration file generation
echo ""
echo "Test 5: Configuration Files"
echo "==========================="
info "Verifying configuration files were generated with resolved IPs..."

# Check char.conf has resolved database IP
CHAR_DB_IP=$(docker-compose -f $COMPOSE_FILE exec -T mithia-char cat /home/RTK/rtk/conf/char.conf | grep "sql_ip:" | awk '{print $2}')
if [[ "$CHAR_DB_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    success "Character server config has resolved database IP: $CHAR_DB_IP"
else
    error "Character server config does not have valid database IP: $CHAR_DB_IP"
fi

# Check inter.conf has resolved server IPs
LOGIN_IP=$(docker-compose -f $COMPOSE_FILE exec -T mithia-char cat /home/RTK/rtk/conf/inter.conf | grep "login_ip:" | awk '{print $2}')
if [[ "$LOGIN_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    success "Inter-server config has resolved login IP: $LOGIN_IP"
else
    error "Inter-server config does not have valid login IP: $LOGIN_IP"
fi

# Test 6: Port accessibility
echo ""
echo "Test 6: Service Ports"
echo "===================="
info "Testing if service ports are accessible from host..."

# Check if ports are bound on host
for port in 2000 2001 2005 3306; do
    if nc -z localhost $port 2>/dev/null; then
        success "Port $port is accessible from host"
    else
        error "Port $port is not accessible from host"
    fi
done

# Test 7: Service process validation
echo ""
echo "Test 7: Service Processes"
echo "========================"
info "Verifying game server processes are running inside containers..."

# Check login server process
if docker-compose -f $COMPOSE_FILE exec -T mithia-login pgrep login-server >/dev/null; then
    success "Login server process is running"
else
    error "Login server process is not running"
fi

# Check character server process
if docker-compose -f $COMPOSE_FILE exec -T mithia-char pgrep char-server >/dev/null; then
    success "Character server process is running"
else
    error "Character server process is not running"
fi

# Check map server process
if docker-compose -f $COMPOSE_FILE exec -T mithia-map pgrep map-server >/dev/null; then
    success "Map server process is running"
else
    error "Map server process is not running"
fi

# Test completion
echo ""
echo "=================================="
echo "🎉 ALL INTEGRATION TESTS PASSED! 🎉"
echo "=================================="
info "Microservices architecture is working correctly"
info "Services can communicate with each other"
info "Configuration files are properly generated"
info "All server processes are running successfully"

# Optional: Show final status
echo ""
echo "Final Service Status:"
echo "===================="
docker-compose -f $COMPOSE_FILE ps