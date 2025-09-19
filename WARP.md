# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Mithia Server is a containerized RTK (Role-Playing Toolkit) MMORPG server implementation written in C. The server uses a multi-process architecture with separate login, character, and map servers communicating through MySQL database and inter-server protocols.

## Architecture

### Core Components
- **Login Server** (`src/login/`): Handles user authentication and account management (Port 2000)
- **Character Server** (`src/char/`): Manages character data and bridges login/map servers (Port 2005)  
- **Map Server** (`src/map/`): Game world simulation and player interactions (Port 2001)
- **MySQL Database**: Persistent storage for accounts, characters, and game data (Port 3306)

### Key Directories
- `rtk/src/`: C source code for all server components
- `rtk/conf/`: Server configuration files (*.conf)
- `rtklua/`: Lua scripts for game logic and formulas
- `rtkmaps/`: Game map data and warp configurations
- `database/scripts/`: SQL migration scripts for database schema

## Essential Commands

### Development Workflow

```bash
# Setup environment (first time)
cp stack.env.example stack.env
# Edit stack.env with secure database passwords

# Build all server components
cd rtk
make clean
make all

# Docker-based development (recommended)
docker-compose build server
docker-compose up -d

# View logs
docker-compose logs -f server
```

### Server Management

```bash
# Start all servers (in container)
./start-mithia-servers

# Stop all servers
./shutdown-mithia-servers

# Check server status
./check-mithia-server-state

# Individual server control
./login-server &
./char-server &
./map-server &
```

### Database Operations

```bash
# Run database migrations
cd database
./migrate.sh

# Create database backup
./backup.sh

# Connect to database
mysql -h localhost -P 3306 -u rtk -p RTK
```

### Testing and Debugging

```bash
# Build specific component
cd rtk
make login    # Login server only
make char     # Character server only  
make map      # Map server only
make metan    # Metadata creator tool

# View server logs
tail -f rtk/logs/login.log
tail -f rtk/logs/char.log
tail -f rtk/logs/map.log

# Debug with packet dumps (set dump_save: 1 in conf files)
tail -f rtk/logs/*_dump.log
```

## Configuration Management

### Server Configuration Files
- `rtk/conf/login.conf`: Login server settings, version info, metadata loading
- `rtk/conf/char.conf`: Character server and database connection settings
- `rtk/conf/map.conf`: Map server settings, IP addresses, rates (XP, drop rates)

### Key Configuration Parameters
- **IP Addresses**: Update `map_ip` and `loginip` in `map.conf` for client connectivity
- **Experience/Drop Rates**: Modify `xprate` and `droprate` in `map.conf`  
- **Database**: Connection settings in `char.conf` (sql_ip, sql_port, sql_id, sql_pw, sql_db)

### Environment Variables (stack.env)
```bash
MYSQL_ROOT_PASSWORD=    # MySQL root password
MYSQL_USER=rtk          # Database username
MYSQL_PASSWORD=         # RTK user password  
MYSQL_DATABASE=RTK      # Database name
```

## Game Administration

### Creating GM Characters
```sql
-- After creating character through normal game process
UPDATE `Character` SET `ChaGMLevel` = '99' WHERE `ChaName` = 'YourCharacterName';
```

### Reloading Game Data (GM Commands)
```
/reloadItem  # Reload item database
/metan       # Reload item metadata
```

## Architecture Notes

### Multi-Server Communication
- Login server authenticates users and forwards to character server
- Character server manages character data and forwards to appropriate map server
- Map servers handle game world simulation and can be scaled horizontally
- All servers communicate through MySQL database and direct TCP connections

### Database Schema
- Migration-based database management in `database/scripts/`
- Chronologically ordered SQL files (YYYY-MM-DD-HH-MM format)
- Automated backup system retains 72 backups (6 hours at 5-minute intervals)

### 32-bit Architecture
- Server runs on i386/32-bit architecture for compatibility
- Requires QEMU emulation on modern 64-bit hosts
- Docker automatically handles architecture emulation

### Metadata System
- Game data loaded from database into memory at server startup
- Metadata files (ItemInfo0, ItemInfo1, CharicInfo0, etc.) must be reloaded after database changes
- Use `/metan` GM command to refresh metadata without server restart

## Docker Deployment

### Production Setup
```bash
# Use pre-built images
docker-compose -f docker-compose.production.yml up

# Scale map servers for load balancing
docker-compose up --scale mithia-map=3
```

### Development Setup
```bash
# Local builds with live code changes
docker-compose -f docker-compose.microservices.yml up --build
```

## Development and CI/CD

### GitHub Actions Workflows
```bash
# Manual monolithic build (legacy)
# Triggers: workflow_dispatch only
# File: .github/workflows/docker-build.yml

# Microservices build (modern approach)
# Triggers: push to main, tags, PRs
# File: .github/workflows/microservices-build.yml
# Builds: login-server, char-server, map-server individually
```

### Container Registry
- Images published to: `ghcr.io/jasonlaguidice/mithia-server`
- Multi-architecture support: linux/amd64, linux/arm64
- Separate images for each service in microservices mode

### Lua Scripting System

#### Key Lua Components
- **Spells System**: Extensive spell implementations per class (warrior, mage, poet, rogue)
- **NPCs and AI**: Complex NPC behavior and mob AI systems
- **Game Logic**: Combat, crafting, quests, and world interactions
- **Items System**: Item effects, consumables, equipment behaviors

#### Important Lua Directories
- `rtklua/Accepted/Spells/`: Class-based spell implementations
- `rtklua/Accepted/NPCs/`: NPC interactions and shop systems
- `rtklua/Accepted/AI/`: Monster and NPC artificial intelligence
- `rtklua/Accepted/Items/`: Item usage and effect scripts
- `rtklua/Accepted/Crafting/`: Crafting system implementations
- `rtklua/Developers/`: Development tools and system scripts

#### Lua Script Loading
- Scripts loaded at server startup via metadata system
- Use `/reloadItem` and `/metan` to refresh without restart
- `formulae.lua` contains core game calculation functions

## Network Configuration
- Internal Docker network: 172.20.0.0/16
- Service discovery through Docker DNS
- Port mappings: 2000 (login), 2001 (map), 2005 (char), 3306 (database)

## Monitoring and Logging

### Log Categories
- **Character logs**: `rtklua/History/logs/characterlog/`
- **Chat logs**: `rtklua/History/logs/chatlogs/` (general, GM, subpath-specific)
- **Boss kills**: `rtklua/History/logs/boss_kills/`
- **Item drops**: `rtklua/History/logs/drops/`
- **Server logs**: `rtk/logs/` (login.log, char.log, map.log)

### Development Tools
```bash
# GM tools for world editing
rtklua/Accepted/Tools/map_editor.lua
rtklua/Accepted/Tools/spawn_tool.lua

# Testing utilities
rtklua/Developers/scripts.lua
rtklua/Accepted/Scripts/
```
