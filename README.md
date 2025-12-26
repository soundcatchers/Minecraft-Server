# Minecraft Server for Raspberry Pi 4

A complete setup for running a cross-platform Minecraft server (Java + Bedrock) on a Raspberry Pi 4.

## Features

- **PaperMC Server**: Optimized Minecraft server (1.21.10)
- **Cross-Platform**: Java and Bedrock players can play together
- **Geyser + Floodgate**: Bedrock players connect without Java accounts
- **ViaVersion**: Version compatibility support
- **Optimized Performance**: Aikar's flags for smooth gameplay
- **Auto-Start**: Systemd service for boot-on-startup

## Quick Start

### 1. Prerequisites

On your Raspberry Pi 4 (8GB recommended):

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 21 (required for Paper 1.21+)
# Option 1: If available in your repos
sudo apt install openjdk-21-jdk -y

# Option 2: If not available, use Adoptium repository
# curl -s https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc
# echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
# sudo apt update && sudo apt install temurin-21-jdk -y

# Verify Java version (should show 21.x.x)
java -version

# Create minecraft user (if not exists)
sudo useradd -r -m -U -d /home/minecraft -s /bin/bash minecraft

# Switch to minecraft user
sudo su - minecraft
```

### 2. Clone and Setup

```bash
# Clone this repository
git clone https://github.com/soundcatchers/minecraft-server minecraft-config
cd minecraft-config

# Run the setup script
bash scripts/setup.sh
```

### 3. Install Auto-Start Service (Optional)

```bash
# Run as root/sudo
sudo bash scripts/install-systemd.sh

# Start the server
sudo systemctl start minecraft
```

## Connection Details

| Edition | Address | Port |
|---------|---------|------|
| Java | `<your-pi-ip>` | 25565 |
| Bedrock | `<your-pi-ip>` | 19132 |

Find your Pi's IP: `hostname -I`

## Server Management

### Systemd Commands

```bash
# Start server
sudo systemctl start minecraft

# Stop server
sudo systemctl stop minecraft

# Restart server
sudo systemctl restart minecraft

# Check status
sudo systemctl status minecraft

# View live logs
sudo journalctl -u minecraft -f

# Disable auto-start
sudo systemctl disable minecraft

# Enable auto-start
sudo systemctl enable minecraft
```

### Manual Start (Without Systemd)

```bash
cd ~/minecraft-server
java -Xms3G -Xmx3G -jar paper-1.21.10-129.jar nogui
```

### Using Screen (Keeps Running After SSH Disconnect)

```bash
# Install screen
sudo apt install screen

# Start server in screen
screen -S minecraft
cd ~/minecraft-server
java -Xms3G -Xmx3G -jar paper-1.21.10-129.jar nogui

# Detach: Ctrl+A, then D
# Reconnect: screen -r minecraft
```

## Player Permissions

### Give Operator Powers

```
# For Java players
op PlayerUsername

# For Bedrock players (note the dot prefix)
op .XboxGamertag

# For gamertags with spaces (use underscores)
op .Cool_Player_123
```

### Remove Operator

```
deop PlayerUsername
deop .XboxGamertag
```

## Common In-Game Commands (for OPs)

```
# Change difficulty
/difficulty peaceful|easy|normal|hard

# Change gamemode
/gamemode survival|creative|adventure
/gamemode creative PlayerName

# Time and weather
/time set day|night
/weather clear|rain

# Teleport
/tp PlayerName x y z
/tp PlayerName OtherPlayer
```

## Configuration Files

| File | Purpose |
|------|---------|
| `server.properties` | Main server settings |
| `config/paper-global.yml` | Paper global optimizations |
| `config/paper-world-defaults.yml` | World-specific optimizations |
| `ops.json` | Operator list |
| `etc/systemd/system/minecraft.service` | Systemd service file |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup.sh` | Initial server setup - downloads Paper, plugins, configs |
| `scripts/install-systemd.sh` | Install auto-start service with Aikar's JVM flags |
| `scripts/auto-update.sh` | Check and install stable updates for all software |
| `scripts/install-cron.sh` | Install daily automatic update cron job |
| `scripts/update-plugins.sh` | Manual plugin update (Geyser/Floodgate/ViaVersion) |
| `scripts/backup.sh` | Backup world data and configs |

## Installed Plugins

1. **Geyser-Spigot** - Allows Bedrock players to connect
2. **Floodgate** - Bedrock players don't need Java accounts
3. **ViaVersion** - Version compatibility support

## Port Forwarding (For Remote Friends)

To let friends outside your network connect:

1. Log into your router (usually `192.168.1.1`)
2. Find "Port Forwarding" or "Virtual Server"
3. Add these rules:
   - **Java**: External 25565 → Internal 25565 (TCP)
   - **Bedrock**: External 19132 → Internal 19132 (UDP)
4. Find your public IP: https://whatismyip.com
5. Share with friends: `your-public-ip:25565` (Java) or `your-public-ip:19132` (Bedrock)

## Performance Optimizations

This setup includes:

- **3GB RAM allocation** (optimal for Pi 4 8GB)
- **Aikar's JVM flags** (reduced garbage collection lag)
- **Paper async chunk loading** (multi-threaded)
- **Entity limits** (prevent mob-related lag)
- **CPU/Memory limits** (safety margins)

### Expected Performance

- **Players**: 10-15 smooth, up to 20 possible
- **TPS**: Consistent 20 (no lag)
- **View distance**: 10 chunks
- **Boot time**: ~60 seconds

### Monitoring

```bash
# In-game (as OP)
/tps
/spark tps

# System
free -h              # Memory
htop                 # CPU
vcgencmd measure_temp  # Temperature (keep under 80C)
```

## Backups

```bash
# Create backup
bash scripts/backup.sh

# Backups saved to ~/minecraft-backups/
```

## Troubleshooting

### Server Won't Start
- Check if already running: `screen -ls`
- Check logs: `sudo journalctl -u minecraft -n 50`
- Verify directory: `cd ~/minecraft-server && ls`

### Can't Connect
- Local network: Use Pi's local IP
- Bedrock: Check port is 19132, not 25565
- Firewalls: Ensure ports are open

### Bedrock Permissions Not Working
- Username must have dot prefix: `op .Gamertag`
- Spaces become underscores: `op .Cool_Player`

### Server Lag
- Reduce view-distance in `server.properties`: `view-distance=8`
- Check temperature: `vcgencmd measure_temp`
- Check logs for errors

## System Requirements

- **Hardware**: Raspberry Pi 4 (8GB recommended, 4GB minimum)
- **OS**: Raspberry Pi OS Lite (64-bit recommended)
- **Java**: OpenJDK 21
- **Storage**: 16GB+ SD card or USB SSD (recommended)

## Updating

### Automatic Updates (Recommended)

Set up automatic daily updates that only install when stable versions are available:

```bash
# Install cron job for automatic updates (runs at 4 AM daily)
sudo bash scripts/install-cron.sh

# Or install without auto-restart (manual restart required)
sudo bash scripts/install-cron.sh minecraft no
```

The auto-update script:
- Checks Paper, Geyser, Floodgate, and ViaVersion for new stable releases
- Only downloads when a new version is confirmed stable
- Creates backups before updating
- Logs all activity to `update.log`

### Manual Update Check

```bash
# Run update check manually
bash scripts/auto-update.sh

# Restart after updates
sudo systemctl restart minecraft
```

### Update Plugins Only

```bash
bash scripts/update-plugins.sh
sudo systemctl restart minecraft
```

### Managing Auto-Updates

```bash
# View update schedule
cat /etc/cron.d/minecraft-updates

# View update history
cat ~/minecraft-server/update.log

# Disable auto-updates
sudo rm /etc/cron.d/minecraft-updates
```

## License

This is a configuration repository for setting up Minecraft servers. Minecraft is a trademark of Mojang Studios.
