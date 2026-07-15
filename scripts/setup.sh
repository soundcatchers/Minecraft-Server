#!/bin/bash

# Minecraft Server Setup Script for Raspberry Pi 4
# This script sets up a Paper Minecraft server with Geyser (Bedrock support)
# 
# IMPORTANT: Run this script as the minecraft user, but you will be prompted
# for sudo password when needed for system-level operations.

set -e

echo "=========================================="
echo "Minecraft Server Setup for Raspberry Pi 4"
echo "=========================================="
echo ""

# Check if running as root (shouldn't be)
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as the minecraft user, not root."
    echo "Usage: sudo su - minecraft && bash scripts/setup.sh"
    exit 1
fi

# Interactive setup options
echo "Setup Options:"
echo ""

# Storage location choice
echo "Where would you like to install the server?"
echo "  1) SD Card (/home/minecraft/minecraft-server) - Default"
echo "  2) USB SSD (/mnt/ssd/minecraft-server) - Recommended"
echo ""
read -p "Choose [1-2] (default: 1): " STORAGE_CHOICE
STORAGE_CHOICE=${STORAGE_CHOICE:-1}

if [ "$STORAGE_CHOICE" = "2" ]; then
    SERVER_DIR="/mnt/ssd/minecraft-server"
    BACKUP_DIR="/mnt/ssd/minecraft-backups"
    
    # Check if SSD is mounted
    if ! mountpoint -q /mnt/ssd 2>/dev/null; then
        echo ""
        echo "ERROR: SSD not mounted at /mnt/ssd"
        echo "Please format and mount your SSD first. See README for instructions."
        echo ""
        echo "Quick SSD setup (as your regular user with sudo):"
        echo "  sudo parted /dev/sda --script mklabel gpt mkpart primary ext4 0% 100%"
        echo "  sudo mkfs.ext4 /dev/sda1"
        echo "  sudo mkdir -p /mnt/ssd"
        echo "  sudo mount /dev/sda1 /mnt/ssd"
        echo "  # Then add to /etc/fstab for auto-mount"
        exit 1
    fi
    
    # Check if we can write to it (sudo may have been used to set permissions)
    if [ ! -w /mnt/ssd ]; then
        echo ""
        echo "Setting up SSD permissions (requires sudo)..."
        sudo mkdir -p "$SERVER_DIR"
        sudo chown $(whoami):$(whoami) "$SERVER_DIR"
        sudo mkdir -p "$BACKUP_DIR"
        sudo chown $(whoami):$(whoami) "$BACKUP_DIR"
    else
        mkdir -p "$SERVER_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    echo "  -> Installing to USB SSD"
else
    SERVER_DIR="$HOME/minecraft-server"
    BACKUP_DIR="$HOME/minecraft-backups"
    mkdir -p "$SERVER_DIR"
    mkdir -p "$BACKUP_DIR"
    echo "  -> Installing to SD Card"
fi

echo ""

# Auto-start option
read -p "Enable auto-start on boot? [Y/n]: " AUTOSTART_CHOICE
AUTOSTART_CHOICE=${AUTOSTART_CHOICE:-Y}

# Auto-update option
read -p "Enable daily automatic updates (4 AM)? [Y/n]: " AUTOUPDATE_CHOICE
AUTOUPDATE_CHOICE=${AUTOUPDATE_CHOICE:-Y}

echo ""
echo "=========================================="
echo "Starting Installation..."
echo "=========================================="

# Fetch latest Paper version
echo ""
echo "[1/8] Checking for required tools..."

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo "  - Installing jq (requires sudo)..."
    sudo apt install -y jq
fi

if ! command -v wget &> /dev/null; then
    echo "  - Installing wget (requires sudo)..."
    sudo apt install -y wget
fi

echo ""
echo "[2/8] Fetching latest Paper version..."

PAPER_VERSION=$(curl -s "https://api.papermc.io/v2/projects/paper" | jq -r '.versions[-1]')
PAPER_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds" | jq -r '.builds[-1].build')
PAPER_JAR="paper-${PAPER_VERSION}-${PAPER_BUILD}.jar"

echo "  - Latest version: $PAPER_VERSION (build $PAPER_BUILD)"

# Create server directory structure
echo ""
echo "[3/8] Creating server directories..."
mkdir -p "$SERVER_DIR/plugins"
mkdir -p "$SERVER_DIR/config"
mkdir -p "$SERVER_DIR/scripts"
mkdir -p "$SERVER_DIR/logs"
cd "$SERVER_DIR"

# Download Paper server
echo ""
echo "[4/8] Downloading Paper $PAPER_VERSION (build $PAPER_BUILD)..."
if [ ! -f "$PAPER_JAR" ]; then
    wget -q --show-progress "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${PAPER_BUILD}/downloads/${PAPER_JAR}" -O "$PAPER_JAR"
else
    echo "Paper JAR already exists, skipping download."
fi

# Accept EULA
echo ""
echo "[5/8] Accepting Minecraft EULA..."
echo "eula=true" > eula.txt

# Download plugins
echo ""
echo "[6/8] Downloading plugins..."
cd plugins

# Geyser-Spigot (allows Bedrock players to connect)
echo "  - Downloading Geyser-Spigot..."
wget -q --show-progress "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" -O Geyser-Spigot.jar

# Floodgate (Bedrock players don't need Java accounts)
echo "  - Downloading Floodgate..."
wget -q --show-progress "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" -O floodgate-spigot.jar

# ViaVersion (version compatibility)
echo "  - Downloading ViaVersion..."
VIAVERSION_URL=$(curl -s "https://hangar.papermc.io/api/v1/projects/ViaVersion/ViaVersion/versions?limit=1&channel=Release" | jq -r '.result[0].downloads.PAPER.downloadUrl // empty')
if [ -n "$VIAVERSION_URL" ]; then
    wget -q --show-progress "$VIAVERSION_URL" -O ViaVersion.jar
else
    # Fallback to GitHub
    VIAVERSION_URL=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest" | grep "browser_download_url.*ViaVersion.*jar" | head -1 | cut -d '"' -f 4)
    if [ -n "$VIAVERSION_URL" ]; then
        wget -q --show-progress "$VIAVERSION_URL" -O ViaVersion.jar
    else
        echo "    Warning: Could not fetch ViaVersion URL."
    fi
fi

cd "$SERVER_DIR"

# Copy configuration files
echo ""
echo "[7/8] Setting up configuration files..."

# server.properties
cat > server.properties << 'EOF'
# Performance optimizations
view-distance=10
simulation-distance=8
entity-broadcast-range-percentage=80
network-compression-threshold=256

# Gameplay settings
max-players=15
spawn-protection=16
difficulty=normal
gamemode=survival
pvp=true
allow-flight=true

# Security
white-list=false
enable-rcon=false

# Server identity
motd=Raspberry Pi Minecraft Server
server-port=25565
EOF

echo "  - Created server.properties"

# Create config directory
mkdir -p config

# paper-global.yml
cat > config/paper-global.yml << 'EOF'
chunk-loading-advanced:
  auto-config-send-distance: true
  player-max-concurrent-loads: 4.0
  player-max-chunk-load-rate: 100.0

chunk-loading-basic:
  player-max-chunk-load-rate: 100.0

async-chunks:
  threads: 3

packet-limiter:
  kick-message: '&cSent too many packets'
  limits:
    all:
      interval: 7.0
      max-packet-rate: 500.0
    PacketPlayInAutoRecipe:
      interval: 4.0
      max-packet-rate: 5.0
      action: DROP

unsupported-settings:
  allow-permanent-block-break-exploits: false
  allow-piston-duplication: false
EOF

echo "  - Created config/paper-global.yml"

# paper-world-defaults.yml
cat > config/paper-world-defaults.yml << 'EOF'
entities:
  spawning:
    all-chunks-are-slime-chunks: false
    alt-item-despawn-rate:
      enabled: true
      items:
        cobblestone: 300
        netherrack: 300
        sand: 300
        gravel: 300
        dirt: 300
    count-all-mobs-for-spawning: false
    creative-arrow-despawn-rate: 300
    despawn-ranges:
      ambient:
        hard: 72
        soft: 30
      axolotls:
        hard: 72
        soft: 30
      creature:
        hard: 72
        soft: 30
      misc:
        hard: 72
        soft: 30
      monster:
        hard: 72
        soft: 30
      underground_water_creature:
        hard: 72
        soft: 30
      water_ambient:
        hard: 72
        soft: 30
      water_creature:
        hard: 72
        soft: 30
    monsters-spawn-limit: 60
    animals-spawn-limit: 10
    water-animals-spawn-limit: 5
    ambient-spawns-limit: 15

misc:
  update-pathfinding-on-block-update: true
  max-leash-distance: 10.0
  redstone-implementation: VANILLA

chunks:
  auto-save-interval: 6000
  delay-chunk-unloads-by: 10s
  entity-per-chunk-save-limit:
    experience_orb: 16
    snowball: 16
    ender_pearl: 16
    arrow: 16
  fixed-chunk-inhabited-time: -1
  max-auto-save-chunks-per-tick: 8
  prevent-moving-into-unloaded-chunks: true

tick-rates:
  behavior:
    villager:
      validatenearbypoi: 60
  container-update: 1
  grass-spread: 4
  mob-spawner: 2
  sensor:
    villager:
      secondarypoisensor: 80
      nearestbedsensor: 80
EOF

echo "  - Created config/paper-world-defaults.yml"

# Create backup script
cat > scripts/backup.sh << SCRIPT
#!/bin/bash
# Manual backup script for Minecraft server

SERVER_DIR="$SERVER_DIR"
BACKUP_DIR="$BACKUP_DIR"

mkdir -p "\$BACKUP_DIR"
BACKUP_NAME="manual-backup-\$(date +%Y%m%d-%H%M%S).tar.gz"

echo "Creating backup: \$BACKUP_NAME"
tar -czf "\$BACKUP_DIR/\$BACKUP_NAME" -C "\$SERVER_DIR" world world_nether world_the_end plugins/*.jar server.properties ops.json whitelist.json 2>/dev/null

echo "Backup saved to: \$BACKUP_DIR/\$BACKUP_NAME"
ls -lh "\$BACKUP_DIR/\$BACKUP_NAME"
SCRIPT

chmod +x scripts/backup.sh
echo "  - Created scripts/backup.sh"

# ops.json and whitelist.json (empty initially)
echo "[]" > ops.json
echo "[]" > whitelist.json
echo "  - Created ops.json and whitelist.json"

# Install systemd service if requested
echo ""
echo "[8/8] Configuring auto-start and updates..."

if [[ "$AUTOSTART_CHOICE" =~ ^[Yy] ]]; then
    echo "  - Installing systemd service (requires sudo)..."
    
    # Create service file
    sudo tee /etc/systemd/system/minecraft.service > /dev/null << EOF
[Unit]
Description=Minecraft Server (Optimized for Pi 4 - 8GB)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$SERVER_DIR

ExecStart=/usr/bin/java -Xms3G -Xmx3G \\
  -XX:+AlwaysPreTouch \\
  -XX:+DisableExplicitGC \\
  -XX:+ParallelRefProcEnabled \\
  -XX:+PerfDisableSharedMem \\
  -XX:+UnlockExperimentalVMOptions \\
  -XX:+UseG1GC \\
  -XX:G1HeapRegionSize=8M \\
  -XX:G1HeapWastePercent=5 \\
  -XX:G1MaxNewSizePercent=40 \\
  -XX:G1MixedGCCountTarget=4 \\
  -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1NewSizePercent=30 \\
  -XX:G1ReservePercent=20 \\
  -XX:InitiatingHeapOccupancyPercent=15 \\
  -XX:MaxGCPauseMillis=200 \\
  -XX:MaxTenuringThreshold=1 \\
  -XX:SurvivorRatio=32 \\
  -Dusing.aikars.flags=https://mcflags.emc.gs \\
  -Daikars.new.flags=true \\
  -jar $PAPER_JAR nogui

StandardInput=null
StandardOutput=journal
StandardError=journal

SuccessExitStatus=0 1
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=120

Restart=on-failure
RestartSec=15

CPUQuota=250%
MemoryMax=3.5G
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable minecraft
    echo "  - Auto-start enabled"
fi

if [[ "$AUTOUPDATE_CHOICE" =~ ^[Yy] ]]; then
    echo "  - Setting up daily auto-updates..."
    
    # Create the auto-update script
    cat > scripts/auto-update.sh << 'AUTOSCRIPT'
#!/bin/bash
# Auto-update script for Minecraft Paper server
# Run via: sudo bash /path/to/auto-update.sh

AUTOSCRIPT

    # Append the rest with variable substitution
    cat >> scripts/auto-update.sh << AUTOSCRIPT
SERVER_DIR="$SERVER_DIR"
BACKUP_DIR="$BACKUP_DIR"
LOG_FILE="\$SERVER_DIR/logs/auto-update.log"
AUTOSCRIPT

    cat >> scripts/auto-update.sh << 'AUTOSCRIPT'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Starting auto-update check ==="

# Create backup before updating
mkdir -p "$BACKUP_DIR"
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S).tar.gz"
log "Creating backup: $BACKUP_NAME"
tar -czf "$BACKUP_DIR/$BACKUP_NAME" -C "$SERVER_DIR" world world_nether world_the_end 2>/dev/null || true

# Check Paper for updates
CURRENT_JAR=$(ls "$SERVER_DIR"/paper-*.jar 2>/dev/null | grep -v '.old' | grep -v '.new' | head -1)
CURRENT_PAPER=$(echo "$CURRENT_JAR" | grep -oP 'paper-\K[0-9.]+-[0-9]+')
LATEST_VERSION=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions[-1]')
LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$LATEST_VERSION/builds" | jq -r '.builds[-1].build')

UPDATES_APPLIED=false

if [ -n "$LATEST_VERSION" ] && [ -n "$LATEST_BUILD" ]; then
    LATEST_PAPER="$LATEST_VERSION-$LATEST_BUILD"
    if [ "$CURRENT_PAPER" != "$LATEST_PAPER" ]; then
        log "Updating Paper: $CURRENT_PAPER -> $LATEST_PAPER"
        
        # Download to temp file first
        curl -o "$SERVER_DIR/paper-$LATEST_PAPER.jar.new" \
            "https://api.papermc.io/v2/projects/paper/versions/$LATEST_VERSION/builds/$LATEST_BUILD/downloads/paper-$LATEST_VERSION-$LATEST_BUILD.jar" 2>/dev/null
        
        # Verify download succeeded (file exists and is > 1MB)
        if [ -f "$SERVER_DIR/paper-$LATEST_PAPER.jar.new" ] && [ $(stat -f%z "$SERVER_DIR/paper-$LATEST_PAPER.jar.new" 2>/dev/null || stat -c%s "$SERVER_DIR/paper-$LATEST_PAPER.jar.new") -gt 1000000 ]; then
            mv "$SERVER_DIR/paper-$LATEST_PAPER.jar.new" "$SERVER_DIR/paper-$LATEST_PAPER.jar"
            
            # Update systemd service to use new jar
            sed -i "s/paper-.*\.jar/paper-$LATEST_PAPER.jar/" /etc/systemd/system/minecraft.service
            systemctl daemon-reload
            log "Updated systemd service to use paper-$LATEST_PAPER.jar"
            
            # Remove old jars (keep current)
            find "$SERVER_DIR" -name "paper-*.jar" ! -name "paper-$LATEST_PAPER.jar" -delete 2>/dev/null
            UPDATES_APPLIED=true
        else
            log "Download failed or incomplete, keeping current version"
            rm -f "$SERVER_DIR/paper-$LATEST_PAPER.jar.new"
        fi
    else
        log "Paper is up to date: $CURRENT_PAPER"
    fi
fi

# Update Geyser
log "Checking Geyser..."
GEYSER_URL=$(curl -s "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest" | jq -r '.downloads.spigot.download_url // empty')
if [ -n "$GEYSER_URL" ]; then
    curl -L -o "$SERVER_DIR/plugins/Geyser-Spigot.jar.new" "https://download.geysermc.org$GEYSER_URL" 2>/dev/null
    if [ -s "$SERVER_DIR/plugins/Geyser-Spigot.jar.new" ]; then
        mv "$SERVER_DIR/plugins/Geyser-Spigot.jar.new" "$SERVER_DIR/plugins/Geyser-Spigot.jar"
        log "Geyser updated"
        UPDATES_APPLIED=true
    else
        rm -f "$SERVER_DIR/plugins/Geyser-Spigot.jar.new"
    fi
fi

# Update Floodgate
log "Checking Floodgate..."
FLOODGATE_URL=$(curl -s "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest" | jq -r '.downloads.spigot.download_url // empty')
if [ -n "$FLOODGATE_URL" ]; then
    curl -L -o "$SERVER_DIR/plugins/floodgate-spigot.jar.new" "https://download.geysermc.org$FLOODGATE_URL" 2>/dev/null
    if [ -s "$SERVER_DIR/plugins/floodgate-spigot.jar.new" ]; then
        mv "$SERVER_DIR/plugins/floodgate-spigot.jar.new" "$SERVER_DIR/plugins/floodgate-spigot.jar"
        log "Floodgate updated"
        UPDATES_APPLIED=true
    else
        rm -f "$SERVER_DIR/plugins/floodgate-spigot.jar.new"
    fi
fi

# Update ViaVersion
log "Checking ViaVersion..."
VIA_URL=$(curl -s "https://hangar.papermc.io/api/v1/projects/ViaVersion/ViaVersion/versions?limit=1&channel=Release" | jq -r '.result[0].downloads.PAPER.downloadUrl // empty')
if [ -n "$VIA_URL" ]; then
    curl -L -o "$SERVER_DIR/plugins/ViaVersion.jar.new" "$VIA_URL" 2>/dev/null
    if [ -s "$SERVER_DIR/plugins/ViaVersion.jar.new" ]; then
        mv "$SERVER_DIR/plugins/ViaVersion.jar.new" "$SERVER_DIR/plugins/ViaVersion.jar"
        log "ViaVersion updated"
        UPDATES_APPLIED=true
    else
        rm -f "$SERVER_DIR/plugins/ViaVersion.jar.new"
    fi
fi

# Clean old backups (keep last 7)
ls -t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null

log "=== Auto-update complete ==="

# Only restart if updates were applied
if [ "$UPDATES_APPLIED" = true ]; then
    systemctl restart minecraft
    log "Server restarted with updates"
else
    log "No updates needed, server not restarted"
fi
AUTOSCRIPT

    chmod +x scripts/auto-update.sh
    
    # Create systemd timer for auto-updates (runs as root)
    sudo tee /etc/systemd/system/minecraft-update.service > /dev/null << EOF
[Unit]
Description=Minecraft Server Auto-Update
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $SERVER_DIR/scripts/auto-update.sh
User=root
EOF

    sudo tee /etc/systemd/system/minecraft-update.timer > /dev/null << 'EOF'
[Unit]
Description=Daily Minecraft Server Auto-Update

[Timer]
OnCalendar=*-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable minecraft-update.timer
    sudo systemctl start minecraft-update.timer
    
    echo "  - Auto-updates enabled (runs daily at 4 AM)"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Server installed to: $SERVER_DIR"
echo ""

if [[ "$AUTOSTART_CHOICE" =~ ^[Yy] ]]; then
    echo "Start the server:"
    echo "  sudo systemctl start minecraft"
    echo ""
    echo "Management commands:"
    echo "  sudo systemctl status minecraft   # Check status"
    echo "  sudo systemctl stop minecraft     # Stop server"
    echo "  sudo systemctl restart minecraft  # Restart server"
    echo "  sudo journalctl -u minecraft -f   # View logs"
else
    echo "Start the server manually:"
    echo "  cd $SERVER_DIR"
    echo "  java -Xms3G -Xmx3G -jar $PAPER_JAR nogui"
fi

echo ""
echo "Connect to your server:"
echo "  - Java Edition: <your-pi-ip>:25565"
echo "  - Bedrock Edition: <your-pi-ip>:19132"
echo ""
echo "=========================================="
