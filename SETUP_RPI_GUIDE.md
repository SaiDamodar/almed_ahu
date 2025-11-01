# ALMED AHU Raspberry Pi Setup Guide

## Quick Setup Instructions

This guide will help you set up a new Raspberry Pi for the ALMED AHU system automatically.

---

## Prerequisites

Before running the script, ensure you have:

- ✅ Raspberry Pi (4B recommended, 4GB+ RAM)
- ✅ Raspberry Pi OS (64-bit) installed on SD card
- ✅ SSH enabled or direct access to the Pi
- ✅ Internet connection
- ✅ Root/sudo access

---

## Installation Steps

### Step 1: Transfer Script to Raspberry Pi

**Option A: Using Git (Recommended)**
```bash
# On the Raspberry Pi:
cd ~
git clone <your-repo-url> almed_ahu
cd almed_ahu
```

**Option B: Using SCP from Windows**
```powershell
# From Windows PowerShell:
scp setup_rpi_almed_ahu.sh pi@raspberrypi.local:~
```

**Option C: Copy via USB**
```bash
# Just copy the file to the Pi using a USB drive
```

### Step 2: Run the Setup Script

```bash
# On the Raspberry Pi:
cd ~/almed_ahu  # or wherever you put the script
chmod +x setup_rpi_almed_ahu.sh
sudo bash setup_rpi_almed_ahu.sh
```

The script will:
1. ✅ Update your system
2. ✅ Install Flutter SDK
3. ✅ Install and build Flutter-Pi
4. ✅ Setup Mosquitto MQTT broker
5. ✅ Configure WiFi hotspot
6. ✅ Setup MQTT bridge service
7. ✅ Install all dependencies
8. ✅ Configure firewall
9. ✅ Create kiosk mode services

**Estimated time: 15-30 minutes** (depending on internet speed)

---

## What Gets Installed

| Component | Purpose | Location |
|-----------|---------|----------|
| **Flutter SDK** | Flutter app framework | `/home/pi/flutter` |
| **Flutter-Pi** | Runs Flutter apps on Pi | `/usr/local/bin` |
| **Mosquitto** | MQTT broker | `/etc/mosquitto/` |
| **MQTT Bridge** | Pi ↔ HiveMQ Cloud | `/home/pi/Documents/almed_ahu/` |
| **WiFi Hotspot** | PiSpot network | `/etc/hostapd/` |
| **Dashboard Service** | Kiosk mode auto-start | `/etc/systemd/system/` |

---

## Configuration

### MQTT Credentials

The script sets up Mosquitto with these default credentials:

- **Username**: `almed`
- **Password**: `Almed1234$`
- **Port**: `1883`
- **Host**: `127.0.0.1` (localhost) or `10.42.0.1` (hotspot IP)

### WiFi Hotspot

- **SSID**: `PiSpot`
- **Password**: `12345678`
- **IP Address**: `10.42.0.1`

---

## Post-Installation Steps

### 1. Configure GPU Memory Split

```bash
sudo raspi-config
```

Navigate to:
- **Advanced Options** → **Memory Split** → **128**

This improves performance for the dashboard.

### 2. Deploy Your Flutter App

Build your Flutter app on your development machine:

```bash
cd ahu_dashboard
flutter build linux --release --target-platform linux-arm64
```

Copy to Raspberry Pi:

```bash
# From Windows:
scp -r build/linux/arm64/release/bundle pi@raspberrypi.local:/opt/ahu_dashboard/

# Or use SFTP client like FileZilla
```

### 3. Enable Dashboard Service

```bash
sudo systemctl enable ahu-dashboard.service
sudo systemctl start ahu-dashboard.service
```

### 4. (Optional) Configure MQTT Bridge to Cloud

Edit the bridge configuration:

```bash
sudo nano /home/pi/Documents/almed_ahu/mqtt_bridge.py
```

Update these variables:
```python
CLOUD_BROKER = "your-cluster.s1.eu.hivemq.cloud"
CLOUD_USER = "almed"
CLOUD_PASS = "your-password"
```

Enable and start the bridge:

```bash
sudo systemctl enable mqtt-bridge.service
sudo systemctl start mqtt-bridge.service
```

### 5. Reboot

```bash
sudo reboot
```

---

## Testing

### Test MQTT Broker

Publish a test message:
```bash
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "almed/test" -m "Hello MQTT"
```

Subscribe to messages:
```bash
mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "almed/#" -v
```

### Test Dashboard

Check if dashboard is running:
```bash
sudo systemctl status ahu-dashboard.service
```

View dashboard logs:
```bash
sudo journalctl -u ahu-dashboard.service -f
```

### Test Hotspot

Connect to `PiSpot` network with password `12345678` from another device.

---

## Troubleshooting

### Mosquitto Not Starting

```bash
# Check status
sudo systemctl status mosquitto

# View logs
sudo journalctl -u mosquitto -f

# Restart service
sudo systemctl restart mosquitto
```

### Dashboard Won't Start

```bash
# Check Flutter-Pi installation
flutter-pi --version

# Check app bundle
ls -la /opt/ahu_dashboard/

# View logs
sudo journalctl -u ahu-dashboard.service -n 50
```

### Hotspot Not Working

```bash
# Check hostapd status
sudo systemctl status hostapd

# Restart hotspot
sudo systemctl restart hostapd

# Check WiFi interface
iwconfig wlan0
```

### Flutter Not Found

```bash
# Source profile
source /etc/profile.d/flutter.sh

# Or add to ~/.bashrc permanently
echo 'export PATH="$PATH:/home/pi/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

---

## Complete Setup Summary

After installation, you'll have:

```
Raspberry Pi System
├── Flutter SDK (3.24.5)
├── Flutter-Pi
├── Mosquitto MQTT Broker
│   ├── Port: 1883
│   ├── User: almed / Pass: Almed1234$
│   └── Config: /etc/mosquitto/conf.d/almed.conf
├── WiFi Hotspot
│   ├── SSID: PiSpot
│   ├── Pass: 12345678
│   └── IP: 10.42.0.1
├── MQTT Bridge Service
│   └── Config: /home/pi/Documents/almed_ahu/mqtt_bridge.py
└── Dashboard Service
    └── App: /opt/ahu_dashboard/
```

---

## Next Steps

1. ✅ **Flash ESP32**: Upload `esp32_main.ino` to your ESP32 devices
2. ✅ **Deploy Dashboard**: Build and copy Flutter app to `/opt/ahu_dashboard/`
3. ✅ **Test Connection**: Verify ESP32 connects to Mosquitto
4. ✅ **Enable Services**: Start dashboard and bridge services
5. ✅ **Monitor**: Use `journalctl` to monitor all services

---

## Reference

- **Setup Summary**: `/home/pi/ALMED_SETUP_SUMMARY.txt`
- **MQTT Config**: `/etc/mosquitto/conf.d/almed.conf`
- **Hotspot Config**: `/etc/hostapd/hostapd.conf`
- **Bridge Script**: `/home/pi/Documents/almed_ahu/mqtt_bridge.py`
- **Dashboard App**: `/opt/ahu_dashboard/`

---

## Support

For issues or questions:

1. Check `/home/pi/ALMED_SETUP_SUMMARY.txt` for detailed info
2. Check service logs: `sudo journalctl -u <service-name> -f`
3. Verify network: `ping 10.42.0.1`
4. Test MQTT: use `mosquitto_pub` and `mosquitto_sub` commands

---

**Ready to deploy! Your Raspberry Pi is now configured for the ALMED AHU system.** 🚀

