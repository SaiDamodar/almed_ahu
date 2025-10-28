# Raspberry Pi Hotspot Stability Fix

## Problem
The Broadcom WiFi hotspot "snorlax" keeps disconnecting when multiple ESP32 devices attempt to connect.

## Solutions (Pick One)

### Solution 1: Optimize hostapd Configuration (Recommended First Try)

**First, check if hostapd is installed and find config location:**

```bash
# Check if hostapd is installed
which hostapd

# Find config file location
sudo find /etc -name "*hostapd*.conf" 2>/dev/null
sudo find / -name "hostapd.conf" 2>/dev/null | grep -v proc

# Check if using systemd-networkd instead
cat /etc/systemd/network/*.conf | grep -i hotspot

# Check running hotspot process
ps aux | grep -i hostapd
ps aux | grep -i create_ap
```

**If hostapd is NOT installed:**

```bash
# Install hostapd
sudo apt update
sudo apt install hostapd dnsmasq

# Create config directory
sudo mkdir -p /etc/hostapd

# Create config file
sudo nano /etc/hostapd/hostapd.conf
```

**If file doesn't exist, create it:**
```bash
sudo nano /etc/hostapd/hostapd.conf
```

**Note:** If your hotspot was set up via `raspi-config` or another method, the config might be in:
- `/boot/config.txt` (for built-in WiFi)
- `/etc/network/interfaces`
- `/etc/wpa_supplicant/wpa_supplicant.conf`
- Or use `create_ap` script

**After creating/editing config, enable hostapd:**
```bash
# Tell systemd where config is
sudo nano /etc/default/hostapd
# Add line: DAEMON_CONF="/etc/hostapd/hostapd.conf"

# If service is masked (disabled), unmask it first
sudo systemctl unmask hostapd

# Enable service
sudo systemctl enable hostapd

# Start service
sudo systemctl start hostapd
```

**Apply these settings:**
```ini
# Basic settings
interface=wlan0
driver=nl80211
ssid=snorlax
hw_mode=g
channel=6
wmm_enabled=1

# Multiple client support
max_num_sta=10
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
# Increase ACK timeout for slow connections
beacon_int=100
dtim_period=2

# Rate limiting (prevent overload)
tx_queue_data0_prio=3
tx_queue_data1_prio=2
tx_queue_data2_prio=1
tx_queue_data3_prio=0

# No disconnect on association errors
disassoc_low_ack=0
```

**Restart hostapd:**
```bash
# If you get "masked" error, unmask first
sudo systemctl unmask hostapd

# Then restart
sudo systemctl restart hostapd

# Check status
sudo systemctl status hostapd
```

**If restart fails, troubleshoot:**

```bash
# 1. Check the error details
sudo journalctl -xeu hostapd.service --no-pager | tail -30

# 2. Verify config file path in /etc/default/hostapd
cat /etc/default/hostapd
# Should have: DAEMON_CONF="/etc/hostapd/hostapd.conf"

# 3. Check if interface exists
ip link show wlan0
# If not found, check available interfaces:
ip link show

# 4. Test config file syntax
sudo hostapd -dd /etc/hostapd/hostapd.conf
# Press Ctrl+C after seeing errors

# 5. Check if NetworkManager is conflicting
sudo systemctl stop NetworkManager
sudo systemctl restart hostapd
# If it works, disable NetworkManager managing WiFi:
sudo systemctl disable NetworkManager

# 6. Check if interface is already in use
sudo iwconfig wlan0
# If it shows "Access Point: Not-Associated", it's available

# 7. For Broadcom built-in WiFi, try different driver:
# In hostapd.conf, try changing:
# driver=nl80211  →  driver=broadcom  or  driver=none

# 8. Make sure interface is up
sudo ip link set wlan0 up
```

**Common fixes:**

**Issue: "Could not configure driver mode" or "nl80211: Driver does not support"**
```bash
# For Raspberry Pi built-in WiFi, try:
sudo nano /etc/hostapd/hostapd.conf
# Change: driver=nl80211
# To: driver=broadcom
# Or: driver=none  (if using AP mode via wpa_supplicant)
```

**Issue: "Interface not found"**
```bash
# Check actual interface name
ls /sys/class/net/
# Update hostapd.conf with correct interface (might be wlan1, wlx..., etc.)
```

**Issue: NetworkManager conflict**
```bash
# Stop NetworkManager
sudo systemctl stop NetworkManager
sudo systemctl disable NetworkManager

# Configure wlan0 manually
sudo nano /etc/network/interfaces
# Add:
# allow-hotplug wlan0
# iface wlan0 inet static
#     address 10.42.0.1
#     netmask 255.255.255.0

# Restart networking
sudo systemctl restart networking
sudo systemctl restart hostapd
```

---

### Solution 2: Use Dedicated USB WiFi Adapter (Most Reliable)

**Why:** Built-in Broadcom WiFi is shared with other functions and can be unstable.

**Steps:**

1. **Buy a USB WiFi adapter** (check Raspberry Pi compatibility)
   - Recommended: TP-Link TL-WN725N or similar

2. **Install and configure:**
```bash
# Check available WiFi adapters
iwconfig

# Configure wlan1 (USB adapter) for hotspot
sudo nano /etc/hostapd/hostapd.conf
# Change: interface=wlan1
```

3. **Use wlan1 for hotspot, wlan0 for connecting to hospital WiFi**

---

### Solution 3: Increase Connection Limits

Edit `/etc/hostapd/hostapd.conf`:

```ini
# Increase max clients
max_num_sta=20

# Allow more connection attempts
# In /etc/default/hostapd, add:
DAEMON_OPTS="-B -P /run/hostapd.pid"
```

---

### Solution 4: Reduce Connection Retry Rate on ESP32

**On ESP32 side** - increase backoff time:

```cpp
const unsigned long WIFI_BACKOFF_MS = 5000;  // Increase from 2000 to 5000
```

This prevents ESP32s from hammering the hotspot.

---

### Solution 5: System-Level Tweaks

**1. Increase WiFi power (if using external adapter):**
```bash
sudo iwconfig wlan0 txpower 20
```

**2. Disable WiFi power saving:**
```bash
sudo iw dev wlan0 set power_save off
```

**3. Increase network buffers:**
Add to `/etc/sysctl.conf`:
```bash
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

Apply:
```bash
sudo sysctl -p
```

---

### Solution 6: Monitor and Auto-Restart

Create a watchdog script:

```bash
sudo nano /usr/local/bin/hotspot-watchdog.sh
```

```bash
#!/bin/bash
while true; do
    if ! ping -c 1 10.42.0.1 &> /dev/null; then
        echo "Hotspot down, restarting..."
        sudo systemctl restart hostapd
        sleep 10
    fi
    sleep 30
done
```

Make executable:
```bash
sudo chmod +x /usr/local/bin/hotspot-watchdog.sh
```

Run as service:
```bash
sudo nano /etc/systemd/system/hotspot-watchdog.service
```

```ini
[Unit]
Description=Hotspot Watchdog
After=network.target

[Service]
ExecStart=/usr/local/bin/hotspot-watchdog.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl enable hotspot-watchdog
sudo systemctl start hotspot-watchdog
```

---

## Recommended Approach

1. **Try Solution 1** first (hostapd config)
2. If still unstable → **Solution 2** (dedicated USB adapter) - most reliable
3. Add **Solution 6** (watchdog) as backup

---

## Verify Stability

```bash
# Check connected devices
hostapd_cli all_sta

# Monitor logs
sudo journalctl -u hostapd -f

# Check WiFi status
iwconfig wlan0
```

