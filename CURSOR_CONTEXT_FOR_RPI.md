# Cursor Context for Raspberry Pi

**Read this file FIRST when starting work on Raspberry Pi!**

This document provides complete context about what we've built and discussed.

---

## 🎯 Project Overview

**ALMED AHU System** - Complete hospital AHU (Air Handling Unit) control and monitoring system

### System Architecture

```
ESP32 Devices (AHU Control Units)
  ↓ MQTT Publish (every 10 seconds)
Raspberry Pi (Mosquitto MQTT Broker)
  ├─→ Flutter Desktop Dashboard (Kiosk mode)
  └─→ MQTT Bridge
      ↓
HiveMQ Cloud (Secure TLS MQTT)
  ├─→ Mobile App (Flutter)
  ├─→ Admin Web Dashboard
  └─→ Backend Services
      ↓
Databases
  ├─→ InfluxDB Cloud (Time-series sensor data)
  └─→ Firebase (Users, tickets, configs, auth)
```

---

## 🗺️ Complete Data Flow

### Real-time Monitoring: ESP32 → Mobile/Web

```
ESP32 reads sensors (temp, humidity)
  ↓ Publishes telemetry every 10s
Local MQTT Broker (Mosquitto on RPI)
  ↓ Bridge forwards
HiveMQ Cloud
  ↓ Mobile/Web subscribes
Display live data
```

### Control Commands: Mobile/Web → ESP32

```
User taps button in Mobile/Web App
  ↓ Publishes command to HiveMQ
MQTT Bridge receives from cloud
  ↓ Checks device is on this RPI
  ↓ Forwards to local Mosquitto
ESP32 subscribed to cmd topic
  ↓ Parses JSON command
  ↓ Executes action (set fan speed, etc.)
  ↓ Publishes state update
Mobile/Web receives updated state
```

### Historical Data: Bridge → InfluxDB

```
MQTT Bridge receives telemetry from local
  ↓ Writes to InfluxDB Cloud
Storage with tags: device_id, site, room
Mobile/Web queries InfluxDB for graphs
```

---

## 🏗️ Hardware Configuration

### ESP32 Pin Assignment

**Sensors:**
- SHT4x: I2C (SDA, SCL)

**Motors:**
- Motor 1 (Drain pump): IN1=25, IN2=26, ENA=33
- Motor 2 (Return pump): IN3=27, IN4=14, ENB=32

**Fan Control (3-speed relay method):**
- LOW speed (5V): Relay on GPIO 18
- MID speed (9V): Relay on GPIO 13
- HIGH speed (12V): Relay on GPIO 4
- All relays: ACTIVE LOW (LOW=ON, HIGH=OFF)

**Relays:**
- Compressor: GPIO 23
- Heater: GPIO 19

### Fan Speed Control

**Modes:**
- `FAN_OFF = 0` - Internal only (system not running)
- `FAN_LOW = 1` - 5V via LM2596 #1
- `FAN_MID = 2` - 9V via LM2596 #2
- `FAN_HIGH = 3` - 12V via LM2596 #3

**Automatic Control:**
- LOW at 24°C, MID at 26°C, HIGH at 28°C
- Switches based on temperature

**Manual Control:**
- Commands: `{"fanToggle": true}` or `{"fanSpeed": 1|2|3}`
- Manual mode expires after 5 minutes

---

## 📡 MQTT Topic Structure

**Format:** `almed/ahu/{site}/{room}/{device-id}/{type}`

**Examples:**
- Telemetry: `almed/ahu/hospitalA/icu1/ahu-01/telemetry`
- Commands: `almed/ahu/hospitalA/icu1/ahu-01/cmd`
- State: `almed/ahu/hospitalA/icu1/ahu-01/state`
- Logs: `almed/ahu/hospitalA/icu1/ahu-01/log`
- Status: `almed/ahu/hospitalA/icu1/ahu-01/status`
- Provisioning: `almed/ahu/hospitalA/icu1/ahu-01/provision/wifi`

**Wildcard Subscriptions:**
- All ALMED devices: `almed/#`
- All commands: `almed/ahu/+/+/+/cmd`
- All telemetry: `almed/ahu/+/+/+/telemetry`

---

## 🎮 Available Commands

**System Control:**
- `{"start": true}` - Start system (M1 drain, fan LOW)
- `{"stop": true}` - Stop system (M1 drain, fan OFF)

**Setpoints:**
- `{"setpoint": 23.5}` - Set temperature (°C)
- `{"humiditySetpoint": 60}` - Set humidity (%RH)

**Fan Control:**
- `{"fanToggle": true}` - Cycle: LOW→MID→HIGH→LOW
- `{"fanSpeed": 0}` - OFF
- `{"fanSpeed": 1}` - LOW (5V)
- `{"fanSpeed": 2}` - MID (9V)
- `{"fanSpeed": 3}` - HIGH (12V)

**Motor Timings (Admin only):**
- `{"motorTimings": {"m1_start": 10, "m1_post": 10, "m2_interval": 30, "m2_run": 10}}`

**Provisioning (Admin only):**
- WiFi: `{"provision": {"wifi": {...}}}`
- MQTT: `{"provision": {"broker": {...}}}`

---

## 🔧 Current System Status

### What's Working ✅
- ESP32 firmware with dual-broker support
- Raspberry Pi with Mosquitto MQTT broker
- MQTT bridge script connecting RPI to HiveMQ Cloud
- ESP32 publishing telemetry to local broker
- Bridge forwarding telemetry to cloud
- Desktop Flutter dashboard on RPI

### Issue to Fix 🔧
- **HiveMQ commands not reaching ESP32** (fan speed commands not working)
- Likely causes:
  1. Device not discovered by bridge
  2. Topic mismatch
  3. Bridge not forwarding commands

### Test Files Available 🧪
- `test_hivemq_command.py` - Send commands to HiveMQ
- `test_bridge_debug.py` - Monitor local MQTT
- `test_influx.py` - Test InfluxDB connection
- `test_firebase.py` - Test Firebase auth/storage

---

## 📋 Key Files

### Firmware
- `esp32_main/esp32_main.ino` - ESP32 control firmware (1,313 lines)

### Raspberry Pi
- `mqtt_bridge.py` - Bridge between local and cloud (402 lines)
- `mqtt-bridge.service` - Systemd service file
- `setup_rpi_almed_ahu.sh` - Automated Pi setup (576 lines)
- `fix-hotspot.sh` - WiFi hotspot configuration
- `fix-hotspot-persistent.sh` - Persistent hotspot fixes

### Dashboards
- `ahu_dashboard/` - Flutter desktop dashboard for RPI
  - Kiosk mode interface
  - Admin and Hospital roles
  - Real-time monitoring

### Plans
- `MOBILE_APP_COMPLETE_PLAN.md` - Mobile app detailed plan (1,020 lines)
- `MOBILE_APP_QUICK_REFERENCE.md` - Quick mobile reference
- `ADMIN_WEB_COMPLETE_PLAN.md` - Admin dashboard plan (1,078 lines)
- `ADMIN_WEB_QUICK_REFERENCE.md` - Quick admin reference

### Setup Guides
- `DAY_TESTING_CHECKLIST.md` - Today's 9 AM - 6 PM schedule
- `TESTING_GUIDE.md` - Debugging guide
- `InfluxDB_quick_setup_guide.md` - Database setup
- `Firebase_quick_setup_guide.md` - Firebase setup
- `HIVEMQ_SETUP_QUICK_START.md` - MQTT setup

---

## 🔐 Credentials

### MQTT Local (Raspberry Pi Mosquitto)
- User: `almed`
- Password: `Almed1234$`
- Port: `1883`
- Host: `127.0.0.1` or `10.42.0.1`

### MQTT Cloud (HiveMQ)
- Broker: `ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud`
- Port: `8883` (TLS)
- User: `almed`
- Password: `AlMed123456`

### WiFi Hotspot
- SSID: `PiSpot`
- Password: `12345678`
- IP: `10.42.0.1`

---

## 🐛 Known Issues & Solutions

### Issue: Fan Speed Commands Not Working

**Symptoms:**
- Command sent to HiveMQ
- Bridge receives but doesn't forward
- ESP32 never receives command

**Debugging:**
1. Check bridge logs: `sudo journalctl -u mqtt-bridge.service -f`
2. Look for: `✓ Device discovered: ahu-01`
3. If missing, ESP32 needs to publish telemetry first (triggers discovery)
4. Check bridge is subscribed to: `almed/ahu/+/+/+/cmd`

**Likely Fix:**
- Restart ESP32 to trigger device discovery
- Or restart bridge: `sudo systemctl restart mqtt-bridge`

---

## 🎯 Today's Goals (9 AM - 6 PM)

### Morning (9 AM - 12:30 PM): Debug MQTT Commands
- Fix HiveMQ command flow
- Test all ESP32 commands
- Verify fan speed control works

### Afternoon Part 1 (1:30 PM - 3:30 PM): Cloud Services
- Set up InfluxDB Cloud
- Set up Firebase
- Integrate with bridge

### Afternoon Part 2 (3:30 PM - 6 PM): Flutter Mobile App
- Create Flutter project
- Set up authentication
- Build login screen
- Implement MQTT service

---

## 💻 Essential Commands for Tomorrow

### Debug MQTT Issues
```
"trace the complete MQTT command flow from HiveMQ to ESP32 and show me why fan speed commands aren't reaching the device"
```

### Integrate InfluxDB
```
"integrate InfluxDB into mqtt_bridge.py to write telemetry data to cloud storage with proper tags and fields"
```

### Build Flutter MQTT Service
```
"create a complete Flutter MQTT service class that connects to HiveMQ Cloud, subscribes to telemetry topics, publishes commands, and handles reconnection"
```

### Build Flutter UI
```
"build Flutter device detail screen with temperature/humidity displays, fan speed control dropdown, and setpoint sliders"
```

### Implement Firebase Auth
```
"implement Firebase authentication in my Flutter app with login screen, token storage, and automatic token refresh"
```

---

## 📊 System Data Structures

### Telemetry JSON
```json
{
  "temperature": 24.5,
  "humidity": 60.0,
  "m1": false,
  "m2": false,
  "run": true,
  "cp": true,
  "heater": false,
  "fan": true,
  "fanSpeed": 1,
  "tempSet": 22.0,
  "humSet": 55.0,
  "ts": 1234567890
}
```

### State JSON
```json
{
  "run": true,
  "m1": false,
  "m2": false,
  "cp": true,
  "heater": false,
  "fan": true,
  "fanSpeed": 1,
  "tempSet": 22.0,
  "humSet": 55.0,
  "m1_start": 10,
  "m1_post": 10,
  "m2_interval": 30,
  "m2_run": 10,
  "m2_delay": 5,
  "ip": "192.168.1.100"
}
```

---

## 🔍 How MQTT Bridge Works

**Device Auto-Discovery:**
1. Bridge subscribes to `almed/#` on local broker
2. When ESP32 publishes telemetry, bridge extracts device ID
3. Adds to `local_devices` set
4. Commands only forwarded to devices in this set

**Command Forwarding Logic:**
```python
# Bridge receives command from cloud
device_id = extract_device_id_from_topic(topic)

# Check if device is on THIS Raspberry Pi
if device_id and device_id not in local_devices:
    # Skip - not our device
    return

# Forward to local Mosquitto
local_client.publish(topic, payload)
```

**Message Deduplication:**
- Cache last payload hash per topic
- Skip duplicates within 10 seconds
- Always forward when sensor values change

---

## 🚨 Important Notes

**ESP32 Watchdog System:**
- 30-second hardware watchdog
- Auto-recovery from WiFi failures
- State persistence across resets
- Always feeds watchdog every loop cycle

**Fan Control Safety:**
- Only ONE relay ON at a time
- 100ms delay between relay switches
- Emergency stop turns all OFF
- Manual mode expires after 5 minutes

**Motor Timing Defaults:**
- M1 Start: 10 seconds
- M1 Post-run: 10 seconds
- M2 Interval: 30 seconds
- M2 Run time: 10 seconds
- M2 Delay after M1: 5 seconds

**Network Priority:**
1. **Primary**: Local RPI broker (low latency, works offline)
2. **Secondary**: HiveMQ Cloud (for remote access)

---

## 📚 Documentation Structure

**Quick Start:**
- `README_START_HERE.md` - Project overview
- `DAY_TESTING_CHECKLIST.md` - Today's tasks

**Setup Guides:**
- `setup_rpi_almed_ahu.sh` - Automated Pi setup
- `InfluxDB_quick_setup_guide.md` - Database
- `Firebase_quick_setup_guide.md` - Firebase
- `HIVEMQ_SETUP_QUICK_START.md` - MQTT

**Application Plans:**
- `MOBILE_APP_COMPLETE_PLAN.md` - Mobile (detailed)
- `MOBILE_APP_QUICK_REFERENCE.md` - Mobile (quick)
- `ADMIN_WEB_COMPLETE_PLAN.md` - Admin (detailed)
- `ADMIN_WEB_QUICK_REFERENCE.md` - Admin (quick)

**References:**
- `COMPLETE_SYSTEM_GUIDE.md` - Architecture
- `TESTING_GUIDE.md` - Debugging
- `COMPLETE_PROJECT_SUMMARY.md` - Everything

---

## 🎯 Quick Actions

**Check Bridge Status:**
```bash
sudo systemctl status mqtt-bridge
```

**Watch Bridge Logs:**
```bash
sudo journalctl -u mqtt-bridge.service -f
```

**Restart Bridge:**
```bash
sudo systemctl restart mqtt-bridge
```

**Test Command Locally:**
```bash
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fanSpeed": 2}'
```

**Monitor Local MQTT:**
```bash
python3 test_bridge_debug.py
```

**Send Test Commands:**
```bash
python3 test_hivemq_command.py
```

---

## 💡 Key Insights

**Device Discovery is Critical:**
- ESP32 must publish telemetry FIRST
- Bridge discovers device from telemetry
- Only THEN will commands be forwarded

**Bridge Filtering:**
- Commands filtered by `local_devices` set
- Prevents commands going to wrong Raspberry Pi
- Multi-site support built-in

**Fan Speed Commands:**
- Require system to be RUNNING
- Manual mode disables auto-control
- Manual mode expires after 5 minutes

**Multiple Brokers:**
- ESP32 publishes to BOTH local AND cloud
- Local: priority, low latency
- Cloud: backup, remote access
- Bridge bridges between them

---

## 🎉 Success Criteria

**End of Day Should Have:**
- ✅ All MQTT commands working
- ✅ InfluxDB storing data
- ✅ Firebase authentication working
- ✅ Flutter app structure created
- ✅ Login screen functional
- ✅ MQTT service receiving data

---

**READ THIS FIRST when starting work tomorrow!** 🚀

This gives complete context to any new Cursor session.

