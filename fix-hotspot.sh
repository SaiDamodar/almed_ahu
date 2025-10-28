#!/bin/bash
# Automated hostapd hotspot fix script for Raspberry Pi

set -e

echo "=========================================="
echo "  Hotspot Stability Fix Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Step 1: Check current status
echo -e "${YELLOW}[1/7]${NC} Checking hostapd status..."
if systemctl is-active --quiet hostapd; then
    echo -e "${GREEN}✓ hostapd is running${NC}"
else
    echo -e "${YELLOW}⚠ hostapd is not running${NC}"
fi

# Step 2: Check if masked
echo -e "${YELLOW}[2/7]${NC} Checking if service is masked..."
if systemctl is-enabled hostapd 2>&1 | grep -q "masked"; then
    echo -e "${YELLOW}Unmasking hostapd...${NC}"
    systemctl unmask hostapd
    echo -e "${GREEN}✓ Unmasked${NC}"
else
    echo -e "${GREEN}✓ Not masked${NC}"
fi

# Step 3: Ensure config directory exists
echo -e "${YELLOW}[3/7]${NC} Checking config directory..."
mkdir -p /etc/hostapd
echo -e "${GREEN}✓ Config directory ready${NC}"

# Step 4: Check for existing config
CONFIG_FILE="/etc/hostapd/hostapd.conf"
echo -e "${YELLOW}[4/7]${NC} Checking config file..."

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Creating config file...${NC}"
    cat > "$CONFIG_FILE" << 'EOF'
# Basic settings
interface=wlan0
driver=nl80211
ssid=snorlax
hw_mode=g
channel=6
wmm_enabled=1

# Multiple client support
max_num_sta=20
ap_max_inactivity=300

# Connection stability
auth_algs=1
wpa=2
wpa_passphrase=12345678
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP

# Power management (prevent disconnections)
ignore_broadcast_ssid=0
beacon_int=100

# Stability tweaks
ap_isolate=0
macaddr_acl=0
dtim_period=2

# No disconnect on association errors
disassoc_low_ack=0
EOF
    echo -e "${GREEN}✓ Config file created${NC}"
else
    echo -e "${GREEN}✓ Config file exists${NC}"
    echo -e "${YELLOW}Backing up existing config...${NC}"
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓ Backup created${NC}"
fi

# Step 5: Detect WiFi interface and driver
echo -e "${YELLOW}[5/7]${NC} Detecting WiFi interface and driver..."
INTERFACE=$(ip link show | grep -oP '^[0-9]+: wlan\d+' | head -1 | awk '{print $2}' || echo "wlan0")
echo "  Detected interface: $INTERFACE"

# Always use nl80211 driver (works for Broadcom and most other chipsets)
# Broadcom on Raspberry Pi uses nl80211, not a "broadcom" driver
DRIVER="nl80211"
if dmesg | grep -qi "brcmfmac\|brcm80211"; then
    echo "  Detected: Broadcom WiFi (using nl80211 driver)"
else
    echo "  Using nl80211 driver"
fi
echo "  Driver: $DRIVER"

# Update config with detected interface and driver
sed -i "s/^interface=.*/interface=$INTERFACE/" "$CONFIG_FILE"
sed -i "s/^driver=.*/driver=$DRIVER/" "$CONFIG_FILE"
echo -e "${GREEN}✓ Config updated with detected settings${NC}"

# Step 6: Configure /etc/default/hostapd
echo -e "${YELLOW}[6/7]${NC} Configuring /etc/default/hostapd..."
DEFAULT_FILE="/etc/default/hostapd"
if [ ! -f "$DEFAULT_FILE" ]; then
    touch "$DEFAULT_FILE"
fi

# Add or update DAEMON_CONF line
if grep -q "^DAEMON_CONF=" "$DEFAULT_FILE"; then
    sed -i "s|^DAEMON_CONF=.*|DAEMON_CONF=\"$CONFIG_FILE\"|" "$DEFAULT_FILE"
else
    echo "DAEMON_CONF=\"$CONFIG_FILE\"" >> "$DEFAULT_FILE"
fi
echo -e "${GREEN}✓ Default config updated${NC}"

# Step 7: Check for NetworkManager conflict
echo -e "${YELLOW}[7/7]${NC} Checking for NetworkManager conflicts..."
if systemctl is-active --quiet NetworkManager; then
    echo -e "${YELLOW}⚠ NetworkManager is running (may conflict)${NC}"
    echo -e "${YELLOW}Stopping NetworkManager temporarily...${NC}"
    systemctl stop NetworkManager
    echo -e "${GREEN}✓ NetworkManager stopped${NC}"
    echo -e "${YELLOW}Consider disabling it permanently: sudo systemctl disable NetworkManager${NC}"
fi

# Step 8: Test config syntax
echo ""
echo -e "${YELLOW}[Testing]${NC} Testing config file syntax..."
# Remove invalid config options if they exist
sed -i '/^tx_queue_data.*prio=/d' "$CONFIG_FILE"

if timeout 3 hostapd -d "$CONFIG_FILE" > /tmp/hostapd-test.log 2>&1; then
    echo -e "${GREEN}✓ Config syntax OK${NC}"
else
    ERRORS=$(grep -i "error\|fail\|invalid" /tmp/hostapd-test.log | head -10 || true)
    if [ -n "$ERRORS" ]; then
        echo -e "${YELLOW}⚠ Config test output (errors may be normal):${NC}"
        echo "$ERRORS" | head -5
    else
        echo -e "${GREEN}✓ Config syntax OK (timeout is normal)${NC}"
    fi
fi

# Step 9: Configure interface IP if not set
echo -e "${YELLOW}[Network]${NC} Configuring interface..."
if ! ip addr show "$INTERFACE" | grep -q "10.42.0.1"; then
    echo "  Setting static IP 10.42.0.1..."
    ip addr flush dev "$INTERFACE" 2>/dev/null || true
    ip addr add 10.42.0.1/24 dev "$INTERFACE" 2>/dev/null || true
    ip link set "$INTERFACE" up
    echo -e "${GREEN}✓ Interface configured${NC}"
else
    echo -e "${GREEN}✓ Interface IP already configured${NC}"
fi

# Step 10: Enable and start hostapd
echo ""
echo -e "${YELLOW}[Final]${NC} Enabling and starting hostapd..."
systemctl enable hostapd
if systemctl start hostapd; then
    sleep 2
    if systemctl is-active --quiet hostapd; then
        echo -e "${GREEN}✓ hostapd started successfully!${NC}"
        echo ""
        echo -e "${GREEN}=========================================="
        echo "  SUCCESS! Hotspot should be running"
        echo "==========================================${NC}"
        echo ""
        echo "Check status: sudo systemctl status hostapd"
        echo "Check logs: sudo journalctl -u hostapd -f"
    else
        echo -e "${RED}✗ hostapd failed to start${NC}"
        echo ""
        echo "Check error: sudo journalctl -xeu hostapd.service --no-pager | tail -30"
        exit 1
    fi
else
    echo -e "${RED}✗ Failed to start hostapd${NC}"
    echo ""
    echo "Running diagnostic test..."
    hostapd -dd "$CONFIG_FILE" 2>&1 | head -50
    exit 1
fi

