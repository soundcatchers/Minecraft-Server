# Minecraft Server Configuration for Raspberry Pi 4

## Overview
This project contains configuration files and setup scripts for running a cross-platform Minecraft Paper Server on a Raspberry Pi 4. It supports both Java and Bedrock players through Geyser/Floodgate plugins.

## Current State
- **Status**: Complete configuration and setup scripts
- **Server Version**: Paper 1.21.10-129
- **Cross-Platform**: Java (25565) + Bedrock (19132)
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
│   ├── setup.sh           # Main setup script
│   ├── install-systemd.sh # Auto-start service installer
│   ├── auto-update.sh     # Automatic version checker and updater
│   ├── install-cron.sh    # Install daily auto-update cron job
│   ├── update-plugins.sh  # Manual plugin updater
│   └── backup.sh          # World backup script
├── config/                # Paper server optimization configs
│   ├── paper-global.yml
│   └── paper-world-defaults.yml
├── etc/systemd/system/    # Systemd service file
│   └── minecraft.service
├── server.properties      # Minecraft server settings
├── ops.json               # Operator permissions
└── README.md              # Complete setup guide
```

## Key Features
1. **Setup Scripts**: Automated installation of Paper server and plugins
2. **Optimized Performance**: Aikar's JVM flags for 8GB Pi 4
3. **Cross-Platform**: Geyser + Floodgate for Bedrock support
4. **Auto-Start**: Systemd service for boot-on-startup
5. **Web Viewer**: Browse configs in the browser

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

## Running Locally
The web viewer runs on port 5000 with `npm start`.
