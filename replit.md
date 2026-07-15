# Minecraft Server Configuration for Raspberry Pi 4

## Overview
This project contains configuration files and setup scripts for running a cross-platform Minecraft Paper Server on a Raspberry Pi 4. It supports both Java and Bedrock players through Geyser/Floodgate plugins.

## Current State
- **Status**: Complete configuration and setup scripts
- **Server Version**: Paper (auto-updates to latest)
- **Cross-Platform**: Java (25565) + Bedrock (19132)
- **Storage**: USB SSD at /mnt/ssd/minecraft-server (recommended)
- **Auto-Start**: Systemd service with SSD mount dependency
- **Auto-Updates**: Systemd timer runs daily at 4 AM
- **Web Viewer**: Running on port 5000 for configuration browsing

## Project Structure
```
/
├── server.js              # Express web server for config viewer
├── package.json           # Node.js dependencies
├── public/                # Web viewer static files
│   ├── index.html         
│   ├── style.css          
│   └── app.js             
├── scripts/               # Setup and management scripts
│   ├── setup.sh           # Interactive setup (storage, auto-start, updates)
│   ├── install-systemd.sh # Manual auto-start service installer
│   ├── auto-update.sh     # Automatic updates (run via systemd timer)
│   ├── update-plugins.sh  # Manual plugin updater
│   └── backup.sh          # World backup script
├── config/                # Paper server optimization configs
│   ├── paper-global.yml
│   └── paper-world-defaults.yml
├── etc/systemd/system/    # Systemd files
│   ├── minecraft.service       # Main server service
│   ├── minecraft-update.service # Auto-update oneshot service
│   └── minecraft-update.timer   # Daily timer for updates
├── server.properties      # Minecraft server settings
├── ops.json               # Operator permissions template
└── README.md              # Complete setup guide
```

## Key Features
1. **Interactive Setup**: Choose storage, auto-start, and auto-updates
2. **USB SSD Support**: Better performance than SD card
3. **Optimized Performance**: Aikar's JVM flags for 8GB Pi 4
4. **Cross-Platform**: Geyser + Floodgate for Bedrock support
5. **Auto-Start**: Systemd service waits for SSD mount
6. **Auto-Updates**: Systemd timer with download verification
7. **Web Viewer**: Browse configs in the browser

## Plugins Included
- Geyser-Spigot (Bedrock connection bridge)
- Floodgate (Bedrock auth bypass)
- ViaVersion (Version compatibility)

## Server Configuration Summary
- **Max Players**: 15
- **Game Mode**: Survival
- **Difficulty**: Normal
- **View Distance**: 10 chunks
- **RAM Allocation**: 3GB

## Recent Changes
- 2025-12-30: Added RCON setup and mcrcon for server console commands from Pi
- 2025-12-30: Fixed auto-update script to properly update Geyser/Floodgate/ViaVersion
- 2025-12-30: Uses redirect header parsing for Geyser API (more reliable)
- 2025-12-30: Added version tracking file (.plugin-versions) to avoid unnecessary downloads
- 2025-12-30: Confirmed new Sabrent USB-SATA cable works reliably (replaced faulty UGREEN enclosure)
- 2025-12-28: Replaced cron with systemd timer for auto-updates
- 2025-12-28: Added SSD mount dependency to prevent boot race condition
- 2025-12-28: Improved auto-update script with download verification
- 2025-12-28: Made setup.sh interactive with storage/auto-start options

## Running Locally
The web viewer runs on port 5000 with `npm start`.
