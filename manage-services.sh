#!/bin/bash
# Mithia Server - Service Management Script
# Quick commands to manage Mithia services on Ubuntu

set -e

COMPOSE_FILE="docker-compose.production.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_usage() {
    echo "Mithia Service Manager"
    echo ""
    echo "Usage: ./manage-services.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start         - Start all services"
    echo "  stop          - Stop all services"
    echo "  restart       - Restart all services"
    echo "  status        - Show service status"
    echo "  logs          - Show logs (all services)"
    echo "  logs-login    - Show login server logs"
    echo "  logs-char     - Show char server logs"
    echo "  logs-map      - Show map server logs"
    echo "  logs-db       - Show database logs"
    echo "  scale-map N   - Scale map servers to N instances"
    echo "  rebuild       - Rebuild and restart services"
    echo "  backup-db     - Backup database"
    echo "  restore-db    - Restore database from backup"
    echo "  health        - Check service health"
    echo "  clean         - Clean up stopped containers and images"
    echo ""
}

cmd_start() {
    echo -e "${BLUE}Starting services...${NC}"
    docker compose -f "$COMPOSE_FILE" up -d
    echo -e "${GREEN}Services started${NC}"
}

cmd_stop() {
    echo -e "${YELLOW}Stopping services...${NC}"
    docker compose -f "$COMPOSE_FILE" down
    echo -e "${GREEN}Services stopped${NC}"
}

cmd_restart() {
    echo -e "${YELLOW}Restarting services...${NC}"
    docker compose -f "$COMPOSE_FILE" restart
    echo -e "${GREEN}Services restarted${NC}"
}

cmd_status() {
    echo -e "${BLUE}Service Status:${NC}"
    docker compose -f "$COMPOSE_FILE" ps
}

cmd_logs() {
    docker compose -f "$COMPOSE_FILE" logs -f --tail=100
}

cmd_logs_service() {
    local service=$1
    docker compose -f "$COMPOSE_FILE" logs -f --tail=100 "$service"
}

cmd_scale_map() {
    local count=$1
    if [[ -z "$count" ]]; then
        echo -e "${RED}Error: Please specify number of map server instances${NC}"
        echo "Usage: ./manage-services.sh scale-map 3"
        exit 1
    fi
    echo -e "${BLUE}Scaling map servers to $count instances...${NC}"
    docker compose -f "$COMPOSE_FILE" up -d --scale mithia-map="$count" --no-recreate
    echo -e "${GREEN}Map servers scaled to $count${NC}"
}

cmd_rebuild() {
    echo -e "${BLUE}Rebuilding services...${NC}"
    docker compose -f "$COMPOSE_FILE" build
    docker compose -f "$COMPOSE_FILE" up -d
    echo -e "${GREEN}Services rebuilt and restarted${NC}"
}

cmd_backup_db() {
    local backup_file="backup_$(date +%Y%m%d_%H%M%S).sql"
    echo -e "${BLUE}Backing up database to $backup_file...${NC}"

    read -sp "Enter MySQL password: " mysql_pass
    echo ""

    docker compose -f "$COMPOSE_FILE" exec -T mithia-db mysqldump -u rtk -p"$mysql_pass" RTK > "$backup_file"

    if [[ -f "$backup_file" ]]; then
        echo -e "${GREEN}Database backed up to $backup_file${NC}"
        echo -e "${YELLOW}File size: $(du -h "$backup_file" | cut -f1)${NC}"
    else
        echo -e "${RED}Backup failed${NC}"
        exit 1
    fi
}

cmd_restore_db() {
    echo "Available backups:"
    ls -lh backup_*.sql 2>/dev/null || echo "No backups found"
    echo ""
    read -p "Enter backup file name: " backup_file

    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}Backup file not found: $backup_file${NC}"
        exit 1
    fi

    read -sp "Enter MySQL password: " mysql_pass
    echo ""

    echo -e "${YELLOW}Restoring database from $backup_file...${NC}"
    docker compose -f "$COMPOSE_FILE" exec -T mithia-db mysql -u rtk -p"$mysql_pass" RTK < "$backup_file"

    echo -e "${GREEN}Database restored from $backup_file${NC}"
}

cmd_health() {
    echo -e "${BLUE}Checking service health...${NC}"
    echo ""

    # Check database
    echo -n "Database (MySQL): "
    if docker compose -f "$COMPOSE_FILE" exec -T mithia-db mysqladmin ping -h localhost &>/dev/null; then
        echo -e "${GREEN}✓ Healthy${NC}"
    else
        echo -e "${RED}✗ Unhealthy${NC}"
    fi

    # Check login server
    echo -n "Login Server:     "
    if nc -z localhost 2000 2>/dev/null; then
        echo -e "${GREEN}✓ Healthy${NC}"
    else
        echo -e "${RED}✗ Unhealthy${NC}"
    fi

    # Check char server
    echo -n "Char Server:      "
    if nc -z localhost 2005 2>/dev/null; then
        echo -e "${GREEN}✓ Healthy${NC}"
    else
        echo -e "${RED}✗ Unhealthy${NC}"
    fi

    # Check map server
    echo -n "Map Server:       "
    if nc -z localhost 2001 2>/dev/null; then
        echo -e "${GREEN}✓ Healthy${NC}"
    else
        echo -e "${RED}✗ Unhealthy${NC}"
    fi

    # Check web dashboard
    echo -n "Web Dashboard:    "
    if nc -z localhost 8080 2>/dev/null; then
        echo -e "${GREEN}✓ Healthy${NC}"
    else
        echo -e "${RED}✗ Unhealthy${NC}"
    fi

    echo ""
    echo "Container stats:"
    docker stats --no-stream
}

cmd_clean() {
    echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
    echo "This will remove:"
    echo "  - Stopped containers"
    echo "  - Unused networks"
    echo "  - Dangling images"
    echo ""
    read -p "Continue? (y/N): " confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        docker system prune -f
        echo -e "${GREEN}Cleanup complete${NC}"
    else
        echo "Cancelled"
    fi
}

# Main command handler
case "${1:-}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    logs-login)
        cmd_logs_service mithia-login
        ;;
    logs-char)
        cmd_logs_service mithia-char
        ;;
    logs-map)
        cmd_logs_service mithia-map
        ;;
    logs-db)
        cmd_logs_service mithia-db
        ;;
    scale-map)
        cmd_scale_map "$2"
        ;;
    rebuild)
        cmd_rebuild
        ;;
    backup-db)
        cmd_backup_db
        ;;
    restore-db)
        cmd_restore_db
        ;;
    health)
        cmd_health
        ;;
    clean)
        cmd_clean
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
