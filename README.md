# Mithia Server

A containerized mithia server setup using Docker for easy deployment and development.

## Quick Start (Recommended)

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- **QEMU emulation** (required for AMD64/ARM64 hosts since server runs on i386 architecture)

#### QEMU Installation
The server uses 32-bit i386 architecture and requires QEMU emulation on modern 64-bit hosts:

**For Ubuntu/Debian (ARM64/AMD64 hosts):**
```bash
sudo apt update
sudo apt install qemu-user-static binfmt-support
sudo systemctl restart systemd-binfmt
```

**Alternative Docker method:**
```bash
# For AMD64 hosts:
sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# For ARM64 hosts:
sudo docker run --rm --privileged multiarch/qemu-user-static:register --reset
```

**Note:** QEMU registration persists until system reboot. You may need to re-run after rebooting your host.

### Setup
1. Clone this repository
2. Create environment file for database secrets:
   ```bash
   cp stack.env.example stack.env
   # Edit stack.env with your database passwords
   ```
3. Create required directories and copy initial config files:
   ```bash
   sudo mkdir -p /opt/mithia/{config,data/{backups,logs,mysql},database/scripts}
   sudo cp -r rtk/conf/* /opt/mithia/config/
   sudo cp -r database/scripts/* /opt/mithia/database/scripts/
   sudo chown -R $USER:$USER /opt/mithia
   ```
4. Start the server stack:
   ```bash
   docker-compose up -d
   ```
5. The server will be available on:
   - Login Server: `localhost:2000`
   - Map Server: `localhost:2001`
   - Character Server: `localhost:2005`
   - MySQL Database: `localhost:3306`

### Initial Database Setup
The database will be automatically initialized with scripts from `database/scripts/` when first started.

## Development

### Building the Server
The server is automatically built when the Docker container starts. To rebuild after code changes:
```bash
docker-compose build server
docker-compose restart server
```

### Database Management
Access the MySQL database using any MySQL client:
- **Host:** `localhost`
- **Port:** `3306`
- **Database:** `RTK`
- **Username:** `rtk`
- **Password:** `changeMe` (change in docker-compose.yml)

### Logs and Debugging
View server logs:
```bash
docker-compose logs -f server
```

Access the server container:
```bash
docker-compose exec server bash
```

## Game Administration

### Creating a GM Character
1. Create a character through the normal game process
2. Log out of the character
3. Connect to the database and promote the character:
   ```sql
   UPDATE `Character` SET `ChaGMLevel` = '99' WHERE `ChaName` = 'YourCharacterName';
   ```

### Reloading Game Data
Use these GM commands in-game to reload data after database changes:
- `/reloadItem` - Reload item data
- `/metan` - Reload item metadata

## Configuration

### Server Configuration Management
After deployment, you can modify server configuration files:

1. **Stop the server** (config changes require restart):
   ```bash
   docker-compose stop server
   ```

2. **Edit configuration files** in `/opt/mithia/config/`:
   - `map.conf`: Map server settings (IP, ports, rates)
   - `login.conf`: Login server settings
   - `char.conf`: Character server and database settings

3. **Restart the server**:
   ```bash
   docker-compose start server
   ```

Key settings in `map.conf`:
- `map_ip`: Server IP address
- `loginip`: Login server IP
- `xprate`: Experience multiplier
- `droprate`: Item drop rate multiplier

### Environment Variables
Database credentials are stored in `stack.env`:
- `MYSQL_ROOT_PASSWORD`: MySQL root password
- `MYSQL_PASSWORD`: RTK user password
- `MYSQL_USER`: Database username (default: rtk)
- `MYSQL_DATABASE`: Database name (default: RTK)

## Architecture

### Services
- **server**: mithia game server (login, character, map servers)
- **database**: MySQL 8.0 database server

### Ports
- `2000`: Login server port
- `2001`: Map server port  
- `2005`: Character server port
- `3306`: MySQL database port

### Volumes
- `./rtk`: Server source code
- `./rtklua`: Lua scripts
- `./rtkmaps`: Game maps
- `./database/scripts`: Database initialization scripts

## Troubleshooting

### Common Issues
- **Server won't start**: Check logs with `docker-compose logs server`
- **Database connection failed**: Ensure database container is running
- **Client can't connect**: Verify port mappings and firewall settings

### Resetting the Environment
```bash
docker-compose down -v
docker-compose up -d
```

## Legacy Setup
For the original VirtualBox-based setup guide, see [LEGACY_SETUP.md](LEGACY_SETUP.md).

## Contributing
1. Make changes to the code
2. Test with `docker-compose build && docker-compose up`
3. Submit a pull request

---

For detailed manual setup instructions using VirtualBox and Ubuntu, see the [Legacy Setup Guide](LEGACY_SETUP.md).