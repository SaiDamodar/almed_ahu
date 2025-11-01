# Setup & Testing Files Summary

## Files Created for Your Testing Day

---

## Testing Scripts

### 1. `test_hivemq_command.py`
**Purpose:** Sends MQTT commands to HiveMQ Cloud from your dev machine

**Usage:**
```bash
python3 test_hivemq_command.py
```

**Features:**
- Interactive command menu
- Test all ESP32 commands
- Real-time feedback
- Secure TLS connection

**Commands available:**
- Start/Stop system
- Fan speed control
- Temperature/Humidity setpoints
- Motor timing control

---

### 2. `test_bridge_debug.py`
**Purpose:** Monitors MQTT messages on local Raspberry Pi broker

**Usage:**
```bash
python3 test_bridge_debug.py
```

**Features:**
- Real-time message monitoring
- Shows all device topics
- JSON pretty-print
- Subscribe to cmd, state, telemetry

---

### 3. `test_influx.py`
**Purpose:** Test InfluxDB connection and data writing

**Usage:**
```bash
# 1. Update config with your InfluxDB credentials
# 2. Run: python3 test_influx.py
```

**Features:**
- Test connection
- Write sample data
- Query verification
- Error handling

---

### 4. `test_firebase.py`
**Purpose:** Test Firebase Auth and Firestore

**Usage:**
```bash
# 1. Place firebase-service-account.json in directory
# 2. Run: python3 test_firebase.py
```

**Features:**
- Firebase initialization test
- User creation/deletion
- Firestore read/write
- Cleanup test data

---

## Documentation Files

### 5. `TESTING_GUIDE.md`
**Complete debugging guide** for MQTT command flow issues

**Contents:**
- Step-by-step debugging process
- Common issues and fixes
- Expected flow diagrams
- Quick reference commands

---

### 6. `DAY_TESTING_CHECKLIST.md`
**Hour-by-hour checklist** for your 9 AM - 6 PM testing day

**Contents:**
- Morning: Debug MQTT commands
- Afternoon Part 1: Cloud services setup
- Afternoon Part 2: Flutter app setup
- End-of-day checklist

---

### 7. `setup_rpi_almed_ahu.sh`
**Automated Raspberry Pi setup script** (576 lines)

**What it does:**
- Installs Flutter SDK
- Builds Flutter-Pi
- Sets up Mosquitto MQTT broker
- Configures WiFi hotspot
- Creates all necessary services

---

## Quick Setup Summary

### For MQTT Testing

**On Raspberry Pi:**
```bash
# Terminal 1: Watch bridge logs
sudo journalctl -u mqtt-bridge.service -f

# Terminal 2: Monitor local MQTT
python3 test_bridge_debug.py

# Terminal 3: ESP32 Serial Monitor
# (Arduino IDE or PlatformIO)
```

**On Your Dev Machine:**
```bash
# Send test commands
python3 test_hivemq_command.py
```

---

### For Cloud Services

**InfluxDB:**
```bash
# 1. Follow InfluxDB_quick_setup_guide.md
# 2. Update test_influx.py with credentials
# 3. Run: python3 test_influx.py
```

**Firebase:**
```bash
# 1. Follow Firebase_quick_setup_guide.md
# 2. Download service-account.json
# 3. Run: python3 test_firebase.py
```

---

## All Files Reference

| File | Purpose | Run On |
|------|---------|--------|
| `test_hivemq_command.py` | Send commands to cloud | Dev Machine |
| `test_bridge_debug.py` | Monitor local MQTT | Raspberry Pi |
| `test_influx.py` | Test InfluxDB | Either |
| `test_firebase.py` | Test Firebase | Either |
| `TESTING_GUIDE.md` | Debug guide | Reference |
| `DAY_TESTING_CHECKLIST.md` | Day plan | Reference |
| `setup_rpi_almed_ahu.sh` | Pi setup | Raspberry Pi |

---

## Quick Commands

**Copy files to Raspberry Pi:**
```bash
scp test_*.py pi@raspberrypi.local:~/Documents/almed_ahu/
scp TESTING_GUIDE.md pi@raspberrypi.local:~/Documents/almed_ahu/
```

**Make scripts executable:**
```bash
chmod +x test_*.py
```

---

## Next Steps

1. Copy test scripts to Raspberry Pi
2. Review `DAY_TESTING_CHECKLIST.md`
3. Start debugging MQTT commands
4. Set up cloud services
5. Build Flutter app

**Everything is ready for your testing day!** 🚀

