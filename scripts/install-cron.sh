#!/bin/bash

# Install cron job for automatic Minecraft server updates
# Runs daily at 4 AM and auto-restarts if updates are found

set -e

echo "=========================================="
echo "Installing Automatic Update Cron Job"
echo "=========================================="

MINECRAFT_USER="${1:-minecraft}"
SERVER_DIR="/home/$MINECRAFT_USER/minecraft-server"
SCRIPT_DIR="$SERVER_DIR/scripts"
AUTO_RESTART="${2:-yes}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo bash $0 [username] [auto-restart: yes/no]"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/auto-update.sh" ]; then
    echo "Error: auto-update.sh not found in $SCRIPT_DIR"
    echo "Please ensure the scripts are in the server directory"
    exit 1
fi

chmod +x "$SCRIPT_DIR/auto-update.sh"

CRON_FILE="/etc/cron.d/minecraft-updates"

if [ "$AUTO_RESTART" = "yes" ]; then
    cat > "$CRON_FILE" << EOF
# Minecraft server automatic updates
# Runs daily at 4:00 AM, updates software, and restarts if needed
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

0 4 * * * root su - $MINECRAFT_USER -c "$SCRIPT_DIR/auto-update.sh $SERVER_DIR" && /usr/bin/systemctl restart minecraft
EOF
else
    cat > "$CRON_FILE" << EOF
# Minecraft server automatic updates
# Runs daily at 4:00 AM (check only, manual restart required)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

0 4 * * * $MINECRAFT_USER $SCRIPT_DIR/auto-update.sh "$SERVER_DIR"
EOF
fi

chmod 644 "$CRON_FILE"

echo ""
echo "Cron job installed successfully!"
echo ""
echo "Schedule: Daily at 4:00 AM"
echo "Auto-restart: $AUTO_RESTART"
echo "Log file: $SERVER_DIR/update.log"
echo ""
echo "=========================================="
echo "Management:"
echo "=========================================="
echo ""
echo "View scheduled updates:  cat /etc/cron.d/minecraft-updates"
echo "View update log:         cat $SERVER_DIR/update.log"
echo "Run update manually:     bash $SCRIPT_DIR/auto-update.sh"
echo "Remove auto-updates:     sudo rm /etc/cron.d/minecraft-updates"
echo ""
echo "=========================================="
