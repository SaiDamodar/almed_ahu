# Raspberry Pi Hotspot Stability Fix

## Problem
The Broadcom WiFi hotspot "snorlax" keeps disconnecting when multiple ESP32 devices attempt to connect.

## Solutions (Pick One)

### Solution 1: Optimize hostapd Configuration (Recommended First Try)

Edit `/etc/hostapd/hostapd.conf`:

```bash
sudo nano /etc/hostapd/hostapd.conf
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

