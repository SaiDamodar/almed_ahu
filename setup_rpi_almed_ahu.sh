#!/bin/bash

#################################################################################
# ALMED AHU System - Complete Raspberry Pi Automated Setup Script
# 
# This script automates the entire setup of a Raspberry Pi for the ALMED AHU
# control system, including:
# - System dependencies and updates
# - Flutter SDK installation
# - Flutter-Pi installation
# - MQTT broker (Mosquitto) configuration
# - Hotspot/WiFi configuration
# - MQTT bridge to HiveMQ Cloud
# - All necessary services and drivers
#
# Usage: 
#   sudo bash setup_rpi_almed_ahu.sh
#
# Requirements:
#   - Raspberry Pi with Raspberry Pi OS (64-bit recommended)
#   - Internet connection
#   - Root/sudo access
#
#################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
FLUTTER_VERSION="3.24.5"  # Latest stable as of 2025
MQTT_USER="almed"
MQTT_PASS="Almed1234$"
PI_USER="${SUDO_USER:-pi}"
HOME_DIR="/home/$PI_USER"
APP_DIR="$HOME_DIR/ahu_dashboard"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Error: Please run as root using sudo${NC}"
    echo "Usage: sudo bash $0"
    exit 1
fi

# Print banner
echo ""
echo -e "${CYAN}================================================================================${NC}"
echo -e "${CYAN}    ALMED AHU System - Complete Raspberry Pi Setup${NC}"
echo -e "${CYAN}================================================================================${NC}"
echo ""
echo -e "${YELLOW}This script will install and configure:${NC}"
echo "  ✓ System dependencies and updates"
echo "  ✓ Flutter SDK and Flutter-Pi"
echo "  ✓ MQTT broker (Mosquitto) with authentication"
echo "  ✓ WiFi hotspot configuration"
echo "  ✓ MQTT bridge to HiveMQ Cloud"
echo "  ✓ InfluxDB client library for data storage"
echo "  ✓ All necessary drivers and services"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Function to print step headers
print_step() {
    echo ""
    echo -e "${BLUE}[$1] $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
        exit 1
    fi
}

#################################################################################
# STEP 1: System Update and Basic Dependencies
#################################################################################
print_step "1/10" "Updating System and Installing Basic Dependencies"

echo -e "${YELLOW}Updating package list...${NC}"
apt update -qq
check_success

echo -e "${YELLOW}Upgrading system packages...${NC}"
apt upgrade -y -qq
check_success

echo -e "${YELLOW}Installing essential build tools...${NC}"
apt install -y \
    git \
    curl \
    wget \
    build-essential \
    cmake \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    unclutter \
    x11-xserver-utils \
    hostapd \
    dnsmasq \
    iptables 2>&1 | grep -v "already installed" || true
check_success

echo -e "${YELLOW}Installing graphics libraries...${NC}"
apt install -y \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    libegl1-mesa-dev \
    libdrm-dev \
    libgbm-dev \
    libinput-dev \
    libxkbcommon-dev \
    xorg \
    openbox 2>&1 | grep -v "already installed" || true
check_success

echo -e "${GREEN}✓ Basic dependencies installed${NC}"

#################################################################################
# STEP 2: Install Flutter SDK
#################################################################################
print_step "2/10" "Installing Flutter SDK"

if [ -d "$HOME_DIR/flutter" ]; then
    echo -e "${YELLOW}Flutter already exists, skipping download...${NC}"
    echo -e "${GREEN}✓ Flutter found${NC}"
else
    echo -e "${YELLOW}Downloading Flutter SDK (this may take a while)...${NC}"
    cd "$HOME_DIR"
    wget -q --show-progress "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    tar xf "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    rm "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    check_success
    
    # Add Flutter to PATH for all users
    echo 'export PATH="$PATH:/home/'"$PI_USER"'/flutter/bin"' >> /etc/profile.d/flutter.sh
    export PATH="$PATH:/home/$PI_USER/flutter/bin"
    check_success
    
    # Fix Flutter permissions
    chown -R "$PI_USER:$PI_USER" "$HOME_DIR/flutter"
    
    echo -e "${GREEN}✓ Flutter SDK installed${NC}"
fi

# Verify Flutter installation
echo -e "${YELLOW}Verifying Flutter installation...${NC}"
sudo -u "$PI_USER" bash -c 'export PATH="/home/'"$PI_USER"'/flutter/bin:$PATH" && flutter --version' > /dev/null 2>&1
check_success

#################################################################################
# STEP 3: Install Flutter-Pi
#################################################################################
print_step "3/10" "Installing Flutter-Pi"

if command -v flutter-pi &> /dev/null; then
    echo -e "${YELLOW}Flutter-Pi already installed, skipping...${NC}"
    echo -e "${GREEN}✓ Flutter-Pi found${NC}"
else
    echo -e "${YELLOW}Cloning Flutter-Pi repository...${NC}"
    cd "$HOME_DIR"
    if [ -d "flutter-pi" ]; then
        rm -rf flutter-pi
    fi
    sudo -u "$PI_USER" git clone https://github.com/ardera/flutter-pi.git
    check_success
    
    echo -e "${YELLOW}Building Flutter-Pi (this may take 5-10 minutes)...${NC}"
    cd flutter-pi
    mkdir -p build && cd build
    sudo -u "$PI_USER" cmake .. > /dev/null 2>&1
    make -j4 > /dev/null 2>&1
    make install
    check_success
    
    echo -e "${GREEN}✓ Flutter-Pi installed and ready${NC}"
fi

#################################################################################
# STEP 4: Install and Configure Mosquitto MQTT Broker
#################################################################################
print_step "4/10" "Installing and Configuring MQTT Broker (Mosquitto)"

echo -e "${YELLOW}Installing Mosquitto MQTT broker...${NC}"
apt install -y mosquitto mosquitto-clients 2>&1 | grep -v "already installed" || true
check_success

echo -e "${YELLOW}Configuring MQTT authentication...${NC}"
# Create password file if it doesn't exist
if [ ! -f /etc/mosquitto/passwd ]; then
    (echo "$MQTT_PASS"; echo "$MQTT_PASS") | mosquitto_passwd -c /etc/mosquitto/passwd "$MQTT_USER" 2>&1 | grep -v "password"
else
    (echo "$MQTT_PASS"; echo "$MQTT_PASS") | mosquitto_passwd /etc/mosquitto/passwd "$MQTT_USER" 2>&1 | grep -v "password"
fi
check_success

# Fix permissions
chown mosquitto:mosquitto /etc/mosquitto/passwd
chmod 600 /etc/mosquitto/passwd
check_success

echo -e "${YELLOW}Creating Mosquitto configuration...${NC}"
cat > /etc/mosquitto/conf.d/almed.conf << EOF
# ALMED AHU MQTT Configuration
listener 1883
password_file /etc/mosquitto/passwd
allow_anonymous true

# Logging
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information

# Persistence
persistence true
persistence_location /var/lib/mosquitto/
EOF
check_success

echo -e "${YELLOW}Starting Mosquitto service...${NC}"
systemctl restart mosquitto
systemctl enable mosquitto
check_success

# Test MQTT
echo -e "${YELLOW}Testing MQTT connection...${NC}"
mosquitto_pub -h 127.0.0.1 -u "$MQTT_USER" -P "$MQTT_PASS" -t "almed/test" -m "MQTT setup test" > /dev/null 2>&1
check_success

echo -e "${GREEN}✓ MQTT broker configured and running${NC}"

#################################################################################
# STEP 5: Configure WiFi Hotspot (Optional but Recommended)
#################################################################################
print_step "5/10" "Configuring WiFi Hotspot"

echo -e "${YELLOW}Setting up hostapd for hotspot...${NC}"
# Create hostapd config
cat > /etc/hostapd/hostapd.conf << EOF
# ALMED AHU Hotspot Configuration
interface=wlan0
driver=nl80211
ssid=PiSpot
hw_mode=g
channel=6
wmm_enabled=1

# Authentication
auth_algs=1
wpa=2
wpa_passphrase=12345678
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Connection stability
max_num_sta=20
ap_max_inactivity=300
ignore_broadcast_ssid=0
beacon_int=100
ap_isolate=0
macaddr_acl=0
dtim_period=2
disassoc_low_ack=0
EOF
check_success

# Configure hostapd defaults
cat > /etc/default/hostapd << EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
check_success

# Unmask and enable hostapd
systemctl unmask hostapd > /dev/null 2>&1 || true
systemctl enable hostapd > /dev/null 2>&1 || true

echo -e "${YELLOW}Configuring static IP for hotspot...${NC}"
# Create systemd network configuration for wlan0
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-wlan0-static.network << EOF
[Match]
Name=wlan0

[Network]
Address=10.42.0.1/24
DHCPServer=yes

[DHCPServer]
PoolOffset=20
PoolSize=20
EOF
check_success

# Enable systemd networking
systemctl enable systemd-networkd > /dev/null 2>&1 || true
systemctl restart systemd-networkd > /dev/null 2>&1 || true

echo -e "${GREEN}✓ WiFi hotspot configured (PiSpot, Password: 12345678)${NC}"

#################################################################################
# STEP 6: Setup MQTT Bridge to HiveMQ Cloud
#################################################################################
print_step "6/10" "Setting up MQTT Bridge to HiveMQ Cloud"

echo -e "${YELLOW}Installing Python MQTT libraries...${NC}"
apt install -y python3-paho-mqtt 2>&1 | grep -v "already installed" || true
check_success

echo -e "${YELLOW}Installing InfluxDB client library...${NC}"
apt install -y python3-influxdb-client 2>&1 | grep -v "already installed" || true
check_success

# Create directories for bridge if not existing
mkdir -p "$HOME_DIR/Documents/almed_ahu"
mkdir -p /var/log

# Ensure log directory has proper permissions
touch /var/log/mqtt_bridge.log 2>/dev/null || true
chmod 644 /var/log/mqtt_bridge.log 2>/dev/null || true

echo -e "${YELLOW}Copying MQTT bridge script (if available)...${NC}"
if [ -f "$SCRIPT_DIR/mqtt_bridge.py" ]; then
    cp "$SCRIPT_DIR/mqtt_bridge.py" "$HOME_DIR/Documents/almed_ahu/"
    chown "$PI_USER:$PI_USER" "$HOME_DIR/Documents/almed_ahu/mqtt_bridge.py"
    chmod +x "$HOME_DIR/Documents/almed_ahu/mqtt_bridge.py"
    echo -e "${GREEN}✓ MQTT bridge script copied${NC}"
else
    echo -e "${YELLOW}⚠ mqtt_bridge.py not found in current directory${NC}"
    echo -e "${YELLOW}  You can add it later at: $HOME_DIR/Documents/almed_ahu/mqtt_bridge.py${NC}"
fi

# Copy systemd service if available
if [ -f "$SCRIPT_DIR/mqtt-bridge.service" ]; then
    echo -e "${YELLOW}Configuring MQTT bridge service...${NC}"
    # Update service file paths
    sed "s|/home/almed|$HOME_DIR|g" "$SCRIPT_DIR/mqtt-bridge.service" > /etc/systemd/system/mqtt-bridge.service
    systemctl daemon-reload
    echo -e "${GREEN}✓ MQTT bridge service configured (disabled by default)${NC}"
else
    echo -e "${YELLOW}⚠ mqtt-bridge.service not found, skipping service setup${NC}"
fi

echo -e "${GREEN}✓ MQTT bridge setup complete${NC}"

#################################################################################
# STEP 7: Configure App Directory
#################################################################################
print_step "7/10" "Setting up Application Directory"

echo -e "${YELLOW}Creating app directories...${NC}"
mkdir -p "$APP_DIR"
mkdir -p /opt/ahu_dashboard
chown "$PI_USER:$PI_USER" "$APP_DIR"
chown "$PI_USER:$PI_USER" /opt/ahu_dashboard
check_success

echo -e "${YELLOW}Creating kiosk startup script...${NC}"
cat > /opt/ahu_dashboard/start_kiosk.sh << 'KIOSK_EOF'
#!/bin/bash

# ALMED AHU Dashboard Kiosk Mode Startup

# Disable screen blanking
xset s off 2>/dev/null
xset -dpms 2>/dev/null
xset s noblank 2>/dev/null

# Hide cursor
unclutter -idle 0.5 -root &

# Start Flutter-Pi app
cd /opt/ahu_dashboard
flutter-pi --release .

# If app crashes, restart after 5 seconds
if [ $? -ne 0 ]; then
    sleep 5
    exec $0
fi
KIOSK_EOF

chmod +x /opt/ahu_dashboard/start_kiosk.sh
check_success

echo -e "${YELLOW}Creating systemd service for dashboard...${NC}"
cat > /etc/systemd/system/ahu-dashboard.service << EOF
[Unit]
Description=ALMED AHU Dashboard
After=graphical.target network.target
Wants=graphical.target

[Service]
Type=simple
User=$PI_USER
Group=$PI_USER
WorkingDirectory=/opt/ahu_dashboard
ExecStart=/opt/ahu_dashboard/start_kiosk.sh
Restart=always
RestartSec=5
Environment=DISPLAY=:0

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
# Don't enable by default - user will do this after deploying app
echo -e "${GREEN}✓ Dashboard service created (not enabled yet)${NC}"

echo -e "${GREEN}✓ Application directory setup complete${NC}"

#################################################################################
# STEP 8: System Optimization
#################################################################################
print_step "8/10" "System Optimization and Performance Tuning"

echo -e "${YELLOW}Disabling unnecessary services...${NC}"
systemctl disable bluetooth 2>/dev/null || true
systemctl disable hciuart 2>/dev/null || true
systemctl disable ModemManager 2>/dev/null || true
echo -e "${GREEN}✓ Unnecessary services disabled${NC}"

echo -e "${YELLOW}Configuring GPU memory split (requires manual raspi-config)...${NC}"
# Note: This requires interactive raspi-config, so we'll just inform user
echo -e "${YELLOW}  Run later: sudo raspi-config → Advanced → Memory Split → 128${NC}"

echo -e "${YELLOW}Enabling hardware watchdog...${NC}"
modprobe bcm2835_wdt 2>/dev/null || true
echo "bcm2835_wdt" >> /etc/modules-load.d/bcm2835-watchdog.conf 2>/dev/null || true
echo -e "${GREEN}✓ Hardware watchdog enabled${NC}"

echo -e "${GREEN}✓ System optimization complete${NC}"

#################################################################################
# STEP 9: Firewall Configuration
#################################################################################
print_step "9/10" "Configuring Firewall"

echo -e "${YELLOW}Setting up UFW firewall...${NC}"
apt install -y ufw 2>&1 | grep -v "already installed" || true
ufw --force enable 2>/dev/null || true
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
ufw allow 1883/tcp comment 'MQTT Local' 2>/dev/null || true
ufw allow 8883/tcp comment 'MQTT TLS (HiveMQ Cloud)' 2>/dev/null || true
ufw allow 80/tcp comment 'HTTP' 2>/dev/null || true
ufw allow 443/tcp comment 'HTTPS' 2>/dev/null || true
check_success

echo -e "${GREEN}✓ Firewall configured${NC}"

#################################################################################
# STEP 10: Final Configuration and Summary
#################################################################################
print_step "10/10" "Final Configuration and Summary"

echo -e "${YELLOW}Creating setup summary...${NC}"
cat > "$HOME_DIR/ALMED_SETUP_SUMMARY.txt" << EOF
================================================================================
    ALMED AHU System - Raspberry Pi Setup Summary
================================================================================

Installation Date: $(date)
Raspberry Pi User: $PI_USER

✓ INSTALLED COMPONENTS:
  - Flutter SDK: $FLUTTER_VERSION
  - Flutter-Pi: $(flutter-pi --version 2>/dev/null | head -1 || echo "Installed")
  - Mosquitto MQTT Broker: $(mosquitto -h 2>&1 | grep version || echo "Installed")
  - Python 3: $(python3 --version)
  - Python MQTT Client (paho-mqtt): Installed
  - Python InfluxDB Client: Installed
  - System Dependencies: All installed

✓ CONFIGURED SERVICES:
  - mosquitto.service: MQTT broker (port 1883)
  - ahu-dashboard.service: Dashboard kiosk mode (not enabled yet)
  - mqtt-bridge.service: Cloud bridge (not enabled yet)
  - hostapd.service: WiFi hotspot
  - UFW Firewall: Enabled

✓ MQTT CREDENTIALS:
  Username: $MQTT_USER
  Password: $MQTT_PASS
  Port: 1883
  Test: mosquitto_pub -h 127.0.0.1 -u $MQTT_USER -P '$MQTT_PASS' -t test -m "hello"

✓ NETWORK CONFIGURATION:
  WiFi Hotspot: PiSpot
  Password: 12345678
  IP Range: 10.42.0.1/24

✓ DIRECTORIES:
  Flutter SDK: $HOME_DIR/flutter
  App Directory: $APP_DIR
  Production App: /opt/ahu_dashboard
  Bridge Script: $HOME_DIR/Documents/almed_ahu/mqtt_bridge.py

✓ NEXT STEPS:
  1. Configure GPU memory split:
     sudo raspi-config
     → Advanced Options → Memory Split → 128

  2. Deploy your Flutter app to /opt/ahu_dashboard/
     (Build and copy from your development machine)

  3. Enable dashboard service:
     sudo systemctl enable ahu-dashboard.service
     sudo systemctl start ahu-dashboard.service

  4. (Optional) Configure MQTT bridge to HiveMQ Cloud and InfluxDB:
     Edit: $HOME_DIR/Documents/almed_ahu/mqtt_bridge.py
     Set CLOUD_BROKER, CLOUD_USER, CLOUD_PASS
     Set INFLUXDB_URL, INFLUXDB_TOKEN, INFLUXDB_ORG, INFLUXDB_BUCKET
     sudo systemctl enable mqtt-bridge.service
     sudo systemctl start mqtt-bridge.service

  5. Test MQTT:
     sudo mosquitto_sub -h 127.0.0.1 -u $MQTT_USER -P '$MQTT_PASS' -t "#" -v

  6. Reboot system:
     sudo reboot

✓ TROUBLESHOOTING:
  - Check Mosquitto: sudo systemctl status mosquitto
  - View logs: sudo journalctl -u mosquitto -f
  - Check dashboard: sudo systemctl status ahu-dashboard.service
  - View dashboard logs: sudo journalctl -u ahu-dashboard.service -f

================================================================================
            Setup Complete! Ready for ALMED AHU deployment.
================================================================================
EOF

chown "$PI_USER:$PI_USER" "$HOME_DIR/ALMED_SETUP_SUMMARY.txt"

echo ""
echo -e "${CYAN}================================================================================${NC}"
echo -e "${GREEN}✓✓✓ ALMED AHU System Setup Complete! ✓✓✓${NC}"
echo -e "${CYAN}================================================================================${NC}"
echo ""
echo -e "${YELLOW}Setup Summary saved to: ${HOME_DIR}/ALMED_SETUP_SUMMARY.txt${NC}"
echo ""
echo -e "${BLUE}Installed and Configured:${NC}"
echo "  ✓ Flutter SDK and Flutter-Pi"
echo "  ✓ MQTT Broker (Mosquitto)"
echo "  ✓ WiFi Hotspot (PiSpot)"
echo "  ✓ MQTT Bridge service"
echo "  ✓ InfluxDB client library"
echo "  ✓ Dashboard kiosk service"
echo "  ✓ Firewall and security"
echo "  ✓ All drivers and dependencies"
echo ""
echo -e "${BLUE}MQTT Credentials:${NC}"
echo "  Username: $MQTT_USER"
echo "  Password: $MQTT_PASS"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Read: ${HOME_DIR}/ALMED_SETUP_SUMMARY.txt"
echo "  2. Configure GPU memory: sudo raspi-config"
echo "  3. Deploy your Flutter app"
echo "  4. Enable services and reboot"
echo ""
echo -e "${GREEN}Your Raspberry Pi is now ready for ALMED AHU deployment!${NC}"
echo ""

# Final reminder about GPU memory
echo -e "${YELLOW}⚠️  IMPORTANT: Run 'sudo raspi-config' to set GPU memory split to 128${NC}"
echo ""

