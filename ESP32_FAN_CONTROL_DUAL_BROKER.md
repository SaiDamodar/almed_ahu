# ESP32 Fan Control with Dual-Broker MQTT Guide

**Complete implementation for ESP32 with fan control (relay + buck DC-DC converter) and dual-broker MQTT support**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Hardware Components](#hardware-components)
3. [Wiring Diagram](#wiring-diagram)
4. [Fan Control Implementation](#fan-control-implementation)
5. [Dual-Broker MQTT Setup](#dual-broker-mqtt-setup)
6. [Complete Code Structure](#complete-code-structure)
7. [MQTT Command Reference](#mqtt-command-reference)
8. [Testing & Verification](#testing--verification)
9. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

### What This Guide Provides

✅ **Fan Control System**:
- Relay-based ON/OFF control
- Buck DC-DC converter for voltage regulation
- Three speed modes: LOW, MID, HIGH
- Automatic speed control based on temperature/humidity

✅ **Dual-Broker MQTT**:
- Local broker (Raspberry Pi) - Priority 1
- Cloud broker (HiveMQ) - Priority 2
- Automatic failover and redundancy

✅ **Complete Integration**:
- Temperature/humidity sensors
- Motor control (M1, M2)
- Compressor control
- Heater control
- Fan control (NEW)

---

## ⚡ Quick Reference - Your Setup (3 LM2596 + 3 Relay)

### ESP32 Pin Assignments

```
Fan Control Pins:
  GPIO 18 (D18) → Relay #1 LOW  (LM2596 #1: 5V)
  GPIO 5  (D5)  → Relay #2 MID  (LM2596 #2: 9V)
  GPIO 4  (D4)  → Relay #3 HIGH (LM2596 #3: 12V)
```

### Wiring Summary

```
12V Power Supply
    │
    ├──→ LM2596 #1 IN ──→ OUT (5V preset) ──→ Relay #1 COM ──┐
    ├──→ LM2596 #2 IN ──→ OUT (9V preset) ──→ Relay #2 COM ──┤
    ├──→ LM2596 #3 IN ──→ OUT (12V preset) ──→ Relay #3 COM ─┘
    │                                                        │
    │                                                        └──→ Fan+
    │
    └──→ ESP32
          ├──→ GPIO 18 ──→ Relay #1 IN
          ├──→ GPIO 5  ──→ Relay #2 IN
          └──→ GPIO 4  ──→ Relay #3 IN
```

**Important**: Only ONE relay ON at a time. All OFF = Fan OFF.

For complete code and wiring details, see sections below.

---

## 🔧 Hardware Components

### Required Components

1. **ESP32 DevKit** (main controller)
2. **SHT45 Sensor** (temperature/humidity)
3. **L298N Motor Driver** (for motors M1, M2)
4. **Relays** (for compressor, heater, fan)
5. **Buck DC-DC Converter** (for fan voltage control)
6. **Fan** (12V DC fan)

### Fan Control Components (Your Setup)

#### LM2596 Buck Converters (3 modules needed)
- **Type**: LM2596 adjustable buck converter modules
- **Quantity**: 3 modules
- **Input**: 12V (from power supply)
- **Output**: 
  - LM2596 #1: Preset to **5.0V** (LOW speed)
  - LM2596 #2: Preset to **9.0V** (MID speed)
  - LM2596 #3: Preset to **12.0V** (HIGH speed)
- **Current**: Up to 3A each
- **Setup**: Adjust potentiometer on each module to desired voltage (use multimeter)

#### Relay Modules (3 modules needed)
- **Type**: 5V SPDT Relay Module
- **Quantity**: 3 modules
- **Function**: Select which LM2596 output connects to fan
- **Rating**: 10A @ 250V AC / 10A @ 30V DC
- **Control**: Via ESP32 GPIO pins (18, 5, 4)

#### Fan Specifications
- **Voltage**: 12V DC (will receive 5V, 9V, or 12V depending on relay selection)
- **Current**: 0.5A - 2A (depending on speed/voltage)
- **Type**: Axial or centrifugal fan

---

## 📐 Wiring Diagram

### Complete System Wiring

```
┌─────────────────────────────────────────────────────────────┐
│                    POWER SUPPLY (12V)                         │
│                                                              │
│  ┌──────────────┐                                           │
│  │  12V Input   │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ├───→ ESP32 (via 5V regulator)                      │
│         ├───→ L298N (motor driver)                          │
│         ├───→ Buck Converter (12V input)                    │
│         └───→ Relay modules                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    FAN CONTROL CIRCUIT                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Buck DC-DC Converter                                        │
│  ┌────────────────────┐                                     │
│  │ IN+  IN-           │                                     │
│  │ 12V  GND           │←── 12V Power Supply                  │
│  │                    │                                     │
│  │ OUT+ OUT- ADJ      │                                     │
│  │ │    │    │        │                                     │
│  │ │    │    └────────┴──→ ESP32 GPIO (PWM for voltage)    │
│  │ │    │    (optional - manual adjustment)                │
│  │ │    │                                                  │
│  │ │    └──→ GND (common ground)                          │
│  │ │                                                       │
│  │ └──→ Relay Module (SPDT)                               │
│  │      ┌────────────┐                                     │
│  │      │ COM        │                                     │
│  │      │ NC  NO     │                                     │
│  │      └────┬───┬───┘                                     │
│  │           │   │                                         │
│  │           │   └──────────→ Fan + (positive)            │
│  │           │                                             │
│  │           └──────────→ GND (fan OFF position)          │
│  │                                                         │
│  │      Relay Control:                                     │
│  │      IN ←── ESP32 GPIO (PIN_FAN_RELAY)                 │
│  └───────────────────────────────────────────────────────┘
│                                                              │
│  Buck Output Voltage Selection (via relay switching):       │
│                                                              │
│  LOW  Mode:  Relay switches to 5V output                    │
│  MID  Mode:  Relay switches to 9V output                    │
│  HIGH Mode:  Relay switches to 12V output                  │
│                                                              │
│  Alternative: Use PWM on buck converter ADJ pin            │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    ESP32 PIN CONNECTIONS                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SENSORS:                                                    │
│  • SHT45 SDA → GPIO 21                                      │
│  • SHT45 SCL → GPIO 22                                      │
│                                                              │
│  MOTORS (L298N):                                            │
│  • M1 IN1  → GPIO 25                                        │
│  • M1 IN2  → GPIO 26                                        │
│  • M1 ENA  → GPIO 33                                        │
│  • M2 IN3  → GPIO 27                                        │
│  • M2 IN4  → GPIO 14                                        │
│  • M2 ENB  → GPIO 32                                        │
│                                                              │
│  RELAYS:                                                     │
│  • Compressor Relay → GPIO 23 (PIN_CP)                     │
│  • Heater Relay    → GPIO 19 (PIN_HEAT)                    │
│  • Fan Relay LOW   → GPIO 18 (LM2596 #1: 5V)               │
│  • Fan Relay MID   → GPIO 5  (LM2596 #2: 9V)              │
│  • Fan Relay HIGH  → GPIO 4  (LM2596 #3: 12V)              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Simplified Buck Converter + Relay Method

**Recommended Approach**: Use relay to switch between preset voltages

```
12V Power Supply
    │
    ├───→ Buck Converter IN+
    │         │
    │         ├──→ Adjust to 5V  → Relay Position 1 (LOW)
    │         ├──→ Adjust to 9V  → Relay Position 2 (MID)
    │         └──→ Adjust to 12V → Relay Position 3 (HIGH)
    │
    └───→ Relay Module Control
              │
              └──→ ESP32 GPIO 18 (PIN_FAN_RELAY)

Fan
    │
    ├───→ Fan + ←── Relay COM (selects voltage)
    └───→ Fan - ←── GND
```

---

## 💻 Fan Control Implementation

### 1. Pin Definitions (3 LM2596 + 3 Relay Method)

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

### 2. Fan Control Functions (3 Relay Method)

```cpp
// ========== FAN CONTROL FUNCTIONS (3 LM2596 + 3 Relay) ==========

// Set fan speed - only ONE relay ON at a time
// Each relay connects one LM2596 output (5V, 9V, or 12V) to the fan
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

### 3. Setup Configuration

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

### 4. Main Loop Integration

```cpp
void loop() {
  // ... existing code (MQTT, WiFi, motors) ...
  
  // ========== FAN CONTROL ==========
  controlFan(filtTempC, filtHum);
  
  // ... rest of loop ...
}
```

---

## 🌐 Dual-Broker MQTT Setup

### Complete MQTT Configuration

```cpp
// ========== MQTT LOCAL (Priority 1: Raspberry Pi) ==========
WiFiClient espNetLocal;
PubSubClient mqttLocal(espNetLocal);

const char* MQTT_USER_LOCAL = "almed";
const char* MQTT_PASS_LOCAL = "Almed1234$";
const uint16_t MQTT_PORT_LOCAL = 1883;
String mqttHostLocal = "10.42.0.1";

// ========== MQTT CLOUD (Priority 2: HiveMQ Cloud) ==========
WiFiClientSecure espNetCloud;
PubSubClient mqttCloud(espNetCloud);

const char* MQTT_USER_CLOUD = "almed";
const char* MQTT_PASS_CLOUD = "AlMed123456";  // YOUR HiveMQ password
const uint16_t MQTT_PORT_CLOUD = 8883;
String mqttHostCloud = "ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud";  // YOUR cluster URL

// Topic definitions
const char* ORG  = "almed";
const char* SITE = "hospitalA";
const char* ROOM = "icu1";
const char* AHU  = "ahu-01";

String baseTopic()        { return String(ORG)+"/ahu/"+SITE+"/"+ROOM+"/"+AHU; }
String tTelemetry()       { return baseTopic()+"/telemetry"; }
String tState()           { return baseTopic()+"/state"; }
String tCmd()             { return baseTopic()+"/cmd"; }
String tLog()             { return baseTopic()+"/log"; }
String tStatus()          { return baseTopic()+"/status"; }
```

### Dual Connection Functions

```cpp
// ========== LOCAL MQTT CONNECTION (Priority 1) ==========
void ensureMqttLocal() {
  if (mqttLocal.connected()) return;
  if (WiFi.status() != WL_CONNECTED) return;
  
  static unsigned long lastLocalAttempt = 0;
  unsigned long now = millis();
  if (now - lastLocalAttempt < 2000) return;
  lastLocalAttempt = now;
  
  mqttLocal.setServer(mqttHostLocal.c_str(), MQTT_PORT_LOCAL);
  mqttLocal.setCallback(onMqttMessage);
  
  String clientId = String(AHU) + "_local_" + String((uint32_t)ESP.getEfuseMac(), HEX);
  
  if (mqttLocal.connect(clientId.c_str(), MQTT_USER_LOCAL, MQTT_PASS_LOCAL,
                       tStatus().c_str(), 1, true, "offline")) {
    mqttLocal.subscribe(tCmd().c_str(), 1);
    mqttLocal.subscribe((String(ORG) + "/ahu/+/+/" + String(AHU) + "/provision/#").c_str(), 1);
    
    motorLogMsg("✓ LOCAL MQTT connected (" + mqttHostLocal + ":" + String(MQTT_PORT_LOCAL) + ")");
    publishStatusOnline();
    publishState();
  } else {
    Serial.print("✗ LOCAL MQTT connect failed, rc=");
    Serial.println(mqttLocal.state());
  }
}

// ========== CLOUD MQTT CONNECTION (Priority 2) ==========
void ensureMqttCloud() {
  if (mqttCloud.connected()) return;
  if (WiFi.status() != WL_CONNECTED) return;
  
  // Only try cloud connection every 30 seconds (lower priority)
  static unsigned long lastCloudAttempt = 0;
  unsigned long now = millis();
  if (now - lastCloudAttempt < 30000) return;
  lastCloudAttempt = now;
  
  mqttCloud.setServer(mqttHostCloud.c_str(), MQTT_PORT_CLOUD);
  mqttCloud.setCallback(onMqttMessage);
  
  String clientId = String(AHU) + "_cloud_" + String((uint32_t)ESP.getEfuseMac(), HEX);
  
  if (mqttCloud.connect(clientId.c_str(), MQTT_USER_CLOUD, MQTT_PASS_CLOUD,
                       tStatus().c_str(), 1, true, "offline")) {
    mqttCloud.subscribe(tCmd().c_str(), 1);
    
    motorLogMsg("✓ CLOUD MQTT connected (" + mqttHostCloud + ":" + String(MQTT_PORT_CLOUD) + ")");
    publishStatusOnline();
    publishState();
  } else {
    Serial.print("✗ CLOUD MQTT connect failed, rc=");
    Serial.println(mqttCloud.state());
  }
}
```

### Setup TLS Configuration

```cpp
void setup() {
  // ... existing setup ...
  
  // ========== MQTT BROKER CONFIGURATION ==========
  // Configure TLS for CLOUD broker (HiveMQ)
  espNetCloud.setInsecure();  // Skip certificate validation (for simplicity)
  Serial.println("✓ Local MQTT configured (Raspberry Pi:" + String(MQTT_PORT_LOCAL) + ")");
  Serial.println("✓ Cloud MQTT configured (HiveMQ:" + String(MQTT_PORT_CLOUD) + " TLS)");
  
  // ... rest of setup ...
}
```

### Loop Integration

```cpp
void loop() {
  // ... watchdog, WiFi, recovery checks ...
  
  // ========== MQTT MAINTENANCE (Priority 1: Local, Priority 2: Cloud) ==========
  if (WiFi.status() == WL_CONNECTED) { 
    // LOCAL MQTT (Priority 1)
    ensureMqttLocal();
    if (mqttLocal.connected()) mqttLocal.loop();
    
    // CLOUD MQTT (Priority 2) 
    ensureMqttCloud();
    if (mqttCloud.connected()) mqttCloud.loop();
  }
  
  // ... sensors, motors, fan control, publish ...
}
```

---

## 📤 Publishing Functions (Dual-Broker)

### Telemetry Publishing

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
  
  // Fan status (NEW)
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

### State Publishing

```cpp
void publishState() {
  StaticJsonDocument<640> doc;
  
  // System state
  doc["run"] = runState;
  doc["m1"] = m1Active;
  doc["m2"] = m2Active;
  
  // Relay state
  doc["cp"] = cpOn;
  doc["heater"] = heatOn;
  
  // Fan state (NEW)
  doc["fan"] = fanOn;
  doc["fanSpeed"] = (int)fanSpeed;
  
  // Setpoints
  doc["tempSet"] = tempSet;
  doc["humSet"] = humSet;
  
  // Motor timings
  doc["m1_start"] = M1_START_RUN / 1000UL;
  doc["m1_post"] = M1_POST_RUN / 1000UL;
  doc["m2_interval"] = M2_INTERVAL / 1000UL;
  doc["m2_run"] = M2_RUN_TIME / 1000UL;
  doc["m2_delay"] = M2_DELAY_AFTER_M1_STOP / 1000UL;
  
  // Network info
  doc["ip"] = WiFi.localIP().toString();
  
  char buf[512];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  // Publish to LOCAL broker (retained)
  if (mqttLocal.connected()) {
    mqttLocal.publish(tState().c_str(), reinterpret_cast<const uint8_t*>(buf), n, true);
  }
  
  // Publish to CLOUD broker (retained)
  if (mqttCloud.connected()) {
    mqttCloud.publish(tState().c_str(), reinterpret_cast<const uint8_t*>(buf), n, true);
  }
}
```

### Log Publishing

```cpp
void mqttPublishLog(const char* level, const String& msg) {
  StaticJsonDocument<240> doc;
  doc["ts"] = millis();
  doc["lvl"] = level;
  doc["msg"] = msg;
  
  char buf[280];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  // Publish to LOCAL broker
  if (mqttLocal.connected()) {
    mqttLocal.publish(tLog().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
  
  // Publish to CLOUD broker
  if (mqttCloud.connected()) {
    mqttCloud.publish(tLog().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
}
```

---

## 📨 MQTT Command Reference

### Complete Command Structure

```json
// Topic: almed/ahu/hospitalA/icu1/ahu-01/cmd

// System control
{
  "start": true      // Start system
}
{
  "stop": true       // Stop system
}
{
  "toggle": true     // Toggle run state
}

// Setpoints
{
  "setpoint": 23.5   // Temperature setpoint (°C)
}
{
  "humset": 55.0     // Humidity setpoint (%RH)
}

// Fan control (NEW)
{
  "fan": 0           // Fan OFF
}
{
  "fan": 1           // Fan LOW speed
}
{
  "fan": 2           // Fan MID speed
}
{
  "fan": 3           // Fan HIGH speed
}
{
  "fanAuto": true    // Enable automatic fan control
}
{
  "fanAuto": false   // Disable automatic fan control (manual mode)
}

// Motor timings (provisioning)
{
  "m1_start": 10,
  "m1_post": 10,
  "m2_interval": 30,
  "m2_run": 10,
  "m2_delay": 5
}
```

### MQTT Command Handler

```cpp
void onMqttMessage(char* topic, byte* payload, unsigned int len) {
  String tStr(topic);
  
  // Handle provisioning messages first
  if (tStr == tProvWifi() || tStr == tProvBroker() || tStr == tProvMotorTimings()) {
    handleProvisioning(topic, payload, len);
    return;
  }
  
  if (tStr != tCmd()) return;
  
  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, payload, len)) return;
  
  // System control
  if (doc["start"]) startSystem();
  if (doc["stop"]) stopSystem();
  if (doc["toggle"]) toggleSystem();
  
  // Temperature setpoint
  if (doc.containsKey("setpoint")) {
    float sp = doc["setpoint"];
    if (sp >= 1 && sp <= 100) {
      tempSet = sp;
      prefs.putFloat("tempSet", tempSet);
      motorLogMsg("Temp setpoint: " + String(tempSet, 1) + "°C");
      publishState();
    }
  }
  
  // Humidity setpoint
  if (doc.containsKey("humset")) {
    float hs = doc["humset"];
    if (hs >= 10 && hs <= 90) {
      humSet = hs;
      prefs.putFloat("humSet", humSet);
      motorLogMsg("Humidity setpoint: " + String(humSet, 1) + "%");
      publishState();
    }
  }
  
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
    // Store auto mode preference
    prefs.putBool("fanAuto", autoMode);
    motorLogMsg("Fan auto mode: " + String(autoMode ? "ON" : "OFF"));
  }
}
```

---

## 🧪 Testing & Verification

### Test 1: Fan Speed Control

**Via MQTT Command**:
```bash
# Test from Raspberry Pi (local broker)
mosquitto_pub -h 10.42.0.1 -p 1883 \
  -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":1}'

# Expected Serial Monitor output:
# Fan: LOW speed (5V)
```

```bash
# Test from cloud (HiveMQ)
mosquitto_pub -h ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed -P "AlMed123456" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fan":3}'

# Expected Serial Monitor output:
# Fan: HIGH speed (12V)
```

### Test 2: Automatic Fan Control

**Expected Behavior**:
```
Temperature < 24°C → Fan OFF
Temperature ≥ 24°C → Fan LOW
Temperature ≥ 26°C → Fan MID
Temperature ≥ 28°C → Fan HIGH
Humidity ≥ 65% → Fan LOW (even if temp low)
```

### Test 3: Dual-Broker Publishing

**Subscribe to both brokers**:

**Terminal 1 (Local)**:
```bash
mosquitto_sub -h 10.42.0.1 -p 1883 \
  -u almed -P "Almed1234$" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/telemetry" -v
```

**Terminal 2 (Cloud)**:
```bash
mosquitto_sub -h ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed -P "AlMed123456" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/telemetry" -v
```

**Expected**: Both terminals show same telemetry messages with fan status.

---

## 🔧 Complete Code Structure

### Header Section

```cpp
#include <WiFi.h>
#include <WiFiClientSecure.h>  // For HiveMQ Cloud TLS
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <esp_task_wdt.h>

// ========== FAN CONTROL DEFINITIONS ==========
#define PIN_FAN_RELAY 18
#define PIN_FAN_PWM 5  // Optional: for PWM control

enum FanSpeed {
  FAN_OFF = 0,
  FAN_LOW = 1,
  FAN_MID = 2,
  FAN_HIGH = 3
};

FanSpeed fanSpeed = FAN_OFF;
bool fanOn = false;
bool fanAutoMode = true;  // Automatic control enabled

const float TEMP_FAN_LOW = 24.0;
const float TEMP_FAN_MID = 26.0;
const float TEMP_FAN_HIGH = 28.0;
const float HUM_FAN_THRESHOLD = 65.0;

// ========== DUAL-BROKER MQTT ==========
WiFiClient espNetLocal;
PubSubClient mqttLocal(espNetLocal);

WiFiClientSecure espNetCloud;
PubSubClient mqttCloud(espNetCloud);

// ... rest of definitions ...
```

### Setup Function

```cpp
void setup() {
  Serial.begin(115200);
  delay(500);
  
  // Watchdog initialization
  esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT * 1000,
    .idle_core_mask = 0,
    .trigger_panic = true
  };
  esp_task_wdt_init(&wdt_config);
  esp_task_wdt_add(NULL);
  
  // Pin initialization
  // ... motors, relays ...
  
  // ========== FAN CONTROL PIN SETUP ==========
  pinMode(PIN_FAN_RELAY, OUTPUT);
  digitalWrite(PIN_FAN_RELAY, LOW);  // Fan OFF at boot
  
  #ifdef PIN_FAN_PWM
    pinMode(PIN_FAN_PWM, OUTPUT);
    ledcSetup(0, 5000, 8);
    ledcAttachPin(PIN_FAN_PWM, 0);
  #endif
  
  // Sensor initialization
  Wire.begin(21, 22);
  sht4.begin();
  
  // Preferences
  prefs.begin("ahu", false);
  
  // Load saved settings
  fanAutoMode = prefs.getBool("fanAuto", true);
  
  // WiFi event handler
  WiFi.onEvent(WiFiEvent);
  
  // ========== MQTT BROKER CONFIGURATION ==========
  espNetCloud.setInsecure();  // TLS for cloud
  
  Serial.println("✓ Local MQTT configured");
  Serial.println("✓ Cloud MQTT configured (TLS)");
  Serial.println("✓ Fan control initialized");
  
  // ... rest of setup ...
}
```

### Main Loop

```cpp
void loop() {
  // Watchdog monitoring
  esp_task_wdt_reset();
  
  // WiFi maintenance
  if (WiFi.status() != WL_CONNECTED) rotateWifiIfNeeded();
  
  // MQTT maintenance (dual-broker)
  if (WiFi.status() == WL_CONNECTED) {
    ensureMqttLocal();
    if (mqttLocal.connected()) mqttLocal.loop();
    
    ensureMqttCloud();
    if (mqttCloud.connected()) mqttCloud.loop();
  }
  
  // Sensors
  readSensorIfDue();
  
  // Controls
  controlCP(filtTempC);
  controlHeater(filtHum);
  
  // ========== FAN CONTROL ==========
  if (fanAutoMode) {
    controlFan(filtTempC, filtHum);  // Automatic control
  }
  // Manual control is handled via MQTT commands
  
  // Motors
  // ... motor control logic ...
  
  // Publish telemetry
  static unsigned long lastTelemetry = 0;
  if (millis() - lastTelemetry > 10000) {
    publishTelemetry();
    lastTelemetry = millis();
  }
  
  delay(5);
}
```

---

## 📊 Telemetry JSON Structure

### Complete Telemetry Message

```json
{
  "temp": 24.5,
  "hum": 62.0,
  "m1": false,
  "m2": false,
  "run": true,
  "cp": true,
  "heater": false,
  "fan": true,
  "fanSpeed": 2,
  "tempSet": 22.0,
  "humSet": 55.0,
  "ts": 12345678
}
```

**Field Descriptions**:
- `fan`: `true` if fan is ON, `false` if OFF
- `fanSpeed`: `0`=OFF, `1`=LOW, `2`=MID, `3`=HIGH

---

## 🛠️ Troubleshooting

### Issue: Fan Not Turning On

**Checklist**:
1. ✅ Verify relay is connected to GPIO 18
2. ✅ Check relay module has power (5V)
3. ✅ Test relay with: `digitalWrite(PIN_FAN_RELAY, HIGH)`
4. ✅ Verify buck converter output voltage
5. ✅ Check fan connections (positive/negative)
6. ✅ Measure fan voltage with multimeter

**Serial Monitor Test**:
```
setFanSpeed(FAN_HIGH);
// Expected: "Fan: HIGH speed (12V)"
```

### Issue: Fan Speed Not Changing

**If using relay switching method**:
- Verify buck converter is manually adjusted to correct voltages
- Check relay is switching properly (test with multimeter)
- Ensure fan receives correct voltage at each setting

**If using PWM method**:
- Check PWM pin (GPIO 5) is not conflicting with other uses
- Verify PWM frequency and resolution settings
- Test with oscilloscope/multimeter

### Issue: Cloud MQTT Not Connecting

**Checklist**:
1. ✅ Verify HiveMQ cluster URL is correct
2. ✅ Check username/password match HiveMQ console
3. ✅ Ensure WiFi has internet connectivity
4. ✅ Test from laptop: `mosquitto_pub` to cloud
5. ✅ Check firewall allows outbound port 8883
6. ✅ Review Serial Monitor for error codes

**Error Codes**:
- `-2`: Network failure (WiFi/internet issue)
- `-1`: Connection refused (credentials wrong)
- `-4`: MQTT CONNACK timeout (firewall blocking)

---

## 📖 References

- **Dual-Broker Setup**: See `ESP32_DUAL_BROKER_CODE.md`
- **Complete System Guide**: See `COMPLETE_SYSTEM_GUIDE.md`
- **HiveMQ Setup**: See `HIVEMQ_SETUP_QUICK_START.md`

---

## ✅ Implementation Checklist

- [ ] Hardware wiring (fan, relay, buck converter)
- [ ] Buck converter voltage adjustment (5V, 9V, 12V)
- [ ] ESP32 pin connections
- [ ] Code modifications (add fan control functions)
- [ ] Test fan ON/OFF via relay
- [ ] Test fan speed switching (LOW/MID/HIGH)
- [ ] Test automatic fan control (temperature-based)
- [ ] Test MQTT commands (fan speed, fanAuto)
- [ ] Verify dual-broker publishing
- [ ] Test from local broker
- [ ] Test from cloud broker
- [ ] Verify telemetry includes fan status
- [ ] Integration testing (fan + motors + compressor + heater)

---

**Last Updated**: October 30, 2025  
**Status**: Complete guide ready for implementation  
**Next Steps**: Wire hardware → Update code → Test → Deploy

