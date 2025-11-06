# ALMED AHU System

## 📚 Complete Documentation

This project has been consolidated into **two comprehensive guides**:

---

## 1️⃣ **ALMED_AHU_COMPLETE_GUIDE.md** ⭐ START HERE
**Complete system documentation for the ALMED AHU controller**

Includes:
- System overview
- Current hardware setup (5-ch relay, PWM fan control)
- ESP32 pin assignments
- Local network architecture (Raspberry Pi hotspot)
- Dashboard setup (Flutter)
- MQTT communication
- Testing & verification
- Complete troubleshooting guide

**📖 Read this first to understand your entire system!**

---

## 2️⃣ **HOTSPOT_FIX_CURSOR_AUTOMATION.md** 🔧 TROUBLESHOOTING
**Automatic hotspot fix guide for Raspberry Pi**

Includes:
- Hotspot problem diagnosis
- Two automated fix scripts
- Cursor AI automation instructions
- Testing procedures
- Monitoring & recovery
- Complete troubleshooting guide

**🔧 Use this when ESP32 can't connect to PiSpot!**

---

## 🚀 Quick Start

### For New Users
1. Read **ALMED_AHU_COMPLETE_GUIDE.md** (start to finish)
2. Follow the "Quick Start Checklist" section
3. Test your system using the verification steps

### For Hotspot Issues
1. Open **HOTSPOT_FIX_CURSOR_AUTOMATION.md**
2. Run the automated fix scripts
3. Follow the testing procedures

---

## 📁 Project Structure

```
almed_ahu/
├── README.md                              ← You are here
├── ALMED_AHU_COMPLETE_GUIDE.md           ← Main system documentation
├── HOTSPOT_FIX_CURSOR_AUTOMATION.md      ← Hotspot troubleshooting
│
├── esp32_main/
│   ├── esp32_main.ino                     ← Current ESP32 firmware (978 lines)
│   └── esp32_main_BACKUP_local_only.ino   ← Backup (local MQTT only)
│
├── ahu_dashboard/                         ← Flutter dashboard (Raspberry Pi)
│   ├── lib/                               ← Dashboard source code
│   │   ├── models/                        ← Data models
│   │   ├── providers/                     ← State management
│   │   ├── screens/                       ← UI screens
│   │   ├── services/                      ← MQTT service
│   │   └── widgets/                       ← UI components
│   ├── pubspec.yaml                       ← Flutter dependencies
│   └── README.md                          ← Dashboard-specific docs
│
├── fix-hotspot.sh                         ← Quick hotspot fix script
├── fix-hotspot-persistent.sh              ← Persistent hotspot fix script
│
└── test.py                                ← MQTT testing script
```

---

## ⚡ Quick Commands

### Raspberry Pi Hotspot
```bash
# Check hotspot status
nmcli con show --active | grep Hotspot

# Fix hotspot (if not working)
sudo bash fix-hotspot.sh

# Add auto-recovery
sudo bash fix-hotspot-persistent.sh

# Manual restart
sudo restart-hotspot
```

### MQTT Testing
```bash
# Subscribe to all AHU topics
mosquitto_sub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" -t "almed/ahu/#" -v

# Send system start command
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"start":true}'
```

### Dashboard
```bash
# Run dashboard on Raspberry Pi
cd ~/almed_ahu/ahu_dashboard
flutter run -d linux
```

---

## 🎯 System Status

**Current Implementation:**
- ✅ ESP32 firmware (local MQTT only)
- ✅ 5-channel relay control (Active LOW)
- ✅ PWM fan control (0-10V, 3 speeds: 5V, 7V, 9V)
- ✅ Temperature & humidity sensing (SHT45)
- ✅ Motor sequencing (boot, run, shutdown)
- ✅ CP & Heater control
- ✅ Watchdog & state recovery
- ✅ Raspberry Pi hotspot (PiSpot)
- ✅ Local MQTT broker (Mosquitto)
- ✅ Flutter dashboard (real-time control)

**Hardware:**
- ESP32 DevKit
- 5-Channel Relay Module (Active LOW)
- PWM to 0-10V Converter
- SHT45 Temperature & Humidity Sensor
- 2x 12V DC Motors
- 3x 220V AC Loads (Heater, CP, System)
- Raspberry Pi (hotspot + MQTT + dashboard)

**Network:**
- Hotspot: PiSpot (password: 12345678)
- MQTT Broker: 10.42.0.1:1883
- Username: almed
- Password: Almed1234$

---

## 📞 Need Help?

### General Questions
→ Read **ALMED_AHU_COMPLETE_GUIDE.md** (comprehensive guide)

### ESP32 Not Connecting
→ Read **HOTSPOT_FIX_CURSOR_AUTOMATION.md** (automatic fix)

### Dashboard Not Working
→ See "Dashboard Setup" in **ALMED_AHU_COMPLETE_GUIDE.md**

### Hardware Issues
→ See "Troubleshooting" in **ALMED_AHU_COMPLETE_GUIDE.md**

---

## 🔐 Default Credentials

**MQTT:**
- Username: `almed`
- Password: `Almed1234$`

**WiFi Hotspot:**
- SSID: `PiSpot`
- Password: `12345678`

**Dashboard Admin:**
- Passcode: `1234`

⚠️ **Change these before production deployment!**

---

## 📊 System Architecture

```
┌─────────────────────────────────────────┐
│        Raspberry Pi Hotspot (PiSpot)    │
│              10.42.0.1                   │
├─────────────────────────────────────────┤
│                                          │
│  ESP32 ──MQTT──> Mosquitto Broker       │
│  (Sensors)       (Port 1883)            │
│                         │                │
│                         ▼                │
│                  Flutter Dashboard       │
│                  (Real-time Control)     │
│                                          │
└─────────────────────────────────────────┘
```

---

## ✅ Verification Checklist

Quick check that everything is working:

- [ ] Raspberry Pi hotspot running (`nmcli con show --active`)
- [ ] MQTT broker running (`sudo systemctl status mosquitto`)
- [ ] ESP32 connected to PiSpot (check serial monitor)
- [ ] Dashboard shows "Connected" (green indicator)
- [ ] Temperature displaying correctly
- [ ] Fan control working (OFF, LOW, MED, HIGH)
- [ ] System ON/OFF working
- [ ] Motors responding to commands

---

**Last Updated:** November 6, 2024  
**System Version:** 2.0 (Local MQTT Only)  
**Documentation:** Consolidated into 2 comprehensive guides

---

**🎉 Everything you need is documented in the two guides above!**

