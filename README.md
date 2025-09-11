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
2. Start the server stack:
   ```bash
   docker-compose up -d
   ```
3. The server will be available on:
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

### Server Configuration
Server settings are located in `rtk/conf/map.conf`. Key settings:
- `map_ip`: Server IP address
- `loginip`: Login server IP

### Environment Variables
Modify `docker-compose.yml` to change:
- `MYSQL_ROOT_PASSWORD`: MySQL root password
- `MYSQL_PASSWORD`: mithia user password
- Port mappings

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