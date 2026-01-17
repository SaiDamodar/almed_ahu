# Raspberry Pi Network Setup - Single WiFi Mode

## Overview

This guide configures the Raspberry Pi to connect directly to the main WiFi network instead of running a hotspot. Both the ESP32 and Raspberry Pi will connect to the same WiFi network and communicate via MQTT.

**Benefits:**
- Simpler network architecture (no hotspot bridging)
- More reliable connectivity
- ESP32 can reach cloud even if RPi is down
- Easier troubleshooting

## Network Configuration

| Device | Network | IP Address |
|--------|---------|------------|
| WiFi Router | AlMed | Gateway (e.g., 192.168.0.1) |
| Raspberry Pi | AlMed | **192.168.0.100** (static) |
| ESP32 | AlMed | DHCP (dynamic) |

## Prerequisites

- Raspberry Pi with Raspbian/Raspberry Pi OS
- Access to the RPi (SSH, keyboard/monitor, or serial)
- WiFi network: **SSID:** `AlMed` **Password:** `AlMed123456`

---

## Step 1: Disable Hotspot Mode

If the RPi is currently running a hotspot, disable it:

```bash
# Stop and disable hostapd (hotspot service)
sudo systemctl stop hostapd
sudo systemctl disable hostapd

# Stop and disable dnsmasq (DHCP for hotspot)
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq

# Remove hotspot configuration if exists
sudo rm -f /etc/hostapd/hostapd.conf
sudo rm -f /etc/dnsmasq.conf.hotspot
```

---

## Step 2: Configure Static IP for WiFi

Edit the dhcpcd configuration to set a static IP:

```bash
sudo nano /etc/dhcpcd.conf
```

Add or modify these lines at the end of the file:

```
# Static IP for wlan0 on AlMed network
interface wlan0
static ip_address=192.168.0.100/24
static routers=192.168.0.1
static domain_name_servers=192.168.0.1 8.8.8.8
```

**Note:** Adjust `static routers` and `domain_name_servers` to match your router's IP if it's not `192.168.0.1`.

---

## Step 3: Configure WiFi Connection

Edit the wpa_supplicant configuration:

```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```

Ensure it contains:

```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="AlMed"
    psk="AlMed123456"
    key_mgmt=WPA-PSK
    priority=1
}
```

**Note:** Change `country=US` to your country code if needed (e.g., `IN` for India, `GB` for UK).

---

## Step 4: Remove Dual-Network Scripts (if present)

If there are any dual-network or hotspot scripts installed:

```bash
# Check for and remove any custom network scripts
sudo rm -f /etc/network/interfaces.d/hotspot
sudo rm -f /usr/local/bin/setup-dual-wifi.sh
sudo rm -f /etc/systemd/system/hotspot.service

# Reload systemd
sudo systemctl daemon-reload
```

---

## Step 5: Ensure MQTT Broker is Running

The Mosquitto MQTT broker should already be installed. Verify it's running:

```bash
# Check status
sudo systemctl status mosquitto

# If not running, start and enable it
sudo systemctl start mosquitto
sudo systemctl enable mosquitto
```

Verify MQTT configuration allows local connections:

```bash
sudo nano /etc/mosquitto/mosquitto.conf
```

Ensure these lines exist:

```
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
```

The MQTT credentials should already be set:
- **Username:** `almed`
- **Password:** `Almed1234$`

If you need to reset the password:

```bash
sudo mosquitto_passwd -c /etc/mosquitto/passwd almed
# Enter password: Almed1234$
sudo systemctl restart mosquitto
```

---

## Step 6: Reboot and Verify

```bash
sudo reboot
```

After reboot, verify the configuration:

```bash
# Check IP address (should show 192.168.1.100)
ip addr show wlan0

# Check WiFi connection
iwconfig wlan0

# Test internet connectivity
ping -c 3 google.com

# Check MQTT broker is running
sudo systemctl status mosquitto

# Test MQTT locally
mosquitto_sub -h localhost -u almed -P 'Almed1234$' -t 'test' &
mosquitto_pub -h localhost -u almed -P 'Almed1234$' -t 'test' -m 'hello'
```

---

## Step 7: Verify ESP32 Connection

Once the RPi is configured, the ESP32 should automatically connect:

1. ESP32 connects to `AlMed` WiFi
2. ESP32 connects to MQTT broker at `192.168.0.100:1883`
3. ESP32 connects to AWS IoT cloud (independent of RPi)

Check the ESP32 Serial Monitor for:
```
📡 WiFi: Connecting to 'AlMed' (non-blocking)
✓ WiFi Connected: 192.168.1.xxx
✓ Local MQTT connected
```

---

## Troubleshooting

### ESP32 can't connect to MQTT broker

1. Verify RPi has IP `192.168.0.100`:
   ```bash
   ip addr show wlan0
   ```

2. Verify MQTT is listening:
   ```bash
   sudo netstat -tlnp | grep 1883
   ```

3. Check firewall (if enabled):
   ```bash
   sudo ufw status
   sudo ufw allow 1883/tcp
   ```

### WiFi won't connect

1. Check wpa_supplicant syntax:
   ```bash
   sudo wpa_cli -i wlan0 reconfigure
   ```

2. View connection logs:
   ```bash
   journalctl -u wpa_supplicant -f
   ```

### IP address conflict

If another device has `192.168.0.100`, choose a different static IP:
- Update NetworkManager connection on RPi
- Update ESP32 code: `mqttHost = "192.168.0.NEW_IP"`
- Or use MQTT provisioning to update broker IP dynamically

---

## MQTT Topics (Unchanged)

The MQTT topic structure remains the same:

| Topic | Purpose |
|-------|---------|
| `almed/{site}/{room}/{ahu}/telemetry` | Sensor data from ESP32 |
| `almed/{site}/{room}/{ahu}/state` | System state |
| `almed/{site}/{room}/{ahu}/cmd` | Commands to ESP32 |
| `almed/{site}/{room}/{ahu}/log` | System logs |

---

## What NOT to Change

- **DO NOT modify** the `ahu_dashboard/` folder - the Flutter dashboard runs on the RPi display
- **DO NOT change** MQTT credentials (almed / Almed1234$)
- **DO NOT change** MQTT port (1883)
- **DO NOT remove** Mosquitto broker

---

## Summary of Changes

| Component | Before (Hotspot Mode) | After (Single WiFi) |
|-----------|----------------------|---------------------|
| RPi Network | Hotspot (10.42.0.1) + Bridge to main WiFi | Direct WiFi (192.168.0.100) |
| ESP32 Network | Connect to RPi hotspot | Connect to AlMed WiFi |
| MQTT Broker | 10.42.0.1:1883 | 192.168.0.100:1883 |
| Cloud Access | Via RPi bridge | Direct from ESP32 |
| Reliability | Dependent on bridge | Independent |
