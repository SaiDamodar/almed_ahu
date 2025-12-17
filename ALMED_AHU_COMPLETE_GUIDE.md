# ALMED AHU System - Complete Guide

## 🎯 START HERE - Everything You Need to Know

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Current Hardware Setup](#current-hardware-setup)
3. [ESP32 Pin Assignments](#esp32-pin-assignments)
4. [Local Network Architecture](#local-network-architecture)
5. [Dashboard Setup](#dashboard-setup)
6. [MQTT Communication](#mqtt-communication)
7. [Testing & Verification](#testing--verification)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 System Overview

### What You Have

**✅ Working Local System:**
- ESP32 AHU controller with sensors
- 5-Channel relay module (Active LOW)
- PWM to 0-10V converter for fan control
- Raspberry Pi hotspot with local MQTT broker
- Flutter dashboard on Raspberry Pi
- Local network only (no cloud)

### Hardware Components

**ESP32 Board:**
- Temperature & Humidity sensor (SHT45)
- 2x 12V DC motors (via 5-ch relay)
- 3x 220V AC loads (Heater, CP, System via 5-ch relay)
- 1x PWM-controlled fan (0-10V converter)

**Power Supply:**
- XY3606 DC-DC buck converter (12V output)
- 12V SMPS for motors and PWM converter
- Common ground for all components

**Raspberry Pi:**
- Hotspot "PiSpot" (password: 12345678)
- Mosquitto MQTT broker (10.42.0.1:1883)
- Flutter dashboard (Kiosk mode)

---

## 🔌 Current Hardware Setup

### 5-Channel Relay Module (Active LOW: LOW=ON, HIGH=OFF)

```
Relay IN1 (D32): Motor 1 (12V DC)
Relay IN2 (D33): Motor 2 (12V DC)
Relay IN3 (D19): Heater (220V AC)
Relay IN4 (D23): CP Compressor (220V AC)
Relay IN5 (D18): System Master (220V AC)
Relay VCC: XY3606 5V
Relay GND: COMMON GND
```

**Relay COM Connections:**
- COM 1 & 2: 12V DC SMPS
- COM 3, 4, 5: 220V AC mains

### PWM to Voltage Converter (0-10V)

```
PWM Input: ESP32 D2
GND: COMMON GND
VCC IN: 12V SMPS
GND IN: GND SMPS
VOUT+: FAN+
VOUT-: FAN-
```

**Fan Speed Control:**
| Mode | Voltage | PWM Duty | PWM Value (8-bit) |
|------|---------|----------|------------------|
| OFF  | 0V      | 0%       | 0                |
| LOW  | 5V      | 50%      | 128              |
| MED  | 7V      | 70%      | 179              |
| HIGH | 9V      | 90%      | 230              |

### Temperature & Humidity Sensor (SHT45)

```
SDA (Yellow): ESP32 D21
SCL (Green): ESP32 D22
VCC: 3.3V ESP32
GND: COMMON GND
```

### Motors (12V DC)

```
Motor 1 & 2:
  GND: SMPS V-
  VCC: Relay IN1/IN2 NO (Normally Open)
```

### ESP32 Power

```
Power Source: USB from XY3606 5V output
GND: COMMON GND
```

---

## 📌 ESP32 Pin Assignments

### Complete Pin Map

```
✅ USED PINS:

Sensors:
  GPIO 21 (D21) → SHT45 SDA
  GPIO 22 (D22) → SHT45 SCL

5-Channel Relay Module:
  GPIO 32 (D32) → Motor 1 Relay (Active LOW)
  GPIO 33 (D33) → Motor 2 Relay (Active LOW)
  GPIO 19 (D19) → Heater Relay (Active LOW)
  GPIO 23 (D23) → CP Compressor Relay (Active LOW)
  GPIO 18 (D18) → System Master Relay (Active LOW)

Fan Control (PWM):
  GPIO 2 (D2) → PWM to 0-10V Converter

⚠️ AVAILABLE FOR FUTURE USE:
  GPIO 13, 12, 5, 4
  GPIO 35, 34 (INPUT ONLY)
```

### Important Notes

- **Active LOW Relays**: Write `LOW` to turn ON, `HIGH` to turn OFF
- **Brownout Detector**: Disabled in software (prevents resets during motor start/stop)
- **Common Ground**: All components share COMMON GND
- **PWM Frequency**: 25 kHz for fan control

---

## 🌐 Local Network Architecture

### Current System (Local Only)

```
┌─────────────────────────────────────────────────────────┐
│                   Raspberry Pi Hotspot                   │
│                  SSID: PiSpot                            │
│                  IP: 10.42.0.1                           │
│                  Password: 12345678                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐         ┌────────────────────┐       │
│  │  ESP32 AHU   │ ─MQTT──>│ Mosquitto Broker   │       │
│  │  (WiFi STA)  │         │ Port: 1883         │       │
│  │  Auto IP     │ <──MQTT─│ User: almed        │       │
│  └──────────────┘         │ Pass: Almed1234$   │       │
│                            └─────────┬──────────┘       │
│                                      │                   │
│                            ┌─────────▼──────────┐       │
│                            │ Flutter Dashboard  │       │
│                            │ (Kiosk Mode)       │       │
│                            └────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

### MQTT Topics Structure

```
Base: almed/ahu/hospitalA/icu1/ahu-01/

Topics:
  /telemetry        → ESP32 publishes sensor data (every 2s)
  /state            → ESP32 publishes state (retained)
  /log              → ESP32 publishes log messages
  /status           → ESP32 publishes online/offline (retained LWT)
  /cmd              → Dashboard publishes commands
  /provision/wifi   → Dashboard sends WiFi credentials
  /provision/broker → Dashboard sends MQTT broker config
  /provision/motor_timings → Admin sends motor timings
```

### Telemetry Data Format (JSON)

```json
{
  "temp": 25.7,
  "hum": 51.4,
  "m1": false,
  "m2": false,
  "run": true,
  "cp": false,
  "heater": false,
  "fan": true,
  "fanSpeed": 2,
  "tempSet": 22.0,
  "humSet": 55.0,
  "ts": 123456
}
```

**Field Definitions:**
- `fan`: Boolean (fan on/off)
- `fanSpeed`: Integer (0=OFF, 1=LOW, 2=MED, 3=HIGH)
- `m1`, `m2`: Motor states
- `cp`: Compressor (cooling)
- `heater`: Heater (dehumidifier)
- `run`: System running state

---

## 📱 Dashboard Setup

### On Raspberry Pi

**Location:** `~/almed_ahu/ahu_dashboard/`

**Run Dashboard:**
```bash
cd ~/almed_ahu/ahu_dashboard
flutter run -d linux
```

### MQTT Connection Settings

```dart
Broker: 127.0.0.1 (localhost)
Port: 1883
Username: almed
Password: Almed1234$
```

### Dashboard Features

**User View:**
- Real-time temperature & humidity
- System ON/OFF control
- Motor status (M1, M2)
- CP & Heater status
- Fan speed control (OFF, LOW, MED, HIGH)
- Temperature & humidity setpoints
- Live log viewer

**Admin View (Passcode: 1234):**
- All user features
- WiFi provisioning
- Motor timing adjustment
- System diagnostics

---

## 🔧 ESP32 Code Key Features

### Motor Control Sequence

**System Start:**
1. System relay ON (master power)
2. Fan starts at LOW speed
3. Motor 1 runs for 10s (boot drain)
4. Wait 5s after M1 stops
5. Motor 2 runs for 10s (filter clean)
6. Motor 2 repeats every 30s

**System Stop (Shutdown Drain):**
1. Stop Motor 2 if running
2. Motor 1 runs for 10s (post-drain)
3. Wait 5s
4. Motor 2 runs for 10s (final clean)
5. System relay OFF

### Temperature & Humidity Control

**CP (Cooling):**
- Turn ON when temp > setpoint + 1°C
- Turn OFF when temp < setpoint
- Min OFF time: 5s
- Min ON time: 3s

**Heater (Dehumidifier):**
- Turn ON when humidity > setpoint + 3%
- Turn OFF when humidity < setpoint
- Min OFF time: 5s
- Min ON time: 3s

### Fan Control

**Automatic:** Fan runs when system is ON
- User can change speed via dashboard
- Fan turns OFF when system stops

### Sensor Glitch Filter

**Temperature:**
- Reject jumps > 12°C
- Reject readings < 5°C (sensor failure)
- Auto-recover from failure

**Humidity:**
- Reject jumps > 18%
- Reject readings < 10% (sensor failure)
- Auto-recover from failure

### Watchdog & Recovery

**Watchdog Timer:** 7 seconds
- Auto-reset if loop hangs
- Auto-reset if WiFi fails for 15s
- Saves system state before reset
- Restores state after reset (motors delayed until WiFi connected)

### Serial Commands

```
start        → Start system
stop         → Stop system
toggle       → Toggle system
set 22.0     → Set temperature to 22.0°C
hum 55.0     → Set humidity to 55.0%
fan off      → Turn fan off
fan low      → Set fan to LOW (5V)
fan med      → Set fan to MED (7V)
fan high     → Set fan to HIGH (9V)
```

---

## 🧪 Testing & Verification

### 1. Check Raspberry Pi Hotspot

```bash
# On Raspberry Pi
nmcli con show --active | grep Hotspot
# Should show hotspot active

# Check IP
ip addr show wlan0 | grep "inet "
# Should show 10.42.0.1
```

### 2. Check MQTT Broker

```bash
# On Raspberry Pi
sudo systemctl status mosquitto
# Should show "active (running)"

# Test subscription
mosquitto_sub -h 127.0.0.1 -p 1883 -u almed -P "Almed1234$" -t "almed/ahu/#" -v
```

### 3. Check ESP32 Connection

```bash
# Monitor all topics from ESP32
mosquitto_sub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" -t "almed/ahu/#" -v

# Should see:
# almed/ahu/hospitalA/icu1/ahu-01/telemetry {"temp":25.7,...}
# almed/ahu/hospitalA/icu1/ahu-01/state {"run":true,...}
# almed/ahu/hospitalA/icu1/ahu-01/status online
```

### 4. Test Fan Control

```bash
# Fan LOW
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":1}'

# Fan MED
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":2}'

# Fan HIGH
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":3}'

# Fan OFF
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":0}'
```

### 5. Test System Control

```bash
# Start system
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"start":true}'

# Stop system
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"stop":true}'
```

### 6. Dashboard Verification Checklist

- [ ] Dashboard connects to MQTT (green indicator)
- [ ] Temperature displays correctly
- [ ] Humidity displays correctly
- [ ] System ON/OFF button works
- [ ] Motor status updates in real-time
- [ ] Fan speed buttons work (OFF, LOW, MED, HIGH)
- [ ] Fan speed shows correct voltage (5V, 7V, 9V)
- [ ] Setpoint changes work
- [ ] Logs appear in log viewer
- [ ] Admin features accessible with passcode

---

## 🛠️ Troubleshooting

### ESP32 Issues

**Problem: ESP32 not connecting to WiFi**
```
Solution:
1. Check hotspot is running: nmcli con show --active
2. Check SSID/password in ESP32 code
3. ESP32 LED should blink during connection
4. Check serial monitor for WiFi status
```

**Problem: Brownout reset when motor starts/stops**
```
Solution (Already implemented):
1. Brownout detector disabled in setup()
2. Temporary WiFi disable during motor operations
3. 200ms delay after motor stop (back-EMF dissipation)
4. Hardware: Install 1N4007 flyback diodes across motors
```

**Problem: Garbled serial output**
```
Solution:
- Ground loop issue
- Back-EMF from motors
- Install flyback diodes (1N4007) across motor terminals
```

**Problem: Watchdog resets**
```
Solution (Already implemented):
- Watchdog timeout: 7 seconds
- State persistence (restores after reset)
- Motors delayed until WiFi connected (safety)
```

### Dashboard Issues

**Problem: Dashboard not receiving data**
```
Solution:
1. Check MQTT broker: sudo systemctl status mosquitto
2. Check ESP32 publishing: mosquitto_sub -h 10.42.0.1 -t "almed/ahu/#" -v
3. Check dashboard MQTT settings (127.0.0.1:1883)
4. Restart dashboard
```

**Problem: Temperature shows N/A**
```
Solution:
1. Check sensor wiring (SDA=D21, SCL=D22)
2. Check ESP32 serial monitor for sensor errors
3. Sensor glitch filter may be rejecting readings
4. Verify sensor power (3.3V)
```

**Problem: Fan voltage labels wrong**
```
Solution (Already fixed):
- LOW: 5V (PWM 50%, value 128)
- MED: 7V (PWM 70%, value 179)
- HIGH: 9V (PWM 90%, value 230)
```

### Hotspot Issues

**Problem: Hotspot drops connections**
```
Solution:
See HOTSPOT_FIX_CURSOR_AUTOMATION.md for automatic fix
```

**Problem: ESP32 can't see hotspot**
```
Solution:
1. Check hotspot status: nmcli con show --active
2. Restart hotspot: sudo restart-hotspot
3. Check ESP32 is within range
4. Check hotspot channel (should be 6)
```

### Hardware Issues

**Problem: Motor doesn't start**
```
Solution:
1. Check relay LED (should light when ON)
2. Active LOW: digitalWrite(pin, LOW) = ON
3. Check power supply (12V for motors)
4. Check relay connections
5. Test relay manually: digitalWrite(PIN_MOTOR1, LOW)
```

**Problem: Fan doesn't respond to PWM**
```
Solution:
1. Check PWM pin (D2)
2. Check PWM converter power (12V input)
3. Test with multimeter on VOUT (should show 0-10V)
4. Check fan wiring (+ to VOUT+, - to VOUT-)
```

**Problem: Sensor readings unstable**
```
Solution:
1. Check I2C pullup resistors (4.7kΩ on SDA/SCL)
2. Keep I2C wires short (<15cm)
3. Check common ground connection
4. Glitch filter will auto-reject bad readings
```

---

## 📝 Motor Timing Configuration

### Default Timings (Adjustable via Admin Dashboard)

```
M1_START_RUN:  10s  (Motor-1 boot run time)
M1_POST_RUN:   10s  (Motor-1 shutdown run time)
M2_INTERVAL:   30s  (Motor-2 interval between cycles)
M2_RUN_TIME:   10s  (Motor-2 run duration)
M2_DELAY:      5s   (Delay after M1 stops before M2 starts)
```

### Adjust via MQTT

```bash
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/provision/motor_timings" \
  -m '{
    "m1_start": 15,
    "m1_post": 15,
    "m2_interval": 45,
    "m2_run": 12,
    "m2_delay": 7
  }'
```

**Note:** All values in seconds

---

## 🔐 Security Notes

### Default Credentials

**MQTT:**
- Username: `almed`
- Password: `Almed1234$`
- Port: `1883` (unencrypted - local network only)

**WiFi Hotspot:**
- SSID: `PiSpot`
- Password: `12345678`

**Dashboard Admin:**
- Passcode: `1234`

### Security Recommendations

1. **Change default passwords** before deployment
2. **Local network only** - no internet exposure
3. **Add TLS/SSL** if deploying over public networks
4. **Restrict MQTT ACLs** per device/user
5. **Use strong admin passcode** (4+ digits)

---

## 📊 System Specifications

### Performance

- **Sensor Update Rate:** 2 seconds
- **Telemetry Publish Rate:** 2 seconds
- **MQTT QoS:** 0 (telemetry), 1 (commands, state)
- **Watchdog Timeout:** 7 seconds
- **WiFi Retry:** Every 5 seconds (alternates primary/secondary)

### Limits

- **Max MQTT Payload:** 576 bytes (telemetry), 384 bytes (state)
- **Max Log Buffer:** 10 entries (motor logs), 10 entries (sensor logs)
- **Max WiFi Failures:** Auto-reset after 15 seconds
- **Max Loop Time:** 5 seconds (before watchdog triggers)

---

## 🚀 Quick Start Checklist

### Hardware Setup
- [ ] Wire 5-channel relay module
- [ ] Wire PWM to voltage converter
- [ ] Wire SHT45 sensor
- [ ] Connect motors to relay outputs
- [ ] Connect all grounds to COMMON GND
- [ ] Power ESP32 from XY3606 USB
- [ ] Power relay/converter from 12V SMPS
- [ ] **CRITICAL:** Install 1N4007 flyback diodes across motors

### Software Setup
- [ ] Raspberry Pi hotspot running
- [ ] Mosquitto broker running
- [ ] Upload esp32_main.ino to ESP32
- [ ] ESP32 connects to PiSpot
- [ ] Verify MQTT telemetry (mosquitto_sub)
- [ ] Start Flutter dashboard
- [ ] Test system ON/OFF
- [ ] Test fan control
- [ ] Test all features

---

## 📞 Support & Documentation

**Main Files:**
- `esp32_main/esp32_main.ino` - ESP32 firmware
- `esp32_main/esp32_main_BACKUP_local_only.ino` - Local-only backup
- `ahu_dashboard/` - Flutter dashboard
- `mqtt_bridge.py` - MQTT bridge (for cloud, not used currently)

**Scripts:**
- `fix-hotspot.sh` - Fix hotspot stability
- `fix-hotspot-persistent.sh` - Persistent hotspot fix

**Testing:**
- `esp32_main/pwm_fan_test.ino` - Fan PWM test
- `esp32_main/relay_test.ino` - Relay test
- `test_firebase.py` - Firebase connection test
- `test_influx.py` - InfluxDB connection test

---

## ✅ System Status

**Current Implementation:**
- ✅ ESP32 firmware with all features
- ✅ 5-channel relay control (Active LOW)
- ✅ PWM fan control (0-10V, 3 speeds)
- ✅ Temperature & humidity sensing (SHT45)
- ✅ Motor sequencing (boot, run, shutdown)
- ✅ CP & Heater control (temp/humidity setpoints)
- ✅ Watchdog & state recovery
- ✅ Local MQTT communication
- ✅ Raspberry Pi hotspot
- ✅ Flutter dashboard (real-time control)
- ✅ Admin features (motor timings, WiFi provisioning)

**Hardware Protection:**
- ✅ Brownout detector disabled (software)
- ✅ WiFi disabled during motor operations
- ✅ Back-EMF delay (200ms after motor stop)
- ⚠️ **TODO:** Install flyback diodes (1N4007) across motors

**Not Currently Used (Available for Future):**
- ⏸️ Cloud MQTT (HiveMQ)
- ⏸️ MQTT bridge script
- ⏸️ Secondary WiFi (hospital network)
- ⏸️ Historical database (InfluxDB/Firebase)

---

**Last Updated:** November 6, 2024  
**System Version:** 2.0 (Local MQTT Only)  
**ESP32 Code:** `esp32_main.ino` (978 lines)  
**Dashboard:** Flutter Linux (Raspberry Pi)

---

**🎉 Your system is production-ready for local operation!**

