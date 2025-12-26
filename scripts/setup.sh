#!/bin/bash

# Minecraft Server Setup Script for Raspberry Pi 4
# This script sets up a Paper Minecraft server with Geyser (Bedrock support)
# Run this as the minecraft user on your Raspberry Pi

set -e

echo "=========================================="
echo "Minecraft Server Setup for Raspberry Pi 4"
echo "=========================================="

# Configuration
SERVER_DIR="$HOME/minecraft-server"
PAPER_VERSION="1.21.10"
PAPER_BUILD="129"
PAPER_JAR="paper-${PAPER_VERSION}-${PAPER_BUILD}.jar"

# Create server directory
echo ""
echo "[1/7] Creating server directory..."
mkdir -p "$SERVER_DIR"
mkdir -p "$SERVER_DIR/plugins"
mkdir -p "$SERVER_DIR/config"
cd "$SERVER_DIR"

# Download Paper server
echo ""
echo "[2/7] Downloading Paper $PAPER_VERSION (build $PAPER_BUILD)..."
if [ ! -f "$PAPER_JAR" ]; then
    wget -q --show-progress "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${PAPER_BUILD}/downloads/${PAPER_JAR}" -O "$PAPER_JAR"
else
    echo "Paper JAR already exists, skipping download."
fi

# Accept EULA
echo ""
echo "[3/7] Accepting Minecraft EULA..."
echo "eula=true" > eula.txt

# Download plugins
echo ""
echo "[4/7] Downloading plugins..."
cd plugins

# Geyser-Spigot (allows Bedrock players to connect)
if [ ! -f "Geyser-Spigot.jar" ]; then
    echo "  - Downloading Geyser-Spigot..."
    wget -q --show-progress "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" -O Geyser-Spigot.jar
else
    echo "  - Geyser-Spigot already exists"
fi

# Floodgate (Bedrock players don't need Java accounts)
if [ ! -f "floodgate-spigot.jar" ]; then
    echo "  - Downloading Floodgate..."
    wget -q --show-progress "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" -O floodgate-spigot.jar
else
    echo "  - Floodgate already exists"
fi

# ViaVersion (version compatibility)
echo "  - Downloading ViaVersion..."
VIAVERSION_URL=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest" | grep "browser_download_url.*ViaVersion.*jar" | head -1 | cut -d '"' -f 4)
if [ -n "$VIAVERSION_URL" ]; then
    wget -q --show-progress "$VIAVERSION_URL" -O ViaVersion.jar
else
    echo "    Warning: Could not fetch ViaVersion URL. You may need to download manually."
fi

cd "$SERVER_DIR"

# Copy configuration files
echo ""
echo "[5/7] Setting up configuration files..."

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

# Server identity
motd=Andy's Optimized Minecraft Server
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

  behavior:
    door-breaking-difficulty:
      husk: []
      zombie: []
      zombie_villager: []
      zombified_piglin: []
    ender-dragons-death-always-places-dragon-egg: false
    mobs-can-always-pick-up-loot:
      skeletons: false
      zombies: false
    nerf-pigmen-from-nether-portals: false
    pillager-patrols:
      disable: false
      spawn-chance: 0.2
      spawn-delay:
        per-player: false
        ticks: 12000
      start:
        per-player: false
        day: 5

  spawning:
    fire-tick-delay: 30
    max-entity-collisions: 4
    should-remove-dragon: false

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

# ops.json (empty initially)
echo "[]" > ops.json
echo "  - Created ops.json"

echo ""
echo "[6/7] Setting file permissions..."
chmod +x "$PAPER_JAR" 2>/dev/null || true

echo ""
echo "[7/7] Setup complete!"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Run the systemd setup script (requires sudo):"
echo "   sudo bash scripts/install-systemd.sh"
echo ""
echo "2. Or start the server manually:"
echo "   cd $SERVER_DIR"
echo "   java -Xms3G -Xmx3G -jar $PAPER_JAR nogui"
echo ""
echo "3. Connect to your server:"
echo "   - Java Edition: <your-pi-ip>:25565"
echo "   - Bedrock Edition: <your-pi-ip>:19132"
echo ""
echo "=========================================="
