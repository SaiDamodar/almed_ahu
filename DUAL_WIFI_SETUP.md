# Dual WiFi Setup for Raspberry Pi 4

This guide shows how to configure Raspberry Pi 4 with **dual WiFi**:
- **One WiFi interface**: Hotspot (PiSpot) for ESP32 devices
- **Another WiFi interface**: Internet connection (hospital network)

---

## Configuration Options

### Option 1: Built-in WiFi (Hotspot) + USB WiFi (Internet) ⭐ Recommended
- **wlan0** (Built-in): PiSpot hotspot (10.42.0.1)
- **wlan1** (USB adapter): Hospital WiFi for internet

### Option 2: Built-in WiFi (Hotspot) + Ethernet (Internet)
- **wlan0** (Built-in): PiSpot hotspot (10.42.0.1)
- **eth0** (Ethernet): Hospital network for internet

### Option 3: USB WiFi (Hotspot) + Built-in WiFi (Internet)
- **wlan0** (USB adapter): PiSpot hotspot (10.42.0.1)
- **wlan1** (Built-in): Hospital WiFi for internet

---

## Setup: Option 1 (Built-in WiFi Hotspot + USB WiFi Internet)

### Step 1: Install USB WiFi Adapter

1. Plug in USB WiFi adapter
2. Check if detected:
   ```bash
   lsusb
   ip link show
   ```
3. You should see both `wlan0` and `wlan1`

### Step 2: Configure Built-in WiFi as Hotspot (wlan0)

```bash
# Run the hotspot setup script
sudo bash fix-hotspot.sh
```

This configures `wlan0` as PiSpot hotspot with IP `10.42.0.1`

### Step 3: Configure USB WiFi for Internet (wlan1)

```bash
# Create NetworkManager connection for hospital WiFi
sudo nmcli con add type wifi ifname wlan1 \
  con-name "Hospital-WiFi" \
  wifi.ssid "HospitalNetwork" \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "hospital-password"

# Set to auto-connect
sudo nmcli con modify "Hospital-WiFi" connection.autoconnect yes

# Connect
sudo nmcli con up "Hospital-WiFi"
```

### Step 4: Enable IP Forwarding and NAT

```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf

# Configure NAT (share internet from wlan1 to wlan0)
sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o wlan1 -j ACCEPT

# Save iptables rules
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

### Step 5: Configure DHCP for Hotspot Clients

```bash
# Install dnsmasq if not installed
sudo apt install dnsmasq

# Configure dnsmasq for hotspot
sudo tee /etc/dnsmasq.d/hotspot.conf << EOF
interface=wlan0
dhcp-range=10.42.0.2,10.42.0.20,255.255.255.0,24h
dhcp-option=3,10.42.0.1
dhcp-option=6,10.42.0.1
server=8.8.8.8
server=8.8.4.4
EOF

# Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq
```

---

## Setup: Option 2 (Built-in WiFi Hotspot + Ethernet Internet)

### Step 1: Configure Built-in WiFi as Hotspot

```bash
sudo bash fix-hotspot.sh
```

### Step 2: Configure Ethernet for Internet

```bash
# Create NetworkManager connection for Ethernet
sudo nmcli con add type ethernet ifname eth0 \
  con-name "Ethernet-Internet" \
  ipv4.method auto

# Set to auto-connect
sudo nmcli con modify "Ethernet-Internet" connection.autoconnect yes

# Connect
sudo nmcli con up "Ethernet-Internet"
```

### Step 3: Enable IP Forwarding and NAT

```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf

# Configure NAT (share internet from eth0 to wlan0)
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# Save iptables rules
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

---

## Verification

### Check Hotspot Status
```bash
# Check hostapd
sudo systemctl status hostapd

# Check hotspot IP
ip addr show wlan0
# Should show: 10.42.0.1/24

# Check if ESP32 can connect
# ESP32 should see "PiSpot" network
```

### Check Internet Connection
```bash
# Check internet interface
ip addr show wlan1  # or eth0

# Test internet connectivity
ping -c 3 8.8.8.8

# Check routing
ip route show
```

### Test ESP32 Connection
```bash
# ESP32 should connect to PiSpot (wlan0)
# ESP32 should get IP: 10.42.0.x
# ESP32 should be able to reach MQTT broker at 10.42.0.1

# Check connected clients
iw dev wlan0 station dump
```

---

## Network Diagram

```
┌─────────────────────────────────────┐
│      Raspberry Pi 4                 │
│                                     │
│  ┌──────────────┐  ┌─────────────┐ │
│  │   wlan0      │  │   wlan1     │ │
│  │  (Hotspot)   │  │  (Internet) │ │
│  │  10.42.0.1   │  │  DHCP/auto  │ │
│  └──────┬───────┘  └──────┬──────┘ │
│         │                 │         │
└─────────┼─────────────────┼─────────┘
          │                 │
          │                 │
    ┌─────▼─────┐    ┌─────▼─────┐
    │  ESP32    │    │  Hospital │
    │  Devices  │    │   WiFi    │
    │           │    │  Network  │
    └───────────┘    └───────────┘
```

---

## Troubleshooting

### Issue: USB WiFi Not Detected
```bash
# Check USB devices
lsusb

# Check kernel modules
lsmod | grep -i wifi

# Load driver if needed
sudo modprobe rtl8812au  # Example for RTL8812AU adapter
```

### Issue: Hotspot Not Working
```bash
# Restart hotspot
sudo systemctl restart hostapd

# Check logs
sudo journalctl -u hostapd -f
```

### Issue: No Internet on Hotspot Clients
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward
# Should be: 1

# Check iptables rules
sudo iptables -t nat -L -n -v
sudo iptables -L FORWARD -n -v

# Test connectivity
ping -I wlan0 8.8.8.8
```

### Issue: Both WiFi Interfaces Conflict
```bash
# Ensure NetworkManager doesn't manage wlan0
sudo nmcli dev set wlan0 managed no

# Or disable NetworkManager for wlan0
sudo nmcli connection delete "Hotspot" 2>/dev/null || true
```

---

## Quick Setup Script

Save as `setup-dual-wifi.sh`:

```bash
#!/bin/bash
set -e

echo "Setting up dual WiFi on Raspberry Pi 4..."

# Detect interfaces
WLAN0=$(ip link show | grep -oP '^[0-9]+: wlan\d+' | head -1 | awk '{print $2}' || echo "wlan0")
WLAN1=$(ip link show | grep -oP '^[0-9]+: wlan\d+' | tail -1 | awk '{print $2}' || echo "wlan1")

echo "Detected interfaces:"
echo "  Hotspot (wlan0): $WLAN0"
echo "  Internet (wlan1): $WLAN1"

# Setup hotspot on wlan0
echo "Setting up hotspot on $WLAN0..."
sudo bash fix-hotspot.sh

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf

# Configure NAT
echo "Configuring NAT..."
if [ "$WLAN1" != "$WLAN0" ]; then
    sudo iptables -t nat -A POSTROUTING -o $WLAN1 -j MASQUERADE
    sudo iptables -A FORWARD -i $WLAN0 -o $WLAN1 -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A FORWARD -i $WLAN0 -o $WLAN1 -j ACCEPT
    echo "✓ NAT configured: $WLAN0 → $WLAN1"
else
    echo "⚠️ Only one WiFi interface detected. Using Ethernet for internet."
    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    sudo iptables -A FORWARD -i $WLAN0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A FORWARD -i $WLAN0 -o eth0 -j ACCEPT
    echo "✓ NAT configured: $WLAN0 → eth0"
fi

# Save iptables
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

echo ""
echo "✓ Dual WiFi setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure internet WiFi: sudo nmcli con add type wifi ifname $WLAN1 ..."
echo "2. Test hotspot: ESP32 should see 'PiSpot' network"
echo "3. Test internet: ping -c 3 8.8.8.8"
```

---

## Benefits of Dual WiFi

✅ **Hotspot Always Available**: ESP32 devices can always connect to PiSpot
✅ **Internet Access**: Pi can access internet for updates, cloud services
✅ **Isolated Network**: ESP32 devices on separate network (10.42.0.x)
✅ **No Conflicts**: Each WiFi interface has dedicated purpose
✅ **Reliable**: Hotspot doesn't depend on internet connection

---

## ESP32 Configuration

ESP32 code already supports this setup:
- **Primary WiFi**: PiSpot (10.42.0.1) - for MQTT
- **Secondary WiFi**: Hospital network (optional) - for AWS IoT

ESP32 will:
1. Connect to PiSpot hotspot
2. Use MQTT broker at 10.42.0.1
3. Optionally connect to hospital WiFi for AWS IoT (if online mode enabled)

---

**Note**: This setup works on Raspberry Pi 4 with any combination:
- Built-in WiFi + USB WiFi
- Built-in WiFi + Ethernet
- USB WiFi + Built-in WiFi

