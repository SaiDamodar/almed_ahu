#!/bin/bash
# Dual WiFi Setup Script for Raspberry Pi 4
# Configures one WiFi as hotspot (PiSpot) and another for internet

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "  Dual WiFi Setup for Raspberry Pi 4"
echo "==========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Detect WiFi interfaces
echo -e "${YELLOW}[1/6] Detecting WiFi interfaces...${NC}"
WLAN0=$(ip link show | grep -oP '^[0-9]+: wlan\d+' | head -1 | awk '{print $2}' || echo "wlan0")
WLAN1=$(ip link show | grep -oP '^[0-9]+: wlan\d+' | tail -1 | awk '{print $2}' || echo "")

echo "  Detected interfaces:"
echo "    wlan0 (Hotspot): $WLAN0"
if [ -n "$WLAN1" ] && [ "$WLAN1" != "$WLAN0" ]; then
    echo "    wlan1 (Internet): $WLAN1"
    INTERNET_IF="$WLAN1"
else
    echo "    wlan1: Not detected (will use Ethernet)"
    INTERNET_IF="eth0"
fi

# Step 1: Setup hotspot on wlan0
echo ""
echo -e "${YELLOW}[2/6] Setting up hotspot on $WLAN0...${NC}"
if [ -f "fix-hotspot.sh" ]; then
    bash fix-hotspot.sh
else
    echo -e "${RED}Error: fix-hotspot.sh not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Step 2: Ensure NetworkManager doesn't manage wlan0
echo ""
echo -e "${YELLOW}[3/6] Configuring NetworkManager...${NC}"
nmcli dev set $WLAN0 managed no 2>/dev/null || true
echo -e "${GREEN}✓ NetworkManager configured${NC}"

# Step 3: Enable IP forwarding
echo ""
echo -e "${YELLOW}[4/6] Enabling IP forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi
echo -e "${GREEN}✓ IP forwarding enabled${NC}"

# Step 4: Configure NAT
echo ""
echo -e "${YELLOW}[5/6] Configuring NAT (Internet sharing)...${NC}"

# Clear existing rules for our interfaces
iptables -t nat -D POSTROUTING -o $INTERNET_IF -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i $WLAN0 -o $INTERNET_IF -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i $WLAN0 -o $INTERNET_IF -j ACCEPT 2>/dev/null || true

# Add new rules
iptables -t nat -A POSTROUTING -o $INTERNET_IF -j MASQUERADE
iptables -A FORWARD -i $WLAN0 -o $INTERNET_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WLAN0 -o $INTERNET_IF -j ACCEPT

echo -e "${GREEN}✓ NAT configured: $WLAN0 → $INTERNET_IF${NC}"

# Step 5: Save iptables rules
echo ""
echo -e "${YELLOW}[6/6] Saving iptables rules...${NC}"
if ! command -v netfilter-persistent &> /dev/null; then
    apt install -y iptables-persistent
fi
netfilter-persistent save
echo -e "${GREEN}✓ Rules saved${NC}"

# Step 6: Configure dnsmasq for hotspot
echo ""
echo -e "${YELLOW}[7/6] Configuring DHCP for hotspot...${NC}"
if ! command -v dnsmasq &> /dev/null; then
    apt install -y dnsmasq
fi

# Create dnsmasq config for hotspot
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/hotspot.conf << EOF
interface=$WLAN0
dhcp-range=10.42.0.2,10.42.0.20,255.255.255.0,24h
dhcp-option=3,10.42.0.1
dhcp-option=6,10.42.0.1
server=8.8.8.8
server=8.8.4.4
EOF

systemctl restart dnsmasq
systemctl enable dnsmasq
echo -e "${GREEN}✓ DHCP configured${NC}"

# Summary
echo ""
echo -e "${GREEN}=========================================="
echo "  Dual WiFi Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Configuration:"
echo "  Hotspot (PiSpot): $WLAN0 at 10.42.0.1"
echo "  Internet: $INTERNET_IF"
echo ""
echo "Next steps:"
if [ "$INTERNET_IF" != "eth0" ]; then
    echo "1. Configure internet WiFi on $INTERNET_IF:"
    echo "   sudo nmcli con add type wifi ifname $INTERNET_IF \\"
    echo "     con-name \"Hospital-WiFi\" \\"
    echo "     wifi.ssid \"YourHospitalSSID\" \\"
    echo "     wifi-sec.key-mgmt wpa-psk \\"
    echo "     wifi-sec.psk \"YourPassword\""
    echo ""
    echo "   sudo nmcli con up \"Hospital-WiFi\""
else
    echo "1. Connect Ethernet cable for internet"
    echo "   (Ethernet should auto-configure via DHCP)"
fi
echo ""
echo "2. Test hotspot:"
echo "   - ESP32 should see 'PiSpot' network"
echo "   - ESP32 should get IP: 10.42.0.x"
echo ""
echo "3. Test internet:"
echo "   ping -c 3 8.8.8.8"
echo ""
echo "4. Verify ESP32 can reach MQTT broker:"
echo "   - ESP32 connects to PiSpot"
echo "   - ESP32 uses MQTT broker: 10.42.0.1"
echo ""

