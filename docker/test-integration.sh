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
    cleanup_on_failure
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "ℹ️  $1"
}

# Cleanup function - only on success to preserve diagnostics
cleanup_on_success() {
    info "Cleaning up test environment..."
    docker compose -f $COMPOSE_FILE down -v --remove-orphans 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
}

# Cleanup function for failures - preserve containers for diagnostics
cleanup_on_failure() {
    warning "Test failed - preserving containers for diagnostics"
    warning "GitHub Actions will collect logs from running containers"
}

info "Starting microservices integration test..."
info "Using compose file: $COMPOSE_FILE"

# Ensure required directories exist for volume mounts
info "Creating required directories for Docker volume mounts..."
mkdir -p data/{logs,mysql,backups}
info "  Created data/logs, data/mysql, data/backups"

# Ensure config directory has write permissions for container users
info "Setting config directory permissions for container access..."
chmod -R 777 rtk/conf
info "  Set rtk/conf permissions to 777 (read/write for all users)"

# Test 1: Start services
echo ""
echo "Test 1: Starting Services"
echo "=========================="
info "Starting all services with docker compose..."
docker compose -f $COMPOSE_FILE up -d

# Immediate status check after startup
info "Checking immediate container status..."
docker compose -f $COMPOSE_FILE ps --format "table"

# Check for any immediate failures
info "Checking for immediate container logs..."
for service in mithia-login mithia-char mithia-map mithia-db; do
    echo "=== $service startup logs ==="
    docker compose -f $COMPOSE_FILE logs $service --tail=20 || echo "No logs available for $service"
done

info "Waiting $TIMEOUT_SERVICES seconds for services to initialize..."
# Check status every 15 seconds during wait
for i in $(seq 1 4); do
    sleep 15
    info "Status check $i/4 (${i}5s elapsed):"
    docker compose -f $COMPOSE_FILE ps --format "table"

    # Check for any crashed containers
    CRASHED=$(docker compose -f $COMPOSE_FILE ps --filter "status=exited" --format "{{.Service}}" | wc -l)
    if [ "$CRASHED" -gt 0 ]; then
        warning "Found $CRASHED crashed containers, collecting logs..."
        for service in mithia-login mithia-char mithia-map mithia-db; do
            echo "=== $service crash logs ==="
            docker compose -f $COMPOSE_FILE logs $service --tail=50 || echo "No logs for $service"
        done
        break
    fi
done

# Test 2: Check container status
echo ""
echo "Test 2: Container Status"
echo "========================"
EXPECTED_SERVICES=4  # login, char, map, db
RUNNING_SERVICES=$(docker compose -f $COMPOSE_FILE ps --services --filter "status=running" | wc -l)

if [ "$RUNNING_SERVICES" -eq "$EXPECTED_SERVICES" ]; then
    success "All $EXPECTED_SERVICES services are running"
else
    error "Only $RUNNING_SERVICES/$EXPECTED_SERVICES services are running"
fi

# List running services
info "Running services:"
docker compose -f $COMPOSE_FILE ps --format "table"

# Test 3: Database health check
echo ""
echo "Test 3: Database Health"
echo "======================"
info "Testing database connectivity..."
for i in {1..10}; do
    if docker compose -f $COMPOSE_FILE exec -T mithia-db mysqladmin ping -h localhost --silent 2>/dev/null; then
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

# Test 4: Service readiness check
echo ""
echo "Test 4: Service Readiness"
echo "========================"
info "Checking for service ready messages in logs..."

# Test login server readiness
if docker compose -f $COMPOSE_FILE logs mithia-login | grep -q "RetroTK Login Server is ready! Listening at 2000."; then
    success "Login server is ready and listening at 2000"
else
    error "Login server ready message not found"
fi

# Test character server readiness
if docker compose -f $COMPOSE_FILE logs mithia-char | grep -q "RetroTK Char Server is ready! Listening at 2005."; then
    success "Character server is ready and listening at 2005"
else
    error "Character server ready message not found"
fi

# Test map server readiness
if docker compose -f $COMPOSE_FILE logs mithia-map | grep -q "RetroTK Map Server is ready! Listening at 2001."; then
    success "Map server is ready and listening at 2001"
else
    error "Map server ready message not found"
fi

# Test 5: Inter-server connectivity
echo ""
echo "Test 5: Inter-Server Connectivity"
echo "================================="
info "Checking for successful inter-server connections..."

# Test character server connects to login server
if docker compose -f $COMPOSE_FILE logs mithia-char | grep -q "Connected to Login Server."; then
    success "Character server connected to login server"
else
    error "Character server connection to login server not found"
fi

# Test map server connects to character server
if docker compose -f $COMPOSE_FILE logs mithia-map | grep -q "Connected to Char Server."; then
    success "Map server connected to character server"
else
    error "Map server connection to character server not found"
fi

# Test login server accepts character server connection
if docker compose -f $COMPOSE_FILE logs mithia-login | grep -q "Connection from Char Server accepted."; then
    success "Login server accepted character server connection"
else
    error "Login server character server acceptance not found"
fi

# Test character server accepts map server connection (optional - may appear as Map Server #0 connected)
if docker compose -f $COMPOSE_FILE logs mithia-char | grep -q "Map Server.*connected"; then
    success "Character server accepted map server connection"
else
    warning "Character server map server acceptance not found (may be normal)"
fi


# Test completion
echo ""
echo "=================================="
echo "🎉 ALL INTEGRATION TESTS PASSED! 🎉"
echo "=================================="
info "Microservices architecture is working correctly"
info "Services can communicate with each other"

# Optional: Show final status
echo ""
echo "Final Service Status:"
echo "===================="
docker compose -f $COMPOSE_FILE ps

# Cleanup on successful completion
cleanup_on_success