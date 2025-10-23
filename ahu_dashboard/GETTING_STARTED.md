# Getting Started with AHU Dashboard

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Dependencies
```bash
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 2: Start MQTT Broker
```bash
# Install if needed
sudo apt install mosquitto mosquitto-clients

# Configure
sudo mosquitto_passwd -c /etc/mosquitto/passwd almed
# Password: Almed1234$

# Start
sudo systemctl start mosquitto
```

### Step 3: Run the Dashboard
```bash
flutter run -d linux
```

### Step 4: Test Without ESP32
Open a new terminal and simulate ESP32 data:

```bash
# Simulate online status
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/status' -r -m 'online'

# Simulate telemetry
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/telemetry' \
  -m '{"temp":22.5,"hum":55.0,"m1":false,"m2":false,"run":false,"cp":false,"heater":false,"tempSet":22.0,"humSet":55.0,"ts":12345}'

# Simulate state
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/state' -r \
  -m '{"run":false,"m1":false,"m2":false,"cp":false,"heater":false,"tempSet":22.0,"humSet":55.0,"ip":"192.168.1.100"}'
```

### Step 5: Interact with the Dashboard
1. Select "Hospital User" or "Administrator"
2. Wait for MQTT connection
3. Click on the AHU card
4. Try starting the system
5. Adjust temperature/humidity setpoints

## 📖 Documentation Guide

- **README.md** - Complete documentation (deployment, configuration, troubleshooting)
- **QUICKSTART.md** - Common commands and quick fixes
- **PROJECT_SUMMARY.md** - Project overview and architecture
- **GETTING_STARTED.md** - This file (first-time setup)

## 🎯 What You Can Do

### As Hospital User
- Monitor temperature and humidity in real-time
- Start/stop AHU systems
- Adjust temperature setpoints (15-30°C)
- Adjust humidity setpoints (30-80%)
- View motor, compressor, and heater status
- Read system logs

### As Administrator
- Everything hospital users can do, plus:
- Configure WiFi credentials for ESP32
- Set MQTT broker address
- Provision multiple AHU units

## 🔧 Troubleshooting

### Dashboard won't connect
```bash
# Check MQTT broker
sudo systemctl status mosquitto

# Test connection
mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t 'test'
```

### No AHU units showing
```bash
# Publish status message
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/status' -r -m 'online'
```

### Build errors
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## 🎓 Next Steps

1. **Read README.md** for full deployment instructions
2. **Test with ESP32** - Connect your actual hardware
3. **Deploy to Pi** - Use `./deploy.sh` script
4. **Set up kiosk mode** - Follow systemd service instructions in README.md
5. **Customize** - Add more AHU units, adjust colors, etc.

## 📞 Need Help?

Check these files in order:
1. GETTING_STARTED.md (this file) - First-time setup
2. QUICKSTART.md - Common commands
3. README.md - Full documentation
4. PROJECT_SUMMARY.md - Architecture overview

## 🎉 You're Ready!

Your AHU dashboard is now running. Enjoy monitoring and controlling your hospital's air handling units with a professional, touch-friendly interface!

