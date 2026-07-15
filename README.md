# Minecraft Server for Raspberry Pi 4

A complete setup for running a cross-platform Minecraft server (Java + Bedrock) on a Raspberry Pi 4.

## Features

- **PaperMC Server**: Optimized Minecraft server (auto-updates to latest)
- **Cross-Platform**: Java and Bedrock players can play together
- **Geyser + Floodgate**: Bedrock players connect without Java accounts
- **ViaVersion**: Version compatibility support
- **Optimized Performance**: Aikar's flags for smooth gameplay
- **Auto-Start**: Systemd service for boot-on-startup
- **Auto-Updates**: Daily automatic updates with world backups
- **USB SSD Support**: Better performance than SD card

## Quick Start

### 1. Prerequisites

On your Raspberry Pi 4 (8GB recommended):

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install git jq wget curl -y

# Install Java 21 (required for Paper 1.21+)
# Option 1: If available in your repos
sudo apt install openjdk-21-jdk -y

# Option 2: If not available, use Adoptium repository
# curl -s https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc
# echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
# sudo apt update && sudo apt install temurin-21-jdk -y

# Verify Java version (should show 21.x.x)
java -version

# Create minecraft user (if not exists)
sudo useradd -r -m -U -d /home/minecraft -s /bin/bash minecraft

# Switch to minecraft user
sudo su - minecraft
```

### 2. (Optional) Prepare USB SSD

If using a USB SSD (recommended for better performance):

```bash
# As your normal user (not minecraft), plug in the SSD and identify it
lsblk
# Look for 'sda' - your SSD

# Create partition
sudo parted /dev/sda --script mklabel gpt mkpart primary ext4 0% 100%

# Format to ext4
sudo mkfs.ext4 /dev/sda1

# Create mount point and mount
sudo mkdir -p /mnt/ssd
sudo mount /dev/sda1 /mnt/ssd

# Get UUID for auto-mount
sudo blkid /dev/sda1
# Copy the UUID shown

# Add to fstab for auto-mount on boot
sudo nano /etc/fstab
# Add this line (use YOUR UUID):
# UUID=your-uuid-here  /mnt/ssd  ext4  defaults,auto,nofail  0  2

# Test and reboot
sudo systemctl daemon-reload
sudo reboot

# After reboot, verify SSD is mounted
df -h | grep sda
```

### 3. Clone and Setup

```bash
# Switch to minecraft user
sudo su - minecraft

# Clone this repository
git clone <your-repo-url> minecraft-config
cd minecraft-config

# Run the interactive setup script
bash scripts/setup.sh
```

The setup script will ask you:
- **Storage location**: SD Card or USB SSD
- **Auto-start**: Enable server to start on boot
- **Auto-updates**: Enable daily automatic updates (4 AM)

### 4. Start the Server

```bash
# Start the server
sudo systemctl start minecraft

# Check it's running
sudo systemctl status minecraft
```

## Connection Details

| Edition | Address | Port |
|---------|---------|------|
| Java | `<your-pi-ip>` | 25565 |
| Bedrock | `<your-pi-ip>` | 19132 |

Find your Pi's IP: `hostname -I`

## Server Management

### Systemd Commands

```bash
# Start server
sudo systemctl start minecraft

# Stop server
sudo systemctl stop minecraft

# Restart server
sudo systemctl restart minecraft

# Check status
sudo systemctl status minecraft

# View live logs
sudo journalctl -u minecraft -f

# Disable auto-start
sudo systemctl disable minecraft

# Enable auto-start
sudo systemctl enable minecraft
```

### Manual Start (Without Systemd)

```bash
# For SD card install:
cd ~/minecraft-server
java -Xms3G -Xmx3G -jar paper-*.jar nogui

# For SSD install:
cd /mnt/ssd/minecraft-server
java -Xms3G -Xmx3G -jar paper-*.jar nogui
```

### Using Screen (Keeps Running After SSH Disconnect)

```bash
# Install screen
sudo apt install screen

# Start server in screen
screen -S minecraft
cd /mnt/ssd/minecraft-server  # or ~/minecraft-server for SD card
java -Xms3G -Xmx3G -jar paper-*.jar nogui

# Detach: Ctrl+A, then D
# Reconnect: screen -r minecraft
```

## Player Permissions

### Give Operator Powers (Using ops.json - Recommended)

Since the server runs via systemd without direct console access, editing `ops.json` is the easiest method:

1. **Stop the server**:
```bash
sudo systemctl stop minecraft
```

2. **Edit the ops.json file**:
```bash
# For SSD install:
nano /mnt/ssd/minecraft-server/ops.json

# For SD card install:
nano /home/minecraft/minecraft-server/ops.json
```

3. **Add your username** (replace `YourUsername` with your actual name):

For **Java players**:
```json
[
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": "YourJavaUsername",
    "level": 4,
    "bypassesPlayerLimit": true
  }
]
```

For **Bedrock players** (use dot prefix, replace spaces with underscores):
```json
[
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": ".YourGamertag",
    "level": 4,
    "bypassesPlayerLimit": true
  }
]
```

For **multiple operators**:
```json
[
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": "JavaPlayer",
    "level": 4,
    "bypassesPlayerLimit": true
  },
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": ".BedrockPlayer",
    "level": 4,
    "bypassesPlayerLimit": true
  }
]
```

4. **Save and exit**: Press `Ctrl+O`, `Enter`, then `Ctrl+X`

5. **Restart the server**:
```bash
sudo systemctl start minecraft
```

The server will automatically assign the correct UUID when each player first joins.

### Remove Operator

Edit `ops.json` and remove the player's entry, then restart the server.

### In-Game Commands (Alternative)

If you have console access via screen, you can use:
```
op PlayerUsername
op .XboxGamertag
deop PlayerUsername
```

## Whitelist (Recommended for Security)

A whitelist ensures only approved players can join your server. This is the best security measure for a private server shared with friends.

### Enable Whitelist

1. **Stop the server**:
```bash
sudo systemctl stop minecraft
```

2. **Edit server.properties**:
```bash
# For SSD install:
nano /mnt/ssd/minecraft-server/server.properties

# For SD card install:
nano /home/minecraft/minecraft-server/server.properties
```

3. **Find and change**:
```
white-list=false
```
To:
```
white-list=true
enforce-whitelist=true
```

4. **Save and exit**: `Ctrl+O`, `Enter`, `Ctrl+X`

5. **Add players to whitelist** by editing `whitelist.json`:
```bash
# For SSD install:
nano /mnt/ssd/minecraft-server/whitelist.json

# For SD card install:
nano /home/minecraft/minecraft-server/whitelist.json
```

Add your friends (similar format to ops.json):

For **Java players**:
```json
[
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": "JavaUsername"
  }
]
```

For **Bedrock players** (dot prefix, spaces become underscores):
```json
[
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": ".BedrockGamertag"
  }
]
```

For **multiple players**:
```json
[
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": "JavaPlayer1"
  },
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": ".BedrockPlayer1"
  },
  {
    "uuid": "00000000-0000-0000-0000-000000000000",
    "name": ".Another_Bedrock_Player"
  }
]
```

6. **Restart the server**:
```bash
sudo systemctl start minecraft
```

The server will automatically assign correct UUIDs when each player first connects.

### Disable RCON (Extra Security)

RCON allows remote console access. If you don't need it, disable it:

In `server.properties`, ensure:
```
enable-rcon=false
```

## Server Console Commands (RCON)

Since the server runs via systemd, you can send commands remotely using RCON (Remote Console).

### One-Time Setup

**1. Install mcrcon (if not already installed):**
```bash
sudo apt update && sudo apt install -y git build-essential
cd ~
git clone https://github.com/Tiiffi/mcrcon.git
cd mcrcon
make
sudo make install
cd ~
```

**2. Enable RCON in server.properties:**
```bash
sudo systemctl stop minecraft

# For SSD install:
sudo sed -i 's/enable-rcon=false/enable-rcon=true/' /mnt/ssd/minecraft-server/server.properties
sudo sed -i 's/rcon.password=/rcon.password=your_secure_password/' /mnt/ssd/minecraft-server/server.properties

# For SD card install:
sudo sed -i 's/enable-rcon=false/enable-rcon=true/' /home/minecraft/minecraft-server/server.properties
sudo sed -i 's/rcon.password=/rcon.password=your_secure_password/' /home/minecraft/minecraft-server/server.properties

sudo systemctl start minecraft
```

### Sending Commands

```bash
# Basic command format
mcrcon -H localhost -P 25575 -p your_secure_password "command here"

# Examples:
mcrcon -H localhost -P 25575 -p your_secure_password "say Hello everyone!"
mcrcon -H localhost -P 25575 -p your_secure_password "op PlayerName"
mcrcon -H localhost -P 25575 -p your_secure_password "whitelist add PlayerName"
```

### Common Server Commands via RCON

```bash
# Disable/enable locator bar (shows player positions on screen)
mcrcon -H localhost -P 25575 -p your_secure_password "gamerule locator_bar false"
mcrcon -H localhost -P 25575 -p your_secure_password "gamerule locator_bar true"

# Change difficulty
mcrcon -H localhost -P 25575 -p your_secure_password "difficulty normal"

# Change weather
mcrcon -H localhost -P 25575 -p your_secure_password "weather clear"

# Set time
mcrcon -H localhost -P 25575 -p your_secure_password "time set day"

# Broadcast message to all players
mcrcon -H localhost -P 25575 -p your_secure_password "say Server will restart in 5 minutes!"

# Add player to whitelist
mcrcon -H localhost -P 25575 -p your_secure_password "whitelist add .BedrockPlayer"

# Give operator status
mcrcon -H localhost -P 25575 -p your_secure_password "op PlayerName"
```

## Common In-Game Commands (for OPs)

```
# Change difficulty
/difficulty peaceful|easy|normal|hard

# Change gamemode
/gamemode survival|creative|adventure
/gamemode creative PlayerName

# Time and weather
/time set day|night
/weather clear|rain

# Teleport
/tp PlayerName x y z
/tp PlayerName OtherPlayer

# Locator bar (player position indicators)
/gamerule locator_bar false
/gamerule locator_bar true
```

## Configuration Files

| File | Purpose |
|------|---------|
| `server.properties` | Main server settings |
| `config/paper-global.yml` | Paper global optimizations |
| `config/paper-world-defaults.yml` | World-specific optimizations |
| `ops.json` | Operator list |
| `etc/systemd/system/minecraft.service` | Systemd service file |

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup.sh` | Interactive server setup - storage, auto-start, auto-updates |
| `scripts/install-systemd.sh` | Install auto-start service with Aikar's JVM flags |
| `scripts/auto-update.sh` | Check and install updates (run via systemd timer) |
| `scripts/update-plugins.sh` | Manual plugin update (Geyser/Floodgate/ViaVersion) |
| `scripts/backup.sh` | Backup world data and configs |

## Installed Plugins

1. **Geyser-Spigot** - Allows Bedrock players to connect
2. **Floodgate** - Bedrock players don't need Java accounts
3. **ViaVersion** - Version compatibility support

## Port Forwarding (For Remote Friends)

To let friends outside your network connect:

### Step 1: Set a Static IP for Your Pi

This ensures your Pi always has the same local IP address:

```bash
sudo nano /etc/dhcpcd.conf
```

Add at the bottom (adjust for your network):
```
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8
```

For WiFi, use `interface wlan0` instead. Reboot after saving.

### Step 2: Configure Your Router

1. Log into your router (usually `192.168.1.1` or `192.168.0.1`)
2. Find "Port Forwarding", "Virtual Server", or "NAT"
3. Add these rules pointing to your Pi's static IP:

| Service | External Port | Internal Port | Protocol | Internal IP |
|---------|---------------|---------------|----------|-------------|
| Minecraft Java | 25565 | 25565 | TCP | 192.168.1.100 |
| Minecraft Bedrock | 19132 | 19132 | UDP | 192.168.1.100 |

4. Save and apply changes

### Step 3: Test Port Forwarding

Visit https://canyouseeme.org and check port 25565. If it shows "Success", you're good!

### Step 4: Share Your Address

- Find your public IP: https://whatismyip.com
- Share with friends: `your-public-ip:25565` (Java) or `your-public-ip:19132` (Bedrock)

## Dynamic DNS (Friendly Web Address)

Instead of sharing your IP address (which can change), use a free Dynamic DNS service to get a memorable hostname like `myserver.duckdns.org`.

### Option 1: DuckDNS (Recommended - Free Forever)

**1. Create Account and Domain**
- Visit https://www.duckdns.org
- Sign in with Google, GitHub, Twitter, or Reddit
- Create a subdomain (e.g., `myminecraft` → `myminecraft.duckdns.org`)
- Copy your **token** (keep this private!)

**2. Set Up Auto-Update on Pi**

```bash
# Create directory
mkdir -p ~/duckdns
cd ~/duckdns

# Create update script
nano duck.sh
```

Add this content (replace YOUR_SUBDOMAIN and YOUR_TOKEN):
```bash
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=YOUR_SUBDOMAIN&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -
```

Example with real values:
```bash
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=myminecraft&token=a1b2c3d4-e5f6-7890-abcd-ef1234567890&ip=" | curl -k -o ~/duckdns/duck.log -K -
```

**3. Make Executable and Test**

```bash
chmod 700 duck.sh
./duck.sh
cat duck.log
```

If it shows `OK`, it's working!

**4. Set Up Automatic Updates (Every 5 Minutes)**

```bash
crontab -e
```

Add this line at the bottom:
```
*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```

Save and exit. Your IP will now auto-update every 5 minutes.

**5. Share Your Address**

Give friends: `myminecraft.duckdns.org` (Java) or `myminecraft.duckdns.org:19132` (Bedrock)

### Option 2: No-IP (Free with Monthly Renewal)

**1. Create Account**
- Visit https://www.noip.com
- Sign up and create a hostname (e.g., `yourname.ddns.net`)

**2. Install No-IP Client**

```bash
cd /tmp
wget http://www.noip.com/client/linux/noip-duc-linux.tar.gz
tar xzf noip-duc-linux.tar.gz
cd noip-2.1.9-1
sudo make
sudo make install
```

**3. Configure**

```bash
sudo noip2 -C
```

Enter your No-IP email, password, and select your hostname.

**4. Start and Enable Auto-Start**

```bash
sudo noip2

# Add to startup
sudo nano /etc/rc.local
```

Add before `exit 0`:
```
/usr/local/bin/noip2
```

### Comparison: DuckDNS vs No-IP

| Feature | DuckDNS | No-IP |
|---------|---------|-------|
| Cost | Free forever | Free (monthly renewal required) |
| Subdomains | 5 max | 3 max (free tier) |
| Setup | Simple curl script | Requires client install |
| Domain format | yourname.duckdns.org | yourname.ddns.net |
| Best for | Simple setup, beginners | Advanced features |

### Troubleshooting Dynamic DNS

**DuckDNS not updating?**
```bash
# Check the log
cat ~/duckdns/duck.log

# Manually test
~/duckdns/duck.sh && cat ~/duckdns/duck.log

# Verify cron is running
sudo systemctl status cron
```

**Can't connect from outside?**
- Verify port forwarding is set up correctly
- Check ports are open: https://canyouseeme.org
- Ensure Pi firewall allows connections: `sudo ufw allow 25565 && sudo ufw allow 19132`

## Changing Server Ports (Optional)

The default ports (25565 for Java, 19132 for Bedrock) are universal Minecraft standards. You can change them for:
- **Security through obscurity** - Automated scanners won't find your server
- **ISP restrictions** - Some ISPs block common gaming ports
- **Multiple servers** - Run several servers on one Pi

### How to Change Ports

1. **Stop the server**:
```bash
sudo systemctl stop minecraft
```

2. **Change Java port** - Edit `server.properties`:
```bash
nano /home/minecraft/minecraft-server/server.properties
```
Find and change:
```
server-port=25565
```
To any number between 10000-65000, e.g.:
```
server-port=34567
```

3. **Change Bedrock port** - Edit Geyser config:
```bash
nano /home/minecraft/minecraft-server/plugins/Geyser-Spigot/config.yml
```
Find and change the port under `bedrock:`:
```yaml
bedrock:
  port: 19132
```
To your chosen port, e.g.:
```yaml
bedrock:
  port: 45678
```

**Important:** YAML requires a space after the colon. `port: 45678` is correct, `port:45678` will break Geyser.

4. **Restart the server**:
```bash
sudo systemctl start minecraft
```

5. **Update port forwarding** in your router to match the new ports

### Connecting with Custom Ports

Players must include the port when connecting:
- **Java**: `your-ip:34567`
- **Bedrock**: Add server manually with IP `your-ip` and port `45678`

### Will Updates Break Custom Ports?

**No** - Config files are preserved during updates. The auto-update script only replaces `.jar` files, not your configurations.

## Performance Optimizations

This setup includes:

- **3GB RAM allocation** (optimal for Pi 4 8GB)
- **Aikar's JVM flags** (reduced garbage collection lag)
- **Paper async chunk loading** (multi-threaded)
- **Entity limits** (prevent mob-related lag)
- **CPU/Memory limits** (safety margins)

### Expected Performance

- **Players**: 10-15 smooth, up to 20 possible
- **TPS**: Consistent 20 (no lag)
- **View distance**: 10 chunks
- **Boot time**: ~60 seconds

### Monitoring

```bash
# In-game (as OP)
/tps
/spark tps

# System
free -h              # Memory
htop                 # CPU
vcgencmd measure_temp  # Temperature (keep under 80C)
```

## Backups

```bash
# Create backup
bash scripts/backup.sh

# Backups saved to ~/minecraft-backups/
```

## Troubleshooting

### Server Won't Start After Reboot (SSD)

If using a USB SSD and the server doesn't auto-start after reboot, the SSD might not be mounted in time.

**1. Check if SSD is mounted:**
```bash
df -h | grep sda
```

If nothing shows, mount it manually:
```bash
sudo mount /dev/sda1 /mnt/ssd
sudo systemctl start minecraft
```

**2. Add SSD mount dependency to the service:**
```bash
sudo nano /etc/systemd/system/minecraft.service
```

Update the `[Unit]` section to wait for the SSD:
```ini
[Unit]
Description=Minecraft Server (Optimized for Pi 4 - 8GB)
After=network-online.target mnt-ssd.mount
Wants=network-online.target
Requires=mnt-ssd.mount
```

Then reload:
```bash
sudo systemctl daemon-reload
```

**3. Make sure fstab has the SSD:**
```bash
cat /etc/fstab | grep ssd
```

If missing, add it (use `sudo blkid /dev/sda1` to get UUID):
```
UUID=your-uuid-here  /mnt/ssd  ext4  defaults,auto,nofail  0  2
```

### Server Won't Start
- Check if already running: `screen -ls`
- Check logs: `sudo journalctl -u minecraft -n 50`
- Verify directory: `cd ~/minecraft-server && ls`

### Can't Connect
- Local network: Use Pi's local IP (not DuckDNS address)
- Bedrock: Check you're using the correct Bedrock port (default 19132)
- Firewalls: Ensure ports are open

### "Tried to log in as Java Edition player" Error (Bedrock)

This usually means port forwarding isn't correctly set up for your Pi's IP:

1. **If using WiFi**: Make sure your router's port forwarding rules point to your Pi's **WiFi IP address** (not ethernet)
2. **Check IP reservation**: If you have a static IP reservation for WiFi, ensure the UDP port forward matches that IP
3. **Local vs Remote**: When at home, connect using the Pi's local IP. When away, use your DuckDNS address

To find your Pi's current IP:
```bash
hostname -I
```

If you see two IPs (ethernet and WiFi), make sure port forwarding points to the one you're actually using.

### Bedrock Players Can't Chat

If Bedrock players see "Chat disabled due to missing profile public key" or similar errors, you need to disable secure chat enforcement:

```bash
sudo systemctl stop minecraft

# For SSD install:
sudo sed -i 's/enforce-secure-profile=true/enforce-secure-profile=false/' /mnt/ssd/minecraft-server/server.properties

# For SD card install:
sudo sed -i 's/enforce-secure-profile=true/enforce-secure-profile=false/' /home/minecraft/minecraft-server/server.properties

sudo systemctl start minecraft
```

This is required because Java 1.19+ introduced cryptographic chat signing that Bedrock clients can't support. Disabling it allows both Java and Bedrock players to chat normally.

### Players Can't Build Near Spawn

If non-operator players can't break/place blocks or strip wood near spawn, that's **spawn protection**. By default, only operators can modify blocks within 16 blocks of world spawn.

**Check current setting:**
```bash
grep spawn-protection /mnt/ssd/minecraft-server/server.properties
```

**Disable spawn protection** (let everyone build anywhere):
```bash
sudo sed -i 's/spawn-protection=16/spawn-protection=0/' /mnt/ssd/minecraft-server/server.properties
sudo systemctl restart minecraft
```

Or set a smaller radius (e.g., `spawn-protection=4` for just 4 blocks).

### Bedrock Permissions Not Working
- Username must have dot prefix: `op .Gamertag`
- Spaces become underscores: `op .Cool_Player`

### Server Lag
- Reduce view-distance in `server.properties`: `view-distance=8`
- Check temperature: `vcgencmd measure_temp`
- Check logs for errors

## System Requirements

- **Hardware**: Raspberry Pi 4 (8GB recommended, 4GB minimum)
- **OS**: Raspberry Pi OS Lite (64-bit recommended)
- **Java**: OpenJDK 21
- **Storage**: 16GB+ SD card or USB SSD (recommended)

## USB SSD Migration (Recommended)

Running from a USB SSD instead of an SD card improves performance and reliability.

### Format and Mount the SSD

1. **Plug in the SSD and identify it**:
```bash
lsblk
```
Look for `sda` (your SSD) - should show ~220GB or similar.

2. **Create a partition**:
```bash
sudo parted /dev/sda --script mklabel gpt mkpart primary ext4 0% 100%
```

3. **Format to ext4**:
```bash
sudo mkfs.ext4 /dev/sda1
```

4. **Create mount point and mount**:
```bash
sudo mkdir -p /mnt/ssd
sudo mount /dev/sda1 /mnt/ssd
```

5. **Set up auto-mount on boot**:
```bash
sudo blkid /dev/sda1
```
Copy the UUID, then:
```bash
sudo cp /etc/fstab /etc/fstab.backup
sudo nano /etc/fstab
```
Add this line (use YOUR UUID):
```
UUID=your-uuid-here  /mnt/ssd  ext4  defaults,auto,nofail  0  2
```

6. **Test auto-mount**:
```bash
sudo systemctl daemon-reload
sudo reboot
```
After reboot, verify: `df -h | grep sda`

### Copy Server to SSD

1. **Create folder and set permissions**:
```bash
sudo mkdir -p /mnt/ssd/minecraft-server
sudo chown minecraft:minecraft /mnt/ssd/minecraft-server
```

2. **Copy all server files**:
```bash
cp -r /home/minecraft/minecraft-server/* /mnt/ssd/minecraft-server/
```

3. **Update systemd service**:
```bash
sudo nano /etc/systemd/system/minecraft.service
```
Change `WorkingDirectory` to:
```
WorkingDirectory=/mnt/ssd/minecraft-server
```

4. **Reload and restart**:
```bash
sudo systemctl daemon-reload
sudo systemctl restart minecraft
sudo systemctl status minecraft
```

5. **Once confirmed working, remove old files** (optional):
```bash
rm -rf /home/minecraft/minecraft-server
```

## Updating

### Automatic Updates (Recommended)

Set up automatic daily updates using systemd timer (more reliable than cron):

**1. Copy the service and timer files:**
```bash
sudo cp etc/systemd/system/minecraft-update.service /etc/systemd/system/
sudo cp etc/systemd/system/minecraft-update.timer /etc/systemd/system/
```

**2. Update the service path if using SD card:**
```bash
# Only if NOT using SSD - edit the ExecStart path:
sudo nano /etc/systemd/system/minecraft-update.service
# Change /mnt/ssd/minecraft-server to /home/minecraft/minecraft-server
```

**3. Enable and start the timer:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable minecraft-update.timer
sudo systemctl start minecraft-update.timer
```

**4. Verify it's scheduled:**
```bash
systemctl list-timers | grep minecraft
```

The auto-update script:
- Runs daily at 4 AM (with random 5-minute delay to avoid API rate limits)
- Checks Paper, Geyser, Floodgate, and ViaVersion for new releases
- Creates world backups before updating (keeps last 7)
- Verifies downloads before replacing files
- Updates systemd service when Paper version changes
- Only restarts server if updates were actually applied
- Logs all activity to `logs/auto-update.log`

### Manual Update Check

```bash
# Run update check manually (as root)
sudo bash /mnt/ssd/minecraft-server/scripts/auto-update.sh

# Or for SD card installs:
sudo bash ~/minecraft-server/scripts/auto-update.sh
```

### Update Plugins Only

```bash
bash scripts/update-plugins.sh
sudo systemctl restart minecraft
```

### Managing Auto-Updates

```bash
# View scheduled timers
systemctl list-timers | grep minecraft

# View update history
cat /mnt/ssd/minecraft-server/logs/auto-update.log

# Run update manually
sudo systemctl start minecraft-update.service

# Disable auto-updates
sudo systemctl disable minecraft-update.timer
sudo systemctl stop minecraft-update.timer

# Re-enable auto-updates
sudo systemctl enable minecraft-update.timer
sudo systemctl start minecraft-update.timer
```

## License

This is a configuration repository for setting up Minecraft servers. Minecraft is a trademark of Mojang Studios.
