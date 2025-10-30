# ESP32 Dual-Broker Implementation Code

## Complete Code for Hybrid Local + Cloud Architecture

This document provides the complete ESP32 code changes needed to connect to BOTH local Mosquitto (Raspberry Pi) AND HiveMQ Cloud simultaneously.

---

## Code Changes Summary

### 1. Add Includes
```cpp
#include <WiFi.h>
#include <WiFiClientSecure.h>  // ADD THIS for cloud TLS connection
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <esp_task_wdt.h>
```

### 2. Create Two MQTT Client Objects

**REPLACE THIS**:
```cpp
// ---------- MQTT ----------
WiFiClient espNet;
PubSubClient mqtt(espNet);
```

**WITH THIS**:
```cpp
// ========== MQTT LOCAL (Priority 1: Raspberry Pi) ==========
WiFiClient espNetLocal;
PubSubClient mqttLocal(espNetLocal);

// ========== MQTT CLOUD (Priority 2: HiveMQ Cloud) ==========
WiFiClientSecure espNetCloud;
PubSubClient mqttCloud(espNetCloud);
```

### 3. Dual Broker Credentials

**REPLACE THIS**:
```cpp
const char* MQTT_USER = "almed";
const char* MQTT_PASS = "Almed1234$";
uint16_t MQTT_PORT = 1883;
String mqttHost = "10.42.0.1";
```

**WITH THIS**:
```cpp
// ========== LOCAL BROKER (Priority 1: Raspberry Pi) ==========
const char* MQTT_USER_LOCAL = "almed";
const char* MQTT_PASS_LOCAL = "Almed1234$";
const uint16_t MQTT_PORT_LOCAL = 1883;
String mqttHostLocal = "10.42.0.1";

// ========== CLOUD BROKER (Priority 2: HiveMQ Cloud) ==========
const char* MQTT_USER_CLOUD = "almed";
const char* MQTT_PASS_CLOUD = "AlmedHospital2025!#Secure";  // YOUR HiveMQ password
const uint16_t MQTT_PORT_CLOUD = 8883;
String mqttHostCloud = "abc123def456.s2.eu.hivemq.cloud";  // YOUR HiveMQ cluster URL
```

### 4. Setup Configuration

**ADD TO setup() function** (after WiFi event registration):
```cpp
void setup() {
  Serial.begin(115200);
  delay(500);
  
  // ... existing code (watchdog, pins, sensor) ...
  
  // ========== MQTT BROKER CONFIGURATION ==========
  
  // Configure LOCAL broker (Raspberry Pi)
  mqttLocal.setServer(mqttHostLocal.c_str(), MQTT_PORT_LOCAL);
  mqttLocal.setCallback(mqttCallback);
  Serial.println("✓ Local MQTT configured (Raspberry Pi:1883)");
  
  // Configure CLOUD broker (HiveMQ)
  espNetCloud.setInsecure();  // Skip certificate validation
  mqttCloud.setServer(mqttHostCloud.c_str(), MQTT_PORT_CLOUD);
  mqttCloud.setCallback(mqttCallback);
  Serial.println("✓ Cloud MQTT configured (HiveMQ:8883 TLS)");
  
  // ... rest of setup ...
}
```

### 5. Dual Connection Functions

**REPLACE your ensureMqtt() function** with these TWO functions:

```cpp
// ========== LOCAL MQTT CONNECTION (Priority 1) ==========
void ensureMqttLocal() {
  if (mqttLocal.connected()) return;
  
  if (WiFi.status() != WL_CONNECTED) return;
  
  Serial.print("LOCAL MQTT connecting to ");
  Serial.print(mqttHostLocal);
  Serial.print(":");
  Serial.println(MQTT_PORT_LOCAL);
  
  String clientId = String(AHU) + "_local";
  
  if (mqttLocal.connect(clientId.c_str(), MQTT_USER_LOCAL, MQTT_PASS_LOCAL)) {
    Serial.println("✓ LOCAL MQTT connected (Raspberry Pi)");
    
    // Subscribe to command topics
    mqttLocal.subscribe(tCmd().c_str());
    mqttLocal.subscribe((String(ORG) + "/ahu/+/+/" + String(AHU) + "/provision/#").c_str());
    
    // Publish online status
    mqttLocal.publish(tStatus().c_str(), "online", true);
    
    motorLogMsg("LOCAL MQTT connected");
    
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
  if (millis() - lastCloudAttempt < 30000) return;
  lastCloudAttempt = millis();
  
  Serial.print("CLOUD MQTT connecting to ");
  Serial.print(mqttHostCloud);
  Serial.print(":");
  Serial.println(MQTT_PORT_CLOUD);
  
  String clientId = String(AHU) + "_cloud";
  
  if (mqttCloud.connect(clientId.c_str(), MQTT_USER_CLOUD, MQTT_PASS_CLOUD)) {
    Serial.println("✓ CLOUD MQTT connected (HiveMQ Cloud)");
    
    // Subscribe to command topics
    mqttCloud.subscribe(tCmd().c_str());
    mqttCloud.subscribe((String(ORG) + "/ahu/+/+/" + String(AHU) + "/provision/#").c_str());
    
    // Publish online status
    mqttCloud.publish(tStatus().c_str(), "online", true);
    
    motorLogMsg("CLOUD MQTT connected");
    
  } else {
    Serial.print("✗ CLOUD MQTT connect failed, rc=");
    Serial.println(mqttCloud.state());
  }
}
```

### 6. Publish to Both Brokers - Helper Function

**ADD THIS NEW FUNCTION**:
```cpp
// ========== PUBLISH TO BOTH BROKERS ==========
void publishToBoth(const char* topic, const char* payload, bool retained = false) {
  // Publish to LOCAL broker (Priority 1)
  if (mqttLocal.connected()) {
    mqttLocal.publish(topic, payload, retained);
  }
  
  // Publish to CLOUD broker (Priority 2)
  if (mqttCloud.connected()) {
    mqttCloud.publish(topic, payload, retained);
  }
}
```

### 7. Update All Publish Calls

**FIND AND REPLACE** all instances where you publish messages:

**OLD PATTERN**:
```cpp
mqtt.publish(tTelemetry().c_str(), payload.c_str());
mqtt.publish(tState().c_str(), payload.c_str());
mqtt.publish(tLog().c_str(), payload.c_str(), true);
mqtt.publish(tStatus().c_str(), "online", true);
```

**NEW PATTERN**:
```cpp
publishToBoth(tTelemetry().c_str(), payload.c_str());
publishToBoth(tState().c_str(), payload.c_str());
publishToBoth(tLog().c_str(), payload.c_str(), true);
publishToBoth(tStatus().c_str(), "online", true);
```

**OR use explicit calls**:
```cpp
// Manual dual publishing (more control)
if (mqttLocal.connected()) {
  mqttLocal.publish(tTelemetry().c_str(), payload.c_str());
}
if (mqttCloud.connected()) {
  mqttCloud.publish(tTelemetry().c_str(), payload.c_str());
}
```

### 8. Update Main Loop

**REPLACE your loop()**:

**OLD CODE**:
```cpp
void loop() {
  ensureMqtt();
  mqtt.loop();
  
  // ... sensor, motor, publish code ...
  
  esp_task_wdt_reset();
}
```

**NEW CODE**:
```cpp
void loop() {
  // ========== PRIORITY 1: LOCAL MQTT (Always try first) ==========
  ensureMqttLocal();
  mqttLocal.loop();  // Process local messages immediately
  
  // ========== PRIORITY 2: CLOUD MQTT (Try less frequently) ==========
  ensureMqttCloud();
  mqttCloud.loop();  // Process cloud messages
  
  // ========== MAIN LOGIC (Unchanged) ==========
  readSensorIfDue();
  updateMotorLogicIfDue();
  publishStateIfDue();
  publishTelemetryIfDue();
  
  esp_task_wdt_reset();
}
```

---

## MQTT Callback (No Changes Needed)

Your existing `mqttCallback()` function works for BOTH brokers automatically:

```cpp
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // This function receives messages from BOTH brokers
  // PubSubClient automatically calls this when messages arrive
  
  String topicStr = String(topic);
  String msg = "";
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  
  motorLogMsg("MQTT RX: " + topicStr + " = " + msg);
  
  // ... existing command processing ...
  // (start, stop, setpoint, provisioning)
}
```

**Why it works**: Both `mqttLocal` and `mqttCloud` use the same callback, so commands from either local dashboard OR mobile app will be processed identically.

---

## Serial Monitor Output

After uploading, you should see:

```
========================================
   ALMED AHU Controller v2.0
   Watchdog Protection Enabled
========================================
✓ Watchdog enabled (7s timeout)
✓ SHT45 ready
✓ Motor timings loaded
✓ WiFi event handler registered
✓ Local MQTT configured (Raspberry Pi:1883)
✓ Cloud MQTT configured (HiveMQ:8883 TLS)

--- Checking for previous state ---

✓ Boot complete. Ready for commands.
========================================

Wi-Fi: trying PRIMARY SSID: PiSpot
Wi-Fi connected (PRIMARY), IP: 192.168.1.100

LOCAL MQTT connecting to 10.42.0.1:1883
✓ LOCAL MQTT connected (Raspberry Pi)

CLOUD MQTT connecting to abc123def456.s2.eu.hivemq.cloud:8883
✓ CLOUD MQTT connected (HiveMQ Cloud)

Temp: 24.5 °C | Hum: 62.0%
Published telemetry to BOTH brokers
```

---

## Failover Behavior

### Scenario 1: Local Broker Down
```
✗ LOCAL MQTT connect failed, rc=-2
✓ CLOUD MQTT connected (HiveMQ Cloud)
→ Mobile app still works
→ Local dashboard shows offline
```

### Scenario 2: Internet Down (Cloud Unavailable)
```
✓ LOCAL MQTT connected (Raspberry Pi)
✗ CLOUD MQTT connect failed, rc=-2
→ Local dashboard still works
→ Mobile app shows offline
```

### Scenario 3: Both Brokers Available (Normal)
```
✓ LOCAL MQTT connected (Raspberry Pi)
✓ CLOUD MQTT connected (HiveMQ Cloud)
→ Both dashboard and mobile app work
→ Commands from either are processed
```

---

## Memory Considerations

**Before (Single Broker)**:
- 1 WiFiClient
- 1 PubSubClient
- ~2KB RAM

**After (Dual Broker)**:
- 1 WiFiClient + 1 WiFiClientSecure
- 2 PubSubClient
- ~5KB RAM

ESP32 has 520KB RAM, so this is totally fine.

---

## Network Bandwidth

**Telemetry Message** (every 10 seconds):
- Size: ~200 bytes JSON
- Local: 200 bytes
- Cloud: 200 bytes
- **Total**: 400 bytes every 10 seconds = 40 bytes/sec

**Monthly Data Usage**:
- 400 bytes × 6 times/min × 60 min × 24 hr × 30 days
- ≈ **311 MB/month**
- HiveMQ Free: Unlimited data
- Well within limits!

---

## Testing Checklist

After uploading the dual-broker code:

- [ ] ESP32 boots successfully
- [ ] Connects to WiFi (PiSpot)
- [ ] Connects to LOCAL MQTT (Raspberry Pi)
- [ ] Connects to CLOUD MQTT (HiveMQ)
- [ ] Publishes telemetry to BOTH brokers
- [ ] Local dashboard shows data (unchanged)
- [ ] Mobile app will show data (when built)
- [ ] Commands work from local dashboard
- [ ] Commands will work from mobile app (when built)
- [ ] If local fails, cloud continues
- [ ] If cloud fails, local continues

---

## Next Steps

1. ✅ Update ESP32 code (this document)
2. ⏭️ Keep local Flutter dashboard unchanged (already works)
3. ⏭️ Create new Flutter mobile app project
4. ⏭️ Connect mobile app to HiveMQ Cloud only
5. ⏭️ Build mobile app for Android/iOS
6. ⏭️ Deploy to staff phones/tablets

---

**Questions?** Check HIVEMQ_DETAILED_GUIDE.md for more details on HiveMQ setup, security, and troubleshooting.

