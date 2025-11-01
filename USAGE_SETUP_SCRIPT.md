# How to Use the Setup Script

## Quick Start

You now have an automated setup script: `setup_rpi_almed_ahu.sh`

This script will **automatically install and configure everything** needed for your ALMED AHU Raspberry Pi system.

---

## How to Transfer to Raspberry Pi

### Option 1: Using Git (Easiest)

```bash
# On your Raspberry Pi:
cd ~
git clone <your-repository-url> almed_ahu
cd almed_ahu
chmod +x setup_rpi_almed_ahu.sh
sudo bash setup_rpi_almed_ahu.sh
```

### Option 2: Using SCP from Windows

```powershell
# From Windows PowerShell:
# First, make sure you have SSH access to your Pi

# Copy the script:
scp setup_rpi_almed_ahu.sh pi@raspberrypi.local:~/

# Copy other needed files:
scp mqtt_bridge.py pi@raspberrypi.local:~/Documents/almed_ahu/
scp mqtt-bridge.service pi@raspberrypi.local:~/Documents/almed_ahu/

# Then SSH into Pi and run:
ssh pi@raspberrypi.local
chmod +x setup_rpi_almed_ahu.sh
sudo bash setup_rpi_almed_ahu.sh
```

### Option 3: Using USB Drive

1. Copy `setup_rpi_almed_ahu.sh` to a USB drive
2. Plug USB into Raspberry Pi
3. Mount the drive:
   ```bash
   sudo mkdir /mnt/usb
   sudo mount /dev/sda1 /mnt/usb  # Adjust device if needed
   cp /mnt/usb/setup_rpi_almed_ahu.sh ~/
   chmod +x ~/setup_rpi_almed_ahu.sh
   sudo bash ~/setup_rpi_almed_ahu.sh
   ```

### Option 4: Copy-Paste via SSH

If you have SSH access, you can copy the script content and create it directly:

```bash
# On Raspberry Pi:
nano ~/setup_rpi_almed_ahu.sh
# Paste the entire script content
# Press Ctrl+O to save, Ctrl+X to exit
chmod +x ~/setup_rpi_almed_ahu.sh
sudo bash ~/setup_rpi_almed_ahu.sh
```

---

## Running the Script

Once the script is on your Raspberry Pi:

```bash
# Make it executable (if not already):
chmod +x setup_rpi_almed_ahu.sh

# Run with sudo:
sudo bash setup_rpi_almed_ahu.sh
```

The script will:
1. ✅ Ask for confirmation to proceed
2. ✅ Install all dependencies automatically
3. ✅ Configure MQTT, Flutter, hotspot, etc.
4. ✅ Create all necessary services
5. ✅ Generate a summary file

**Time: 15-30 minutes** (depending on internet speed)

---

## What the Script Installs

### 1. System Updates
- Updates all packages
- Installs essential build tools

### 2. Flutter SDK (Version 3.24.5)
- Downloads from official source
- Installs to `/home/pi/flutter`
- Adds to system PATH

### 3. Flutter-Pi
- Clones from GitHub
- Builds from source (takes 5-10 min)
- Installs system-wide

### 4. Mosquitto MQTT Broker
- Installs MQTT broker
- Configures authentication
  - Username: `almed`
  - Password: `Almed1234$`
- Starts and enables service

### 5. WiFi Hotspot
- Configures hostapd
- Sets up PiSpot (password: 12345678)
- Static IP: 10.42.0.1

### 6. MQTT Bridge Setup
- Installs Python MQTT libraries
- Copies bridge script (if present)
- Creates systemd service

### 7. Dashboard Service
- Creates kiosk mode script
- Configures systemd service
- Ready for your Flutter app

### 8. System Optimization
- Disables unnecessary services
- Configures firewall
- Sets up hardware watchdog

---

## After Script Completes

### Check the Summary

The script creates a summary file:
```bash
cat ~/ALMED_SETUP_SUMMARY.txt
```

### Manual Steps Required

The script does NOT do these automatically (requires interaction):

1. **GPU Memory Split**
   ```bash
   sudo raspi-config
   # Navigate to: Advanced → Memory Split → 128
   ```

2. **Deploy Flutter App**
   ```bash
   # Build on your dev machine:
   cd ahu_dashboard
   flutter build linux --release --target-platform linux-arm64
   
   # Copy to Pi:
   scp -r build/linux/arm64/release/bundle pi@raspberrypi.local:/opt/ahu_dashboard/
   ```

3. **Enable Dashboard**
   ```bash
   sudo systemctl enable ahu-dashboard.service
   sudo systemctl start ahu-dashboard.service
   ```

4. **Enable MQTT Bridge (Optional)**
   ```bash
   # Edit config first:
   sudo nano ~/Documents/almed_ahu/mqtt_bridge.py
   
   # Then enable:
   sudo systemctl enable mqtt-bridge.service
   sudo systemctl start mqtt-bridge.service
   ```

---

## Verification Commands

### Test MQTT
```bash
# Publish test message:
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "test" -m "hello"

# Subscribe to messages:
mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "almed/#" -v
```

### Check Services
```bash
# Check Mosquitto:
sudo systemctl status mosquitto

# Check Dashboard (when enabled):
sudo systemctl status ahu-dashboard.service

# Check Bridge (when enabled):
sudo systemctl status mqtt-bridge.service
```

### View Logs
```bash
# Mosquitto logs:
sudo journalctl -u mosquitto -f

# Dashboard logs:
sudo journalctl -u ahu-dashboard.service -f

# Bridge logs:
sudo journalctl -u mqtt-bridge.service -f
```

---

## Troubleshooting

### Script Fails at Flutter Download

```bash
# Check internet connection:
ping google.com

# Manually download Flutter:
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
tar xf flutter_linux_3.24.5-stable.tar.xz
rm flutter_linux_3.24.5-stable.tar.xz
chown -R pi:pi flutter
# Then rerun script
```

### Script Fails at Flutter-Pi Build

```bash
# Check if CMake installed:
cmake --version

# Manually build:
cd ~/flutter-pi
mkdir build && cd build
cmake ..
make -j4
sudo make install
```

### MQTT Not Starting

```bash
# Check Mosquitto config:
mosquitto -c /etc/mosquitto/mosquitto.conf -v

# Fix permissions:
sudo chown mosquitto:mosquitto /etc/mosquitto/passwd
sudo chmod 600 /etc/mosquitto/passwd
```

### Permission Errors

Make sure you run with `sudo`:
```bash
sudo bash setup_rpi_almed_ahu.sh
```

---

## Quick Reference

| File | Location | Purpose |
|------|----------|---------|
| Setup Script | `setup_rpi_almed_ahu.sh` | Main installation script |
| Flutter SDK | `/home/pi/flutter` | Flutter framework |
| Flutter-Pi | `/usr/local/bin/flutter-pi` | Flutter runtime for Pi |
| Mosquitto Config | `/etc/mosquitto/conf.d/almed.conf` | MQTT settings |
| Hotspot Config | `/etc/hostapd/hostapd.conf` | WiFi hotspot |
| Bridge Script | `~/Documents/almed_ahu/mqtt_bridge.py` | Cloud bridge |
| Dashboard App | `/opt/ahu_dashboard/` | Your Flutter app |
| Setup Summary | `~/ALMED_SETUP_SUMMARY.txt` | Installation log |

---

## Support Files

You also have these helpful files:

- `SETUP_RPI_GUIDE.md` - Detailed setup instructions
- `ALMED_SETUP_SUMMARY.txt` - Generated after script runs
- `mqtt_bridge.py` - MQTT bridge script (copy to Pi)
- `mqtt-bridge.service` - Bridge service file

---

## Need Help?

1. Check `SETUP_RPI_GUIDE.md` for detailed instructions
2. Look at `~/ALMED_SETUP_SUMMARY.txt` after running script
3. Check service logs: `sudo journalctl -u <service> -f`
4. Verify MQTT: use `mosquitto_pub` and `mosquitto_sub`

---

**You're all set! Just run the script on your Raspberry Pi and follow the prompts.** 🚀

