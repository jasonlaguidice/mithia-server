#!/bin/bash
set -e

echo "=== Mithia Server Startup ==="
echo "Resolving Docker service IPs..."

# Resolve Docker service names to actual container IPs for inter-server communication
if [ -n "${LOGIN_SERVER_HOST:-}" ]; then
    LOGIN_SERVER_IP=$(getent hosts ${LOGIN_SERVER_HOST} | awk '{ print $1 }' | head -1)
    echo "  Login Server (internal): $LOGIN_SERVER_IP"
fi

if [ -n "${CHAR_SERVER_HOST:-}" ]; then
    CHAR_SERVER_IP=$(getent hosts ${CHAR_SERVER_HOST} | awk '{ print $1 }' | head -1)
    echo "  Char Server (internal): $CHAR_SERVER_IP"
fi

if [ -n "${MAP_SERVER_HOST:-}" ]; then
    MAP_SERVER_IP=$(getent hosts ${MAP_SERVER_HOST} | awk '{ print $1 }' | head -1)
    echo "  Map Server (internal): $MAP_SERVER_IP"
fi

if [ -n "${DB_HOST:-}" ]; then
    DB_IP=$(getent hosts ${DB_HOST} | awk '{ print $1 }' | head -1 || echo "${DB_HOST}")
    echo "  Database (internal): $DB_IP"
else
    DB_IP="127.0.0.1"
fi

# Get our own container IP
OWN_IP=$(hostname -i | awk '{print $1}')
echo "  Own IP (internal): $OWN_IP"

# Public IP for client connections - use environment variable with fallback
if [ -z "$PUBLIC_MAP_IP" ]; then
    # Fallback: try external IP detection, otherwise use Docker host gateway
    PUBLIC_MAP_IP=$(
        (curl -s --max-time 3 http://ipecho.net/plain 2>/dev/null) ||
        (ip route show default | awk '/default/ {print $3}' 2>/dev/null) ||
        echo "127.0.0.1"
    )
    echo "  Auto-detected public IP: $PUBLIC_MAP_IP"
else
    echo "  Using provided public IP: $PUBLIC_MAP_IP"
fi

# Use same public IP for login server if not specified
if [ -z "$PUBLIC_LOGIN_IP" ]; then
    PUBLIC_LOGIN_IP="$PUBLIC_MAP_IP"
fi
echo "  Public Login IP: $PUBLIC_LOGIN_IP"

# Set default database credentials if not provided
DB_USER=${DB_USER:-${MYSQL_USER:-rtk}}
DB_PASSWORD=${DB_PASSWORD:-${MYSQL_PASSWORD:-changeme}}
DB_NAME=${DB_NAME:-${MYSQL_DATABASE:-RTK}}
DB_PORT=${DB_PORT:-3306}

# Set default server ports (fixed, not configurable)
LOGIN_SERVER_PORT=${LOGIN_SERVER_PORT:-2000}
CHAR_SERVER_PORT=${CHAR_SERVER_PORT:-2005}
MAP_SERVER_PORT=${MAP_SERVER_PORT:-2001}

# Set default game configuration
START_MONEY=${START_MONEY:-100}
START_POINT=${START_POINT:-"0, 1, 1"}
XP_RATE=${XP_RATE:-1}
DROP_RATE=${DROP_RATE:-1}
SERVER_ID=${SERVER_ID:-0}

# Export all variables for envsubst
export LOGIN_SERVER_IP CHAR_SERVER_IP MAP_SERVER_IP DB_IP OWN_IP
export PUBLIC_MAP_IP PUBLIC_LOGIN_IP
export DB_USER DB_PASSWORD DB_NAME DB_PORT
export LOGIN_SERVER_PORT CHAR_SERVER_PORT MAP_SERVER_PORT
export START_MONEY START_POINT XP_RATE DROP_RATE SERVER_ID

echo ""
echo "=== Generating Configuration Files ==="

# Restore template files from backup if they don't exist (due to volume mount override)
echo "Checking for template files..."
if [ ! -f /home/RTK/rtk/conf/char.conf.template ] && [ -d /home/RTK/rtk/conf-templates ]; then
    echo "  Templates missing from mounted volume, restoring from backup..."
    cp /home/RTK/rtk/conf-templates/*.template /home/RTK/rtk/conf/
    echo "  Templates restored"
fi

# Debug: List available template files
echo "Available template files:"
ls -la /home/RTK/rtk/conf/*.template 2>/dev/null || echo "  No template files found"

# Restore SObj.tbl from backup if it doesn't exist (due to volume mount override)
echo "Checking for SObj.tbl..."
if [ ! -f /home/RTK/rtk/SObj.tbl ] && [ -f /home/RTK/rtk/SObj.tbl.backup ]; then
    echo "  SObj.tbl missing, restoring from built-in backup..."
    cp /home/RTK/rtk/SObj.tbl.backup /home/RTK/rtk/SObj.tbl
    echo "  SObj.tbl restored"
elif [ -f /home/RTK/rtk/SObj.tbl ]; then
    echo "  SObj.tbl found (using mounted or existing version)"
else
    echo "  ERROR: SObj.tbl not found and no backup available!"
fi

# Generate configuration files from templates
if [ -f /home/RTK/rtk/conf/inter.conf.template ]; then
    envsubst < /home/RTK/rtk/conf/inter.conf.template > /home/RTK/rtk/conf/inter.conf
    echo "  Generated inter.conf"
else
    echo "  inter.conf.template not found"
fi

if [ -f /home/RTK/rtk/conf/char.conf.template ]; then
    envsubst < /home/RTK/rtk/conf/char.conf.template > /home/RTK/rtk/conf/char.conf
    echo "  Generated char.conf"
    echo "  DB_IP resolved to: $DB_IP"
else
    echo "  char.conf.template not found"
fi

if [ -f /home/RTK/rtk/conf/map.conf.template ]; then
    envsubst < /home/RTK/rtk/conf/map.conf.template > /home/RTK/rtk/conf/map.conf
    echo "  Generated map.conf"
else
    echo "  map.conf.template not found"
fi

# Debug: Show final char.conf database config
if [ -f /home/RTK/rtk/conf/char.conf ]; then
    echo "Final char.conf database config:"
    grep -A5 "sql_ip:" /home/RTK/rtk/conf/char.conf || echo "  No sql_ip found in char.conf"
fi

if [ -f /home/RTK/rtk/conf/login.conf.template ]; then
    envsubst < /home/RTK/rtk/conf/login.conf.template > /home/RTK/rtk/conf/login.conf
    echo "  Generated login.conf"
fi

if [ -f /home/RTK/rtk/conf/save.conf.template ]; then
    envsubst < /home/RTK/rtk/conf/save.conf.template > /home/RTK/rtk/conf/save.conf
    echo "  Generated save.conf"
fi

echo ""
echo "=== Configuration Summary ==="
echo "  Internal IPs (Docker network):"
echo "    Login: ${LOGIN_SERVER_IP:-N/A}"
echo "    Char: ${CHAR_SERVER_IP:-N/A}"
echo "    Map: ${MAP_SERVER_IP:-N/A}"
echo "    Database: ${DB_IP:-N/A} (internal only)"
echo "  Public IPs (client-facing):"
echo "    Map: $PUBLIC_MAP_IP:$MAP_SERVER_PORT"
echo "    Login: $PUBLIC_LOGIN_IP:$LOGIN_SERVER_PORT"
echo ""

echo "=== Starting Server ==="

# Debug: Show executable information
echo "DEBUG: Executable path: $1"
echo "DEBUG: File exists: $(ls -la "$1" 2>/dev/null || echo "FILE NOT FOUND")"
echo "DEBUG: File permissions: $(stat -c '%A' "$1" 2>/dev/null || echo "STAT FAILED")"

# Debug: Check library dependencies
echo "DEBUG: Library dependencies:"
ldd "$1" 2>/dev/null || echo "LDD failed - not a dynamic executable or missing libraries"

echo "DEBUG: Installed MySQL client libraries:"
find /usr/lib* -name "*mysql*" 2>/dev/null | head -10

echo "DEBUG: Installed Lua libraries:"
find /usr/lib* -name "*lua*" 2>/dev/null | head -10

echo "DEBUG: Architecture information:"
echo "  Container arch: $(uname -m)"
echo "  Executable arch: $(file "$1" 2>/dev/null || echo "FILE command failed")"

# Test if the executable can run at all
echo "DEBUG: Testing if executable starts..."
echo "DEBUG: About to exec (line-buffered): $@"

# Execute the server with line-buffered stdout/stderr so Docker logs capture prints immediately
# Also mirror output into logs/console.log so you can compare with bare metal logs on the host
mkdir -p logs
if command -v stdbuf >/dev/null 2>&1; then
  stdbuf -oL -eL "$@" 2>&1 | tee -a logs/console.log
else
  "$@" 2>&1 | tee -a logs/console.log
fi
