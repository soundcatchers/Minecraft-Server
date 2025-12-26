#!/bin/bash

# Automatic update script for Minecraft Paper server and plugins
# Checks for stable versions and only updates when new versions are available
# Can be scheduled via cron for fully automatic updates

set -e

SERVER_DIR="${1:-$HOME/minecraft-server}"
LOG_FILE="$SERVER_DIR/update.log"
VERSION_FILE="$SERVER_DIR/.versions"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_paper_update() {
    log "Checking for Paper updates..."
    
    CURRENT_JAR=$(ls "$SERVER_DIR"/paper-*.jar 2>/dev/null | head -1)
    if [ -z "$CURRENT_JAR" ]; then
        log "  No Paper jar found"
        return 1
    fi
    
    CURRENT_VERSION=$(basename "$CURRENT_JAR" | sed 's/paper-\(.*\)\.jar/\1/')
    log "  Current version: $CURRENT_VERSION"
    
    LATEST_MC_VERSION=$(curl -s "https://api.papermc.io/v2/projects/paper" | grep -oP '"versions":\[.*?\]' | grep -oP '"\d+\.\d+(\.\d+)?"' | tr -d '"' | tail -1)
    
    if [ -z "$LATEST_MC_VERSION" ]; then
        log "  Could not fetch latest MC version"
        return 1
    fi
    
    LATEST_BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$LATEST_MC_VERSION/builds" | grep -oP '"build":\d+' | grep -oP '\d+' | tail -1)
    
    if [ -z "$LATEST_BUILD" ]; then
        log "  Could not fetch latest build"
        return 1
    fi
    
    LATEST_VERSION="$LATEST_MC_VERSION-$LATEST_BUILD"
    log "  Latest stable version: $LATEST_VERSION"
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        log "  Paper is up to date"
        return 1
    fi
    
    log "  New version available: $LATEST_VERSION"
    echo "$LATEST_MC_VERSION:$LATEST_BUILD"
    return 0
}

update_paper() {
    local MC_VERSION="$1"
    local BUILD="$2"
    
    log "Downloading Paper $MC_VERSION-$BUILD..."
    
    DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/$MC_VERSION/builds/$BUILD/downloads/paper-$MC_VERSION-$BUILD.jar"
    
    cd "$SERVER_DIR"
    
    rm -f paper-*.jar.backup
    for jar in paper-*.jar; do
        [ -f "$jar" ] && mv "$jar" "$jar.backup"
    done
    
    if wget -q "$DOWNLOAD_URL" -O "paper-$MC_VERSION-$BUILD.jar"; then
        rm -f paper-*.jar.backup
        log "  Paper updated to $MC_VERSION-$BUILD"
        return 0
    else
        for backup in paper-*.jar.backup; do
            [ -f "$backup" ] && mv "$backup" "${backup%.backup}"
        done
        log "  Download failed, restored backup"
        return 1
    fi
}

check_geyser_update() {
    log "Checking for Geyser updates..."
    
    CURRENT_BUILD=$(grep "^geyser=" "$VERSION_FILE" 2>/dev/null | cut -d= -f2)
    
    LATEST_BUILD=$(curl -s "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest" | grep -oP '"build":\d+' | grep -oP '\d+' | head -1)
    
    if [ -z "$LATEST_BUILD" ]; then
        log "  Could not fetch latest Geyser build"
        return 1
    fi
    
    log "  Current: ${CURRENT_BUILD:-unknown}, Latest: $LATEST_BUILD"
    
    if [ "$CURRENT_BUILD" = "$LATEST_BUILD" ]; then
        log "  Geyser is up to date"
        return 1
    fi
    
    echo "$LATEST_BUILD"
    return 0
}

check_floodgate_update() {
    log "Checking for Floodgate updates..."
    
    CURRENT_BUILD=$(grep "^floodgate=" "$VERSION_FILE" 2>/dev/null | cut -d= -f2)
    
    LATEST_BUILD=$(curl -s "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest" | grep -oP '"build":\d+' | grep -oP '\d+' | head -1)
    
    if [ -z "$LATEST_BUILD" ]; then
        log "  Could not fetch latest Floodgate build"
        return 1
    fi
    
    log "  Current: ${CURRENT_BUILD:-unknown}, Latest: $LATEST_BUILD"
    
    if [ "$CURRENT_BUILD" = "$LATEST_BUILD" ]; then
        log "  Floodgate is up to date"
        return 1
    fi
    
    echo "$LATEST_BUILD"
    return 0
}

check_viaversion_update() {
    log "Checking for ViaVersion updates..."
    
    CURRENT_VERSION=$(grep "^viaversion=" "$VERSION_FILE" 2>/dev/null | cut -d= -f2)
    
    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest")
    LATEST_VERSION=$(echo "$LATEST_RELEASE" | grep -oP '"tag_name":\s*"\K[^"]+')
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep -oP '"browser_download_url":\s*"[^"]*ViaVersion-[^"]*\.jar"' | head -1 | grep -oP 'https://[^"]+')
    
    if [ -z "$LATEST_VERSION" ]; then
        log "  Could not fetch latest ViaVersion release"
        return 1
    fi
    
    log "  Current: ${CURRENT_VERSION:-unknown}, Latest: $LATEST_VERSION"
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        log "  ViaVersion is up to date"
        return 1
    fi
    
    echo "$LATEST_VERSION:$DOWNLOAD_URL"
    return 0
}

update_plugin() {
    local NAME="$1"
    local URL="$2"
    local OUTPUT="$3"
    local VERSION_KEY="$4"
    local VERSION_VALUE="$5"
    
    log "Updating $NAME..."
    
    PLUGINS_DIR="$SERVER_DIR/plugins"
    cd "$PLUGINS_DIR"
    
    [ -f "$OUTPUT" ] && mv "$OUTPUT" "$OUTPUT.backup"
    
    if wget -q "$URL" -O "$OUTPUT"; then
        rm -f "$OUTPUT.backup"
        
        touch "$VERSION_FILE"
        grep -v "^$VERSION_KEY=" "$VERSION_FILE" > "$VERSION_FILE.tmp" 2>/dev/null || true
        echo "$VERSION_KEY=$VERSION_VALUE" >> "$VERSION_FILE.tmp"
        mv "$VERSION_FILE.tmp" "$VERSION_FILE"
        
        log "  $NAME updated to $VERSION_VALUE"
        return 0
    else
        [ -f "$OUTPUT.backup" ] && mv "$OUTPUT.backup" "$OUTPUT"
        log "  $NAME update failed, restored backup"
        return 1
    fi
}

create_world_backup() {
    log "Creating world backup before updates..."
    
    BACKUP_DIR="$SERVER_DIR/../minecraft-backups"
    mkdir -p "$BACKUP_DIR"
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/pre-update-$TIMESTAMP.tar.gz"
    
    if [ -d "$SERVER_DIR/world" ]; then
        cd "$SERVER_DIR"
        tar -czf "$BACKUP_FILE" world world_nether world_the_end 2>/dev/null || tar -czf "$BACKUP_FILE" world 2>/dev/null || true
        
        if [ -f "$BACKUP_FILE" ]; then
            log "  Backup created: $BACKUP_FILE"
            return 0
        fi
    fi
    
    log "  No world data to backup (new server)"
    return 0
}

main() {
    log "=========================================="
    log "Minecraft Auto-Update Check"
    log "=========================================="
    
    if [ ! -d "$SERVER_DIR" ]; then
        log "Error: Server directory not found: $SERVER_DIR"
        exit 1
    fi
    
    create_world_backup
    
    UPDATES_AVAILABLE=0
    UPDATES_APPLIED=0
    
    PAPER_INFO=$(check_paper_update) && {
        MC_VERSION=$(echo "$PAPER_INFO" | cut -d: -f1)
        BUILD=$(echo "$PAPER_INFO" | cut -d: -f2)
        if update_paper "$MC_VERSION" "$BUILD"; then
            UPDATES_APPLIED=$((UPDATES_APPLIED + 1))
        fi
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    }
    
    GEYSER_BUILD=$(check_geyser_update) && {
        if update_plugin "Geyser" "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" "Geyser-Spigot.jar" "geyser" "$GEYSER_BUILD"; then
            UPDATES_APPLIED=$((UPDATES_APPLIED + 1))
        fi
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    }
    
    FLOODGATE_BUILD=$(check_floodgate_update) && {
        if update_plugin "Floodgate" "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" "floodgate-spigot.jar" "floodgate" "$FLOODGATE_BUILD"; then
            UPDATES_APPLIED=$((UPDATES_APPLIED + 1))
        fi
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    }
    
    VIA_INFO=$(check_viaversion_update) && {
        VIA_VERSION=$(echo "$VIA_INFO" | cut -d: -f1)
        VIA_URL=$(echo "$VIA_INFO" | cut -d: -f2-)
        if update_plugin "ViaVersion" "$VIA_URL" "ViaVersion.jar" "viaversion" "$VIA_VERSION"; then
            UPDATES_APPLIED=$((UPDATES_APPLIED + 1))
        fi
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    }
    
    log ""
    log "=========================================="
    if [ $UPDATES_APPLIED -gt 0 ]; then
        log "Updates applied: $UPDATES_APPLIED"
        log ""
        log "Restart server to apply updates:"
        log "  sudo systemctl restart minecraft"
    else
        log "All software is up to date!"
    fi
    log "=========================================="
}

main "$@"
