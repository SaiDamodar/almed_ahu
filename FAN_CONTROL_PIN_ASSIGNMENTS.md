# Fan Control - Pin Assignments & Quick Reference

## ✅ ESP32 Pin Assignments (3 LM2596 + 3 Relay Method)

### Your Available Pins Used

```
Fan Control:
  GPIO 18 → Relay #1 (LOW - connects LM2596 #1 @ 5V to fan)
  GPIO 5  → Relay #2 (MID - connects LM2596 #2 @ 9V to fan)
  GPIO 4  → Relay #3 (HIGH - connects LM2596 #3 @ 12V to fan)
```

**Note**: GPIO 35 and 34 are input-only pins, so they can't be used for relay control.

---

## Complete Pin Assignments

### Existing Pins (Don't Change)
```
Sensors:
  GPIO 21 → SHT45 SDA
  GPIO 22 → SHT45 SCL

Motors:
  GPIO 25 → M1 IN1
  GPIO 26 → M1 IN2
  GPIO 33 → M1 ENA
  GPIO 27 → M2 IN3
  GPIO 14 → M2 IN4
  GPIO 32 → M2 ENB

Relays:
  GPIO 23 → Compressor Relay
  GPIO 19 → Heater Relay
```

### New Fan Control Pins
```
Fan Relays (NEW):
  GPIO 18 → Fan Relay LOW  (LM2596 #1: 5V)
  GPIO 5  → Fan Relay MID  (LM2596 #2: 9V)
  GPIO 4  → Fan Relay HIGH (LM2596 #3: 12V)
```

### Remaining Available Pins
```
Unused (Available for future use):
  GPIO 13 (D13)
  GPIO 12 (D12)
  GPIO 35 (D35 - INPUT ONLY)
  GPIO 34 (D34 - INPUT ONLY)
  GPIO 2  (D2 - can cause boot issues if pulled LOW)
```

---

## Complete Code Additions

### 1. Pin Definitions

```cpp
// ========== FAN CONTROL (3 LM2596 + 3 Relay Method) ==========
// Each relay connects one LM2596 output to the fan
#define PIN_FAN_RELAY_LOW  18  // Relay #1: Connects LM2596 #1 (5V) to fan
#define PIN_FAN_RELAY_MID  5   // Relay #2: Connects LM2596 #2 (9V) to fan
#define PIN_FAN_RELAY_HIGH 4   // Relay #3: Connects LM2596 #3 (12V) to fan

// Fan speed modes
enum FanSpeed {
  FAN_OFF = 0,
  FAN_LOW = 1,    // 5V (low speed) - LM2596 #1
  FAN_MID = 2,    // 9V (medium speed) - LM2596 #2
  FAN_HIGH = 3    // 12V (high speed) - LM2596 #3
};

FanSpeed fanSpeed = FAN_OFF;
bool fanOn = false;

// Fan control parameters
const float TEMP_FAN_LOW = 24.0;   // °C - Switch to LOW at this temp
const float TEMP_FAN_MID = 26.0;   // °C - Switch to MID at this temp
const float TEMP_FAN_HIGH = 28.0;  // °C - Switch to HIGH at this temp
const float HUM_FAN_THRESHOLD = 65.0;  // %RH - Turn on fan if humidity high
```

### 2. Fan Control Function

```cpp
// ========== FAN CONTROL FUNCTIONS (3 LM2596 + 3 Relay) ==========

// Set fan speed - only ONE relay ON at a time
void setFanSpeed(FanSpeed speed) {
  if (speed == fanSpeed) return;  // No change needed
  
  // IMPORTANT: Turn OFF all relays first (safety - prevents short circuits)
  digitalWrite(PIN_FAN_RELAY_LOW, LOW);
  digitalWrite(PIN_FAN_RELAY_MID, LOW);
  digitalWrite(PIN_FAN_RELAY_HIGH, LOW);
  delay(50);  // Allow relays to settle before switching
  
  fanSpeed = speed;
  
  switch (speed) {
    case FAN_OFF:
      // All relays already OFF
      fanOn = false;
      motorLogMsg("Fan: OFF");
      break;
      
    case FAN_LOW:
      // Connect LM2596 #1 (5V) to fan
      digitalWrite(PIN_FAN_RELAY_LOW, HIGH);  // Relay #1 ON
      fanOn = true;
      motorLogMsg("Fan: LOW speed (5V)");
      break;
      
    case FAN_MID:
      // Connect LM2596 #2 (9V) to fan
      digitalWrite(PIN_FAN_RELAY_MID, HIGH);  // Relay #2 ON
      fanOn = true;
      motorLogMsg("Fan: MID speed (9V)");
      break;
      
    case FAN_HIGH:
      // Connect LM2596 #3 (12V) to fan
      digitalWrite(PIN_FAN_RELAY_HIGH, HIGH);  // Relay #3 ON
      fanOn = true;
      motorLogMsg("Fan: HIGH speed (12V)");
      break;
  }
  
  publishState();  // Update state
}

// Automatic fan control based on temperature/humidity
void controlFan(float temp, float hum) {
  if (!runState) {
    // System not running -> turn off fan
    if (fanOn) {
      setFanSpeed(FAN_OFF);
    }
    return;
  }
  
  if (isnan(temp)) return;  // Need valid temperature reading
  
  // Temperature-based speed control
  if (temp >= TEMP_FAN_HIGH) {
    setFanSpeed(FAN_HIGH);
  } else if (temp >= TEMP_FAN_MID) {
    setFanSpeed(FAN_MID);
  } else if (temp >= TEMP_FAN_LOW) {
    setFanSpeed(FAN_LOW);
  } else if (hum >= HUM_FAN_THRESHOLD) {
    // High humidity -> run at low speed
    setFanSpeed(FAN_LOW);
  } else {
    // Normal conditions -> fan off
    setFanSpeed(FAN_OFF);
  }
}
```

### 3. Setup Function Addition

```cpp
void setup() {
  // ... existing setup code (watchdog, motors, sensors) ...
  
  // ========== FAN CONTROL PIN SETUP (3 LM2596 + 3 Relay) ==========
  pinMode(PIN_FAN_RELAY_LOW, OUTPUT);
  pinMode(PIN_FAN_RELAY_MID, OUTPUT);
  pinMode(PIN_FAN_RELAY_HIGH, OUTPUT);
  
  // All relays OFF at boot (fan OFF)
  digitalWrite(PIN_FAN_RELAY_LOW, LOW);
  digitalWrite(PIN_FAN_RELAY_MID, LOW);
  digitalWrite(PIN_FAN_RELAY_HIGH, LOW);
  
  motorLogMsg("✓ Fan control initialized (3 LM2596 + 3 relay)");
  Serial.println("  Fan Relay LOW:  GPIO 18 (LM2596 #1: 5V)");
  Serial.println("  Fan Relay MID:  GPIO 5  (LM2596 #2: 9V)");
  Serial.println("  Fan Relay HIGH: GPIO 4  (LM2596 #3: 12V)");
  
  // ... rest of setup ...
}
```

### 4. Loop Function Addition

```cpp
void loop() {
  // ... existing code (MQTT, WiFi, motors) ...
  
  // ========== FAN CONTROL ==========
  controlFan(filtTempC, filtHum);
  
  // ... rest of loop ...
}
```

### 5. Update publishTelemetry() Function

**Find your existing `publishTelemetry()` function and add fan status**:

```cpp
void publishTelemetry() {
  StaticJsonDocument<512> doc;
  
  // Sensor data
  if (isnan(filtTempC)) doc["temp"] = nullptr; 
  else doc["temp"] = filtTempC;
  
  if (isnan(filtHum)) doc["hum"] = nullptr; 
  else doc["hum"] = filtHum;
  
  // Motor status
  doc["m1"] = m1Active;
  doc["m2"] = m2Active;
  doc["run"] = runState;
  
  // Relay status
  doc["cp"] = cpOn;
  doc["heater"] = heatOn;
  
  // Fan status (NEW) ← ADD THIS
  doc["fan"] = fanOn;
  doc["fanSpeed"] = (int)fanSpeed;  // 0=OFF, 1=LOW, 2=MID, 3=HIGH
  
  // Setpoints
  doc["tempSet"] = tempSet;
  doc["humSet"] = humSet;
  doc["ts"] = millis();
  
  char buf[576];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  // Publish to LOCAL broker
  if (mqttLocal.connected()) {
    mqttLocal.publish(tTelemetry().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
  
  // Publish to CLOUD broker
  if (mqttCloud.connected()) {
    mqttCloud.publish(tTelemetry().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
}
```

### 6. Update onMqttMessage() Function

**Find your existing `onMqttMessage()` function and add fan commands**:

```cpp
void onMqttMessage(char* topic, byte* payload, unsigned int len) {
  String tStr(topic);
  
  // ... existing provisioning handling ...
  
  if (tStr != tCmd()) return;
  
  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, payload, len)) return;
  
  // ... existing commands (start, stop, setpoint) ...
  
  // ========== FAN CONTROL COMMANDS (NEW) ==========
  if (doc.containsKey("fan")) {
    int speed = doc["fan"].as<int>();
    if (speed >= 0 && speed <= 3) {
      setFanSpeed((FanSpeed)speed);
      motorLogMsg("Fan speed set to: " + String(speed));
    }
  }
  
  if (doc.containsKey("fanAuto")) {
    bool autoMode = doc["fanAuto"].as<bool>();
    // Store auto mode preference if needed
    prefs.putBool("fanAuto", autoMode);
    motorLogMsg("Fan auto mode: " + String(autoMode ? "ON" : "OFF"));
  }
}
```

---

## Wiring Diagram

### Relay Module Connections (3 modules needed)

**For Relay #1 (LOW - 5V)**:
```
Relay Module #1:
  IN  → ESP32 GPIO 18
  VCC → ESP32 5V
  GND → ESP32 GND
  COM → LM2596 #1 OUT+ (5V output)
  NO  → Fan+ (positive terminal)
  NC  → Not connected (or GND)
```

**For Relay #2 (MID - 9V)**:
```
Relay Module #2:
  IN  → ESP32 GPIO 5
  VCC → ESP32 5V
  GND → ESP32 GND
  COM → LM2596 #2 OUT+ (9V output)
  NO  → Fan+ (positive terminal)
  NC  → Not connected (or GND)
```

**For Relay #3 (HIGH - 12V)**:
```
Relay Module #3:
  IN  → ESP32 GPIO 4
  VCC → ESP32 5V
  GND → ESP32 GND
  COM → LM2596 #3 OUT+ (12V output)
  NO  → Fan+ (positive terminal)
  NC  → Not connected (or GND)
```

**Fan Connection**:
```
Fan:
  Fan+ → All relay NO contacts (only one connected at a time)
  Fan- → GND (common ground - connect to all LM2596 OUT-)
```

**Important**: All three relay NO contacts should connect to the SAME fan+ terminal. Only one relay will be ON at any time.

---

## LM2596 Setup

### Preset Each LM2596 to Correct Voltage

**LM2596 #1 (LOW speed)**:
1. Connect 12V input
2. Use multimeter on output
3. Adjust potentiometer until output reads **5.0V**
4. Mark as "LOW"

**LM2596 #2 (MID speed)**:
1. Connect 12V input
2. Use multimeter on output
3. Adjust potentiometer until output reads **9.0V**
4. Mark as "MID"

**LM2596 #3 (HIGH speed)**:
1. Connect 12V input
2. Use multimeter on output
3. Adjust potentiometer until output reads **12.0V**
4. Mark as "HIGH"

**Don't change these settings** - they're preset for each speed mode.

---

## Testing

### Test 1: Manual Relay Test

```cpp
// Add to loop() for testing
// Test relay #1 (LOW)
digitalWrite(PIN_FAN_RELAY_LOW, HIGH);
delay(1000);
digitalWrite(PIN_FAN_RELAY_LOW, LOW);

// Test relay #2 (MID)
digitalWrite(PIN_FAN_RELAY_MID, HIGH);
delay(1000);
digitalWrite(PIN_FAN_RELAY_MID, LOW);

// Test relay #3 (HIGH)
digitalWrite(PIN_FAN_RELAY_HIGH, HIGH);
delay(1000);
digitalWrite(PIN_FAN_RELAY_HIGH, LOW);
```

**Expected**: Fan should spin at different speeds when each relay is ON.

### Test 2: MQTT Command Test

```bash
# Test fan LOW speed
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":1}'

# Test fan MID speed
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":2}'

# Test fan HIGH speed
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":3}'

# Test fan OFF
mosquitto_pub -h 10.42.0.1 -p 1883 -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":0}'
```

**Expected Serial Monitor output**:
```
Fan: LOW speed (5V)
Fan: MID speed (9V)
Fan: HIGH speed (12V)
Fan: OFF
```

---

## Pin Summary

### All ESP32 Pins Used

```
✅ Used Pins (14 pins):
  GPIO 21 → SHT45 SDA
  GPIO 22 → SHT45 SCL
  GPIO 25 → M1 IN1
  GPIO 26 → M1 IN2
  GPIO 33 → M1 ENA
  GPIO 27 → M2 IN3
  GPIO 14 → M2 IN4
  GPIO 32 → M2 ENB
  GPIO 23 → Compressor Relay
  GPIO 19 → Heater Relay
  GPIO 18 → Fan Relay LOW  (NEW)
  GPIO 5  → Fan Relay MID  (NEW)
  GPIO 4  → Fan Relay HIGH (NEW)

⚠️ Available Pins (for future use):
  GPIO 13 (D13)
  GPIO 12 (D12)
  GPIO 35 (D35 - INPUT ONLY)
  GPIO 34 (D34 - INPUT ONLY)
  GPIO 2  (D2 - use with caution)
```

---

## Quick Checklist

- [ ] Wire 3 LM2596 modules (each preset to 5V, 9V, 12V)
- [ ] Wire 3 relay modules
- [ ] Connect relays to ESP32 GPIO 18, 5, 4
- [ ] Connect LM2596 outputs to relay COM contacts
- [ ] Connect fan+ to all relay NO contacts
- [ ] Connect fan- to GND
- [ ] Add code to esp32_main.ino
- [ ] Upload to ESP32
- [ ] Test each relay manually
- [ ] Test via MQTT commands
- [ ] Verify automatic control works

---

**For complete guide**: See `ESP32_FAN_CONTROL_DUAL_BROKER.md`

**Last Updated**: October 30, 2025

