# Day Testing & Development Checklist

## Quick Start

Copy these files to your Raspberry Pi:
- `test_hivemq_command.py` - Sends commands to HiveMQ
- `test_bridge_debug.py` - Monitors local MQTT

---

## 9:00 AM - 10:30 AM: Debug MQTT Commands

### Checklist

- [ ] **Check bridge status**
  ```bash
  sudo systemctl status mqtt-bridge
  ```

- [ ] **View bridge logs** (in one terminal)
  ```bash
  sudo journalctl -u mqtt-bridge.service -f
  ```

- [ ] **Monitor local MQTT** (in another terminal)
  ```bash
  python3 test_bridge_debug.py
  ```

- [ ] **Open ESP32 Serial Monitor**
  - Arduino IDE Serial Monitor
  - Or: PlatformIO monitor
  - Baud: 115200

- [ ] **Send test command from cloud**
  - On your dev machine: `python3 test_hivemq_command.py`
  - Type: `1` for start command

- [ ] **Watch all three outputs simultaneously**
  - Bridge logs should show: `← LOCAL: almed/ahu/.../cmd`
  - Local MQTT monitor should show command
  - ESP32 Serial Monitor should show: "MQTT message received"

- [ ] **Check device discovery**
  - Look in bridge logs for: `✓ Device discovered: ahu-01`
  - If missing, ESP32 needs to publish telemetry first

### Expected Results

✅ Bridge receives command from HiveMQ  
✅ Bridge forwards to local Mosquitto  
✅ ESP32 receives command  
✅ ESP32 executes action  
✅ ESP32 publishes state update  

---

## 10:30 AM - 11:30 AM: Fix Issues

### Common Fixes

**If device not discovered:**
```bash
# Restart ESP32 or power cycle
# Wait for telemetry to be published
# Check bridge logs for discovery message
```

**If bridge not forwarding:**
```bash
# Check bridge config:
cat mqtt_bridge.py | grep CLOUD_BROKER

# Restart bridge:
sudo systemctl restart mqtt-bridge

# Check logs for errors
```

**If ESP32 not receiving:**
```bash
# Check topic matches exactly:
# Bridge expects: almed/ahu/hospitalA/icu1/ahu-01/cmd
# Verify in ESP32 code
```

---

## 11:30 AM - 12:30 PM: Test All Commands

Run through each command and verify:

1. `{"start": true}` → System starts, M1 runs, fan LOW
2. `{"fanSpeed": 1}` → Fan LOW (5V)
3. `{"fanSpeed": 2}` → Fan MID (9V)
4. `{"fanSpeed": 3}` → Fan HIGH (12V)
5. `{"fanToggle": true}` → Fan cycles through speeds
6. `{"setpoint": 23.5}` → Temp setpoint changes
7. `{"humiditySetpoint": 60}` → Humidity setpoint changes
8. `{"stop": true}` → System stops, M1 runs drain

---

## 1:30 PM - 2:30 PM: InfluxDB Setup

Follow: `InfluxDB_quick_setup_guide.md`

### Checklist

- [ ] Create account → cloud2.influxdata.com
- [ ] Create organization: "ALMED AHU"
- [ ] Create bucket: "ahu_telemetry"
- [ ] Generate API token (Read/Write)
- [ ] Save credentials
- [ ] Install client: `pip3 install influxdb-client`
- [ ] Run `test_influx.py` (create this from guide)
- [ ] Integrate with bridge
- [ ] Verify data writing

---

## 2:30 PM - 3:30 PM: Firebase Setup

Follow: `Firebase_quick_setup_guide.md`

### Checklist

- [ ] Create project: "ALMED AHU"
- [ ] Enable Authentication → Email/Password
- [ ] Create test user
- [ ] Create Firestore database
- [ ] Create collections: users, devices, tickets
- [ ] Get Firebase config
- [ ] Download service account key
- [ ] Test with `test_firebase.py` (create from guide)

---

## 3:30 PM - 4:30 PM: Flutter Setup

### Checklist

- [ ] Create project: `flutter create almed_ahu_mobile`
- [ ] Update `pubspec.yaml` with dependencies
- [ ] Run: `flutter pub get`
- [ ] Install FlutterFire CLI
- [ ] Run: `flutterfire configure`
- [ ] Create folder structure
- [ ] Update `main.dart` with Firebase init

---

## 4:30 PM - 5:30 PM: Build Login

### Checklist

- [ ] Create `AuthService`
- [ ] Implement sign in/out methods
- [ ] Create `LoginScreen` UI
- [ ] Add form validation
- [ ] Test login with Firebase user
- [ ] Handle errors

---

## 5:30 PM - 6:00 PM: MQTT Service

### Checklist

- [ ] Create `MqttService`
- [ ] Connect to HiveMQ Cloud
- [ ] Subscribe to telemetry topics
- [ ] Implement publish method
- [ ] Test receiving ESP32 data
- [ ] Test sending command

---

## End of Day Checklist

- [ ] All commands working via HiveMQ ✓
- [ ] InfluxDB storing data ✓
- [ ] Firebase auth working ✓
- [ ] Flutter app structure created ✓
- [ ] Login screen working ✓
- [ ] MQTT service receiving data ✓

---

## Troubleshooting Commands

**Restart bridge:**
```bash
sudo systemctl restart mqtt-bridge
```

**Restart Mosquitto:**
```bash
sudo systemctl restart mosquitto
```

**Check bridge config:**
```bash
cat ~/Documents/almed_ahu/mqtt_bridge.py | grep -A 5 "CLOUD_BROKER"
```

**Test local MQTT:**
```bash
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t "test" -m "hello"
```

---

Good luck! 💪

