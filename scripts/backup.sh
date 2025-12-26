#!/bin/bash

# Backup Minecraft server world and configuration
# Usage: ./backup.sh [destination-directory]

set -e

SERVER_DIR="${SERVER_DIR:-$HOME/minecraft-server}"
BACKUP_DIR="${1:-$HOME/minecraft-backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="minecraft-backup-$TIMESTAMP"

echo "=========================================="
echo "Minecraft Server Backup"
echo "=========================================="

if [ ! -d "$SERVER_DIR" ]; then
    echo "Error: Server directory not found: $SERVER_DIR"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo ""
echo "Source: $SERVER_DIR"
echo "Destination: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo ""

# Create backup
echo "Creating backup..."
cd "$SERVER_DIR/.."
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --exclude='*.jar' \
    --exclude='cache' \
    --exclude='logs/*.log.gz' \
    minecraft-server/

# Show backup size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
echo ""
echo "=========================================="
echo "Backup complete!"
echo "=========================================="
echo ""
echo "Backup file: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Size: $BACKUP_SIZE"
echo ""

# List recent backups
echo "Recent backups:"
ls -lht "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -5

# Cleanup old backups (keep last 5)
echo ""
echo "Cleaning up old backups (keeping last 5)..."
cd "$BACKUP_DIR"
ls -t *.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -v

echo ""
echo "Done!"
