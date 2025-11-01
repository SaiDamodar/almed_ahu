# 🚀 Raspberry Pi Automated Setup Script

## New Feature: One-Click Setup!

You now have a **fully automated setup script** that installs and configures everything for your ALMED AHU Raspberry Pi system!

---

## What This Does

The script `setup_rpi_almed_ahu.sh` automatically:

✅ **System Setup**
- Updates all packages
- Installs essential build tools and dependencies
- Configures graphics libraries for Flutter

✅ **Flutter Environment**
- Downloads and installs Flutter SDK 3.24.5
- Clones, builds, and installs Flutter-Pi
- Sets up all required paths

✅ **MQTT Broker**
- Installs Mosquitto MQTT broker
- Configures authentication (user: `almed`, pass: `Almed1234$`)
- Sets up logging and persistence
- Starts and enables the service

✅ **WiFi Hotspot**
- Configures hostapd for PiSpot network
- Sets up static IP (10.42.0.1)
- Configures DHCP server

✅ **MQTT Bridge**
- Installs Python MQTT libraries
- Sets up bridge script to HiveMQ Cloud
- Creates systemd service

✅ **Dashboard Service**
- Creates kiosk mode startup script
- Configures systemd auto-start service
- Sets up display management

✅ **System Optimization**
- Disables unnecessary services
- Configures firewall rules
- Sets up hardware watchdog
- Creates detailed summary report

---

## Quick Start

### 1. Transfer Script to Raspberry Pi

**Option A: Git Clone (Easiest)**
```bash
# On Raspberry Pi:
git clone <your-repo> almed_ahu
cd almed_ahu
chmod +x setup_rpi_almed_ahu.sh
sudo bash setup_rpi_almed_ahu.sh
```

**Option B: SCP from Windows**
```powershell
# From Windows:
scp setup_rpi_almed_ahu.sh pi@raspberrypi.local:~/
scp mqtt_bridge.py pi@raspberrypi.local:~/
scp mqtt-bridge.service pi@raspberrypi.local:~/

# Then SSH and run:
ssh pi@raspberrypi.local
chmod +x ~/setup_rpi_almed_ahu.sh
sudo bash ~/setup_rpi_almed_ahu.sh
```

### 2. Run the Script

```bash
cd ~/almed_ahu  # or wherever you put it
sudo bash setup_rpi_almed_ahu.sh
```

That's it! The script does everything automatically.

**Time: 15-30 minutes** (depending on internet speed)

---

## What You Get

After the script completes:

### Installed Components

| Component | Version | Location |
|-----------|---------|----------|
| Flutter SDK | 3.24.5 | `/home/pi/flutter` |
| Flutter-Pi | Latest | `/usr/local/bin/flutter-pi` |
| Mosquitto | Latest | System-wide |
| Python MQTT | Latest | System Python3 |

### Configured Services

| Service | Status | Purpose |
|---------|--------|---------|
| `mosquitto.service` | Running | MQTT Broker on port 1883 |
| `ahu-dashboard.service` | Created* | Dashboard kiosk mode |
| `mqtt-bridge.service` | Created* | Cloud bridge to HiveMQ |
| `hostapd.service` | Enabled | WiFi hotspot (PiSpot) |

*Services are created but not enabled yet (you enable after deploying app)

### Credentials

- **MQTT**: `almed` / `Almed1234$`
- **Hotspot**: `PiSpot` / `12345678`
- **Bridge**: Configure in `mqtt_bridge.py`

---

## After Script Completes

### Required Manual Steps

1. **Set GPU Memory Split**
   ```bash
   sudo raspi-config
   # Advanced Options → Memory Split → 128
   ```

2. **Deploy Flutter App**
   ```bash
   # Build on your dev machine:
   cd ahu_dashboard
   flutter build linux --release --target-platform linux-arm64
   
   # Copy to Pi:
   scp -r build/linux/arm64/release/bundle pi@raspberrypi.local:/opt/ahu_dashboard/
   ```

3. **Enable Services**
   ```bash
   # Dashboard:
   sudo systemctl enable ahu-dashboard.service
   sudo systemctl start ahu-dashboard.service
   
   # Bridge (optional):
   sudo nano ~/Documents/almed_ahu/mqtt_bridge.py  # Edit config
   sudo systemctl enable mqtt-bridge.service
   sudo systemctl start mqtt-bridge.service
   ```

4. **Reboot**
   ```bash
   sudo reboot
   ```

---

## Testing

### Test MQTT Broker
```bash
# Publish:
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "test" -m "hello"

# Subscribe:
mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "almed/#" -v
```

### Test Services
```bash
# Check status:
sudo systemctl status mosquitto
sudo systemctl status ahu-dashboard.service
sudo systemctl status mqtt-bridge.service

# View logs:
sudo journalctl -u mosquitto -f
sudo journalctl -u ahu-dashboard.service -f
```

### Test Hotspot
- Connect to `PiSpot` from another device
- Password: `12345678`
- IP should be 10.42.0.x

---

## Documentation Files

You have detailed guides:

1. **USAGE_SETUP_SCRIPT.md** 📖
   - How to transfer and run the script
   - Troubleshooting tips
   - Verification commands

2. **SETUP_RPI_GUIDE.md** 📋
   - Complete setup instructions
   - Post-installation steps
   - Service configuration
   - Troubleshooting

3. **ALMED_SETUP_SUMMARY.txt** ✅
   - Generated automatically after script runs
   - Complete installation log
   - All credentials and paths
   - Next steps reminder

---

## Troubleshooting

### Script Won't Run

```bash
# Make sure it's executable:
chmod +x setup_rpi_almed_ahu.sh

# Run with sudo:
sudo bash setup_rpi_almed_ahu.sh
```

### Flutter Download Fails

Check internet connection:
```bash
ping google.com
```

### Build Errors

Check dependencies:
```bash
sudo apt install -y git curl wget build-essential cmake
```

### MQTT Not Working

```bash
# Restart Mosquitto:
sudo systemctl restart mosquitto

# Check logs:
sudo journalctl -u mosquitto -f
```

---

## Benefits

### Before
❌ Manual installation of 20+ packages  
❌ Complex configuration steps  
❌ Easy to miss dependencies  
❌ Hours of setup time  
❌ Error-prone process  

### After
✅ One command to run  
✅ Automatic dependency resolution  
✅ Idempotent (safe to rerun)  
✅ 15-30 minute setup time  
✅ Professional configuration  

---

## Script Features

- ✅ **Error Handling**: Exits immediately on any error
- ✅ **Progress Tracking**: Shows what's happening at each step
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Colored Output**: Easy to read status messages
- ✅ **Summary Report**: Complete log of what was installed
- ✅ **Dry Run Ready**: Check what will be installed first

---

## File Structure

```
almed_ahu/
├── setup_rpi_almed_ahu.sh          # ← Main setup script
├── USAGE_SETUP_SCRIPT.md            # How to use it
├── SETUP_RPI_GUIDE.md               # Detailed guide
├── SETUP_SCRIPT_README.md           # This file!
├── mqtt_bridge.py                   # Bridge script (copied to Pi)
├── mqtt-bridge.service              # Bridge service (copied to Pi)
├── esp32_main/
│   └── esp32_main.ino               # ESP32 code
└── ahu_dashboard/
    └── ...                          # Flutter dashboard app
```

---

## Summary

You now have a **production-ready automated setup** for deploying your ALMED AHU system to any Raspberry Pi!

**Just run one script, wait 15-30 minutes, and you have:**
- ✅ Complete Flutter development environment
- ✅ Working MQTT broker
- ✅ WiFi hotspot
- ✅ Cloud bridge setup
- ✅ Dashboard kiosk mode
- ✅ All services configured

**Ready for deployment!** 🚀

---

## Next Steps

1. Read `USAGE_SETUP_SCRIPT.md` for detailed instructions
2. Transfer script to your Raspberry Pi
3. Run the setup script
4. Follow the post-installation steps
5. Deploy your Flutter app
6. Test everything!

---

**Questions? Check the documentation files or service logs!**

