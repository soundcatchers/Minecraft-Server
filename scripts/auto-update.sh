#!/bin/bash

# Automatic update script for Minecraft Paper server and plugins
# Designed to run via systemd timer as root for reliable updates
# Creates backups before updating and only restarts if updates were applied

set -e

SERVER_DIR="/mnt/ssd/minecraft-server"
BACKUP_DIR="/mnt/ssd/minecraft-backups"
LOG_FILE="$SERVER_DIR/logs/auto-update.log"
VERSION_FILE="$SERVER_DIR/.plugin-versions"
UPDATES_APPLIED=false

mkdir -p "$SERVER_DIR/logs"
mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

create_backup() {
    log "Creating world backup before updates..."
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/backup-$TIMESTAMP.tar.gz"
    
    if [ -d "$SERVER_DIR/world" ]; then
        cd "$SERVER_DIR"
        tar -czf "$BACKUP_FILE" world world_nether world_the_end 2>/dev/null || tar -czf "$BACKUP_FILE" world 2>/dev/null || true
        log "  Backup created: $BACKUP_FILE"
        
        # Keep only last 7 backups
        ls -t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null || true
    else
        log "  No world data to backup (new server)"
    fi
}

update_paper() {
    log "Checking for Paper updates..."
    
    CURRENT_JAR=$(ls "$SERVER_DIR"/paper-*.jar 2>/dev/null | grep -v '.new' | grep -v '.backup' | grep -v '.old' | head -1)
    if [ -z "$CURRENT_JAR" ]; then
        log "  No Paper jar found"
        return 1
    fi
    
    CURRENT_VERSION=$(basename "$CURRENT_JAR" | sed 's/paper-\(.*\)\.jar/\1/')
    log "  Current version: $CURRENT_VERSION"
    
    # Get latest version info
    LATEST_MC_VERSION=$(curl -s "https://api.papermc.io/v2/projects/paper" | jq -r '.versions[-1]')
    if [ -z "$LATEST_MC_VERSION" ] || [ "$LATEST_MC_VERSION" = "null" ]; then
        log "  Could not fetch latest MC version"
        return 1
    fi
    
    LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$LATEST_MC_VERSION/builds" | jq -r '.builds[-1].build')
    if [ -z "$LATEST_BUILD" ] || [ "$LATEST_BUILD" = "null" ]; then
        log "  Could not fetch latest build"
        return 1
    fi
    
    LATEST_VERSION="$LATEST_MC_VERSION-$LATEST_BUILD"
    log "  Latest version: $LATEST_VERSION"
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        log "  Paper is up to date"
        return 0
    fi
    
    log "  Downloading Paper $LATEST_VERSION..."
    DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/$LATEST_MC_VERSION/builds/$LATEST_BUILD/downloads/paper-$LATEST_MC_VERSION-$LATEST_BUILD.jar"
    
    curl -s -o "$SERVER_DIR/paper-$LATEST_VERSION.jar.new" "$DOWNLOAD_URL"
    
    # Verify download (must be > 1MB)
    FILESIZE=$(stat -c%s "$SERVER_DIR/paper-$LATEST_VERSION.jar.new" 2>/dev/null || echo "0")
    if [ "$FILESIZE" -lt 1000000 ]; then
        log "  Download failed or incomplete (${FILESIZE} bytes)"
        rm -f "$SERVER_DIR/paper-$LATEST_VERSION.jar.new"
        return 1
    fi
    
    # Move new jar into place
    mv "$SERVER_DIR/paper-$LATEST_VERSION.jar.new" "$SERVER_DIR/paper-$LATEST_VERSION.jar"
    
    # Update systemd service to use new jar
    if [ -f /etc/systemd/system/minecraft.service ]; then
        sed -i "s/paper-.*\.jar/paper-$LATEST_VERSION.jar/" /etc/systemd/system/minecraft.service
        systemctl daemon-reload
        log "  Updated systemd service to use paper-$LATEST_VERSION.jar"
    fi
    
    # Remove old jars
    find "$SERVER_DIR" -name "paper-*.jar" ! -name "paper-$LATEST_VERSION.jar" -delete 2>/dev/null || true
    
    log "  Paper updated to $LATEST_VERSION"
    UPDATES_APPLIED=true
    return 0
}

update_geyser() {
    log "Checking for Geyser updates..."
    
    CURRENT_BUILD=$(grep "^geyser=" "$VERSION_FILE" 2>/dev/null | cut -d= -f2)
    
    # Get latest build from redirect header
    REDIRECT=$(curl -sI "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" | grep -i "^location:" | tr -d '\r')
    LATEST_BUILD=$(echo "$REDIRECT" | grep -oP 'builds/\K[0-9]+')
    
    if [ -z "$LATEST_BUILD" ]; then
        log "  Could not fetch latest Geyser build"
        return 1
    fi
    
    log "  Current: ${CURRENT_BUILD:-unknown}, Latest: $LATEST_BUILD"
    
    if [ "$CURRENT_BUILD" = "$LATEST_BUILD" ]; then
        log "  Geyser is up to date"
        return 0
    fi
    
    curl -s -L -o "$SERVER_DIR/plugins/Geyser-Spigot.jar.new" \
        "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
    
    FILESIZE=$(stat -c%s "$SERVER_DIR/plugins/Geyser-Spigot.jar.new" 2>/dev/null || echo "0")
    if [ "$FILESIZE" -gt 100000 ]; then
        mv "$SERVER_DIR/plugins/Geyser-Spigot.jar.new" "$SERVER_DIR/plugins/Geyser-Spigot.jar"
        
        # Update version tracking
        touch "$VERSION_FILE"
        grep -v "^geyser=" "$VERSION_FILE" > "$VERSION_FILE.tmp" 2>/dev/null || true
        echo "geyser=$LATEST_BUILD" >> "$VERSION_FILE.tmp"
        mv "$VERSION_FILE.tmp" "$VERSION_FILE"
        
        log "  Geyser updated to build $LATEST_BUILD"
        UPDATES_APPLIED=true
    else
        rm -f "$SERVER_DIR/plugins/Geyser-Spigot.jar.new"
        log "  Geyser download failed"
    fi
}

update_floodgate() {
    log "Checking for Floodgate updates..."
    
    CURRENT_BUILD=$(grep "^floodgate=" "$VERSION_FILE" 2>/dev/null | cut -d= -f2)
    
    # Get latest build from redirect header
    REDIRECT=$(curl -sI "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" | grep -i "^location:" | tr -d '\r')
    LATEST_BUILD=$(echo "$REDIRECT" | grep -oP 'builds/\K[0-9]+')
    
    if [ -z "$LATEST_BUILD" ]; then
        log "  Could not fetch latest Floodgate build"
        return 1
    fi
    
    log "  Current: ${CURRENT_BUILD:-unknown}, Latest: $LATEST_BUILD"
    
    if [ "$CURRENT_BUILD" = "$LATEST_BUILD" ]; then
        log "  Floodgate is up to date"
        return 0
    fi
    
    curl -s -L -o "$SERVER_DIR/plugins/floodgate-spigot.jar.new" \
        "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
    
    FILESIZE=$(stat -c%s "$SERVER_DIR/plugins/floodgate-spigot.jar.new" 2>/dev/null || echo "0")
    if [ "$FILESIZE" -gt 100000 ]; then
        mv "$SERVER_DIR/plugins/floodgate-spigot.jar.new" "$SERVER_DIR/plugins/floodgate-spigot.jar"
        
        touch "$VERSION_FILE"
        grep -v "^floodgate=" "$VERSION_FILE" > "$VERSION_FILE.tmp" 2>/dev/null || true
        echo "floodgate=$LATEST_BUILD" >> "$VERSION_FILE.tmp"
        mv "$VERSION_FILE.tmp" "$VERSION_FILE"
        
        log "  Floodgate updated to build $LATEST_BUILD"
        UPDATES_APPLIED=true
    else
        rm -f "$SERVER_DIR/plugins/floodgate-spigot.jar.new"
        log "  Floodgate download failed"
    fi
}

update_viaversion() {
    log "Checking for ViaVersion updates..."
    
    CURRENT_VERSION=$(grep "^viaversion=" "$VERSION_FILE" 2>/dev/null | cut -d= -f2)
    
    RELEASE_INFO=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest")
    LATEST_VERSION=$(echo "$RELEASE_INFO" | jq -r '.tag_name // empty')
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name | endswith(".jar")) | select(.name | contains("ViaVersion")) | .browser_download_url' | head -1)
    
    if [ -z "$LATEST_VERSION" ] || [ -z "$DOWNLOAD_URL" ]; then
        log "  Could not fetch latest ViaVersion release"
        return 1
    fi
    
    log "  Current: ${CURRENT_VERSION:-unknown}, Latest: $LATEST_VERSION"
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        log "  ViaVersion is up to date"
        return 0
    fi
    
    curl -s -L -o "$SERVER_DIR/plugins/ViaVersion.jar.new" "$DOWNLOAD_URL"
    
    FILESIZE=$(stat -c%s "$SERVER_DIR/plugins/ViaVersion.jar.new" 2>/dev/null || echo "0")
    if [ "$FILESIZE" -gt 100000 ]; then
        mv "$SERVER_DIR/plugins/ViaVersion.jar.new" "$SERVER_DIR/plugins/ViaVersion.jar"
        
        touch "$VERSION_FILE"
        grep -v "^viaversion=" "$VERSION_FILE" > "$VERSION_FILE.tmp" 2>/dev/null || true
        echo "viaversion=$LATEST_VERSION" >> "$VERSION_FILE.tmp"
        mv "$VERSION_FILE.tmp" "$VERSION_FILE"
        
        log "  ViaVersion updated to $LATEST_VERSION"
        UPDATES_APPLIED=true
    else
        rm -f "$SERVER_DIR/plugins/ViaVersion.jar.new"
        log "  ViaVersion download failed"
    fi
}

main() {
    log "=========================================="
    log "Minecraft Auto-Update Check"
    log "Server: $SERVER_DIR"
    log "=========================================="
    
    create_backup
    
    update_paper || true
    update_geyser || true
    update_floodgate || true
    update_viaversion || true
    
    log ""
    log "=========================================="
    
    if [ "$UPDATES_APPLIED" = true ]; then
        log "Updates were applied - restarting server..."
        systemctl restart minecraft
        log "Server restarted"
    else
        log "All software is up to date - no restart needed"
    fi
    
    log "=========================================="
}

main "$@"
