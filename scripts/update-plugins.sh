#!/bin/bash

# Update plugins to latest versions
# Run this from the minecraft-server directory

set -e

echo "=========================================="
echo "Updating Minecraft Server Plugins"
echo "=========================================="

PLUGINS_DIR="${1:-$HOME/minecraft-server/plugins}"

if [ ! -d "$PLUGINS_DIR" ]; then
    echo "Error: Plugins directory not found: $PLUGINS_DIR"
    echo "Usage: $0 [plugins-directory]"
    exit 1
fi

cd "$PLUGINS_DIR"

echo ""
echo "Updating plugins in: $PLUGINS_DIR"
echo ""

# Backup existing plugins
echo "[1/4] Backing up existing plugins..."
BACKUP_DIR="../plugins-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp *.jar "$BACKUP_DIR/" 2>/dev/null || true
echo "  - Backed up to: $BACKUP_DIR"

# Download Geyser-Spigot
echo ""
echo "[2/4] Downloading latest Geyser-Spigot..."
rm -f Geyser-Spigot.jar
wget -q --show-progress "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" -O Geyser-Spigot.jar

# Download Floodgate
echo ""
echo "[3/4] Downloading latest Floodgate..."
rm -f floodgate-spigot.jar
wget -q --show-progress "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" -O floodgate-spigot.jar

# Download ViaVersion
echo ""
echo "[4/4] Downloading latest ViaVersion..."
VIAVERSION_URL=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest" | grep "browser_download_url.*ViaVersion.*jar" | head -1 | cut -d '"' -f 4)
if [ -n "$VIAVERSION_URL" ]; then
    rm -f ViaVersion.jar
    wget -q --show-progress "$VIAVERSION_URL" -O ViaVersion.jar
else
    echo "  Warning: Could not fetch ViaVersion URL"
fi

echo ""
echo "=========================================="
echo "Plugins updated successfully!"
echo "=========================================="
echo ""
echo "Restart the server to apply updates:"
echo "  sudo systemctl restart minecraft"
echo ""
