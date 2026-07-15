#!/bin/bash

# Install systemd service for Minecraft server
# Run this with sudo: sudo bash install-systemd.sh

set -e

echo "=========================================="
echo "Installing Minecraft systemd Service"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run with sudo"
    echo "Usage: sudo bash $0"
    exit 1
fi

# Prompt for configuration
echo ""
echo "Server location:"
echo "  1) SD Card (/home/minecraft/minecraft-server)"
echo "  2) USB SSD (/mnt/ssd/minecraft-server)"
read -p "Choose [1-2] (default: 1): " STORAGE_CHOICE
STORAGE_CHOICE=${STORAGE_CHOICE:-1}

if [ "$STORAGE_CHOICE" = "2" ]; then
    SERVER_DIR="/mnt/ssd/minecraft-server"
else
    SERVER_DIR="/home/minecraft/minecraft-server"
fi

# Find Paper JAR
PAPER_JAR=$(ls "$SERVER_DIR"/paper-*.jar 2>/dev/null | grep -v '.old' | head -1 | xargs basename 2>/dev/null)

if [ -z "$PAPER_JAR" ]; then
    echo "Error: No Paper JAR found in $SERVER_DIR"
    echo "Please run setup.sh first."
    exit 1
fi

echo ""
echo "Using: $SERVER_DIR/$PAPER_JAR"

# Configuration
SERVICE_FILE="/etc/systemd/system/minecraft.service"
MINECRAFT_USER="minecraft"

echo ""
echo "[1/4] Creating systemd service file..."

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Minecraft Server (Optimized for Pi 4 - 8GB)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$MINECRAFT_USER
Group=$MINECRAFT_USER
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

echo "  - Created $SERVICE_FILE"

echo ""
echo "[2/4] Reloading systemd..."
systemctl daemon-reload

echo ""
echo "[3/4] Enabling service for auto-start..."
systemctl enable minecraft

echo ""
echo "[4/4] Service installed!"
echo ""
echo "=========================================="
echo "Management Commands:"
echo "=========================================="
echo ""
echo "Start server:    sudo systemctl start minecraft"
echo "Stop server:     sudo systemctl stop minecraft"
echo "Restart server:  sudo systemctl restart minecraft"
echo "Check status:    sudo systemctl status minecraft"
echo "View logs:       sudo journalctl -u minecraft -f"
echo ""
echo "Disable auto-start: sudo systemctl disable minecraft"
echo "Enable auto-start:  sudo systemctl enable minecraft"
echo ""
echo "=========================================="
echo ""
echo "To start the server now, run:"
echo "  sudo systemctl start minecraft"
echo ""
