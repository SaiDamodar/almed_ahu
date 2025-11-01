#include <WiFi.h>
#include <WiFiClientSecure.h>  // ADD: For HiveMQ Cloud TLS connection
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <esp_task_wdt.h>

// ========================= DEFAULT MOTOR TIMINGS (Adjustable via Admin) =========================
// These are DEFAULT values - can be changed via MQTT provisioning from Admin UI
unsigned long M1_START_RUN = 10UL * 1000UL;   // Motor-1 boot run time (default 10s)
unsigned long M1_POST_RUN  = 10UL * 1000UL;   // Motor-1 shutdown run time (default 10s)
unsigned long M2_INTERVAL  = 30UL * 1000UL;   // Motor-2 interval (default 30s)
unsigned long M2_RUN_TIME  = 10UL * 1000UL;   // Motor-2 run time (default 10s)
unsigned long M2_DELAY_AFTER_M1_STOP = 5UL * 1000UL; // Delay after M1 stops (default 5s)
// ============================================================================

// ========================= WATCHDOG CONFIGURATION =========================
const unsigned long WDT_TIMEOUT = 7;      // Watchdog timeout in seconds (7s - FAST RECOVERY)
const unsigned long LOOP_TIMEOUT_MS = 5000; // Max loop cycle time (5s)
const unsigned long WIFI_FAIL_RESET_MS = 15000; // Auto-reset if WiFi fails for 15s
// ============================================================================

// ============ DEFAULT / FIRST-BOOT PRIMARY WIFI (Pi hotspot or your lab) ============
#define DEFAULT_W1_SSID "PiSpot"
#define DEFAULT_W1_PASS "12345678"
// Secondary Wi-Fi (hospital) will be provisioned over MQTT; empty by default
// ============================================================================

// ---------- SHT45 ----------
Adafruit_SHT4x sht4;
float filtTempC = NAN, filtHum = NAN;     // filtered (stable) readings
unsigned long lastSensorAt = 0;
const unsigned long SENSOR_PERIOD = 2000; // 2 s

// Glitch filter thresholds
const float TEMP_JUMP_MAX = 12.0; // ignore temp jumps > 12 °C
const float HUM_JUMP_MAX  = 18.0; // ignore RH jumps   > 18 %

// Sensor failure detection thresholds (accept any upward jump from these values)
const float TEMP_FAIL_THRESHOLD = 5.0;  // < 5°C indicates sensor failure
const float HUM_FAIL_THRESHOLD = 10.0;  // < 10% indicates sensor failure

// ---------- L298N / Motors ----------
#define IN1 25
#define IN2 26
#define ENA 33
#define IN3 27
#define IN4 14
#define ENB 32

bool runState = false, m1Active = false, m2Active = false, shuttingDown = false;
unsigned long m1StopAt = 0, m2StopAt = 0, m2NextAt = 0;
bool m2ScheduledAfterM1 = false;         // during RUN sequence
unsigned long m2StartAt = 0;

// ========== MQTT COMMAND DEBOUNCING ==========
// Prevent duplicate commands from triggering multiple times
unsigned long lastCmdTime = 0;
String lastCmdHash = "";
const unsigned long CMD_DEBOUNCE_MS = 500;  // Ignore duplicate commands within 500ms

// Shutdown sequencing
bool shutdownM2Pending = false;
bool shutdownStarted = false;             // NEW: prevents re-starting M1 during shutdown

// ---------- Relays (open-drain drive) ----------
// CP = compressor (temperature control)
#define PIN_CP 23
bool   cpOn = false;
float  tempSet = 22.0;               // °C
const float TEMP_DEADBAND = 1.0;     // °C
const unsigned long CP_MIN_OFF_MS = 5000;  // test timings
const unsigned long CP_MIN_ON_MS  = 3000;
unsigned long cpLastOnAt  = 0, cpLastOffAt = 0;

// HEATER = dehumidifier effect (humidity control)
#define PIN_HEAT 19
bool   heatOn = false;
float  humSet = 55.0;                // %RH
const float HUM_DEADBAND = 3.0;      // %RH
const unsigned long HEAT_MIN_OFF_MS = 5000; // test timings
const unsigned long HEAT_MIN_ON_MS  = 3000;
unsigned long heatLastOnAt  = 0, heatLastOffAt = 0;

// ========== FAN CONTROL (3 LM2596 + 3 Relay Method) ==========
// Each relay connects one LM2596 output to the fan
#define PIN_FAN_RELAY_LOW  18  // Relay #1: Connects LM2596 #1 (5V) to fan
#define PIN_FAN_RELAY_MID  13  // Relay #2: Connects LM2596 #2 (9V) to fan (changed from GPIO 5 to 13 for stability)
#define PIN_FAN_RELAY_HIGH 4   // Relay #3: Connects LM2596 #3 (12V) to fan

// NOTE: Fan relays are ACTIVE LOW (LOW = relay ON, HIGH = relay OFF)
// This matches CP/HEAT relay behavior: LOW = ON, HIGH = OFF

// Fan speed modes
// NOTE: FAN_OFF is internal only (used when system is not running)
// Users can only select LOW/MID/HIGH when system is running
enum FanSpeed {
  FAN_OFF = 0,    // Internal: Fan OFF (system not running)
  FAN_LOW = 1,    // 5V (low speed) - LM2596 #1
  FAN_MID = 2,    // 9V (medium speed) - LM2596 #2
  FAN_HIGH = 3    // 12V (high speed) - LM2596 #3
};

FanSpeed fanSpeed = FAN_OFF;  // Fan starts OFF - only turns on when system starts
bool fanOn = false;  // Fan is OFF until system starts
bool fanManualMode = false;  // When true, automatic control is disabled
unsigned long fanManualModeUntil = 0;  // Timestamp when manual mode expires (0 = never expires)

// Fan control parameters
const float TEMP_FAN_LOW = 24.0;   // °C - Switch to LOW at this temp
const float TEMP_FAN_MID = 26.0;   // °C - Switch to MID at this temp
const float TEMP_FAN_HIGH = 28.0;  // °C - Switch to HIGH at this temp
const float HUM_FAN_THRESHOLD = 65.0;  // %RH - Turn on fan if humidity high
const unsigned long FAN_MANUAL_MODE_TIMEOUT = 300000;  // Manual mode expires after 5 minutes (0 = never expire)

// ---------- Ring buffers for logs (last 10) ----------
const int LOG_MAX = 10;
String tempBuf[LOG_MAX]; int tempHead = -1; int tempCount = 0;
String motorBuf[LOG_MAX]; int motorHead = -1; int motorCount = 0;

void pushTempHTML(const String& line)  { tempHead  = (tempHead  + 1) % LOG_MAX; tempBuf[tempHead]  = line; if (tempCount  < LOG_MAX) tempCount++; }
void pushMotorHTML(const String& line) { motorHead = (motorHead + 1) % LOG_MAX; motorBuf[motorHead] = line; if (motorCount < LOG_MAX) motorCount++; }
String renderNewestFirst(String buf[], int head, int cnt){
  if (cnt == 0) return "—";
  String out; for (int i=0;i<cnt;i++){ int idx=head-i; if(idx<0) idx+=LOG_MAX; out += buf[idx] + "<br>"; } return out;
}

// ========== MQTT LOCAL (Priority 1: Raspberry Pi) ==========
WiFiClient espNetLocal;
PubSubClient mqttLocal(espNetLocal);

const char* MQTT_USER_LOCAL = "almed";
const char* MQTT_PASS_LOCAL = "Almed1234$";
const uint16_t MQTT_PORT_LOCAL = 1883;

// ========== MQTT CLOUD (Priority 2: HiveMQ Cloud) ==========
WiFiClientSecure espNetCloud;
PubSubClient mqttCloud(espNetCloud);

const char* MQTT_USER_CLOUD = "almed";
const char* MQTT_PASS_CLOUD = "AlMed123456";  // CHANGE THIS to your HiveMQ password
const uint16_t MQTT_PORT_CLOUD = 8883;
String mqttHostCloud = "ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud";  // CHANGE THIS to your HiveMQ cluster URL

const char* ORG  = "almed";
const char* SITE = "hospitalA";
const char* ROOM = "icu1";
const char* AHU  = "ahu-01";

String baseTopic()        { return String(ORG)+"/ahu/"+SITE+"/"+ROOM+"/"+AHU; }
String tTelemetry()       { return baseTopic()+"/telemetry"; }
String tLog()             { return baseTopic()+"/log"; }
String tState()           { return baseTopic()+"/state"; }
String tCmd()             { return baseTopic()+"/cmd"; }
String tStatus()          { return baseTopic()+"/status"; }
// Provisioning topics (from kiosk Admin on Pi hotspot)
String tProvWifi()        { return baseTopic()+"/provision/wifi"; }
String tProvBroker()      { return baseTopic()+"/provision/broker"; }
String tProvMotorTimings(){ return baseTopic()+"/provision/motor_timings"; }
String tProvAck()         { return baseTopic()+"/provision/ack"; }

unsigned long lastMqttAttempt = 0;

// ---------- Preferences ----------
Preferences prefs;
// Wi-Fi creds + broker host (in prefs)
String w1_ssid, w1_pass, w2_ssid, w2_pass;
String mqttHostLocal = "10.42.0.1";  // default is Pi hotspot IP (can be changed to "mqtt-broker.local")

// ---------- Watchdog & State Recovery ----------
unsigned long lastLoopTime = 0;
unsigned long wifiFailStartTime = 0;
bool wifiWasFailing = false;
int consecutiveWifiFailures = 0;
bool wifiAssociationRefused = false; // Flag for immediate reset on association error
bool pendingRecoveryStart = false;    // Flag: waiting for WiFi before starting motors after recovery

// ---------- State Persistence (for watchdog recovery) ----------
void saveSystemState(){
  prefs.putBool("runState", runState);
  prefs.putBool("cpOn", cpOn);
  prefs.putBool("heatOn", heatOn);
  prefs.putBool("shuttingDown", shuttingDown);
  prefs.putULong("saveTime", millis());
}

void restoreSystemState(){
  // Only restore if saved within last 5 minutes (watchdog reset scenario)
  unsigned long saveTime = prefs.getULong("saveTime", 0);
  if (saveTime == 0 || millis() < 300000) { // First 5 min after boot
    bool wasRunning = prefs.getBool("runState", false);
    bool wasCpOn = prefs.getBool("cpOn", false);
    bool wasHeatOn = prefs.getBool("heatOn", false);
    bool wasShuttingDown = prefs.getBool("shuttingDown", false);
    
    if (wasRunning && !wasShuttingDown) {
      // CRITICAL: Set flag to delay motor start until WiFi is connected
      // This prevents motors from running during WiFi connection (which can trigger loop timeout)
      pendingRecoveryStart = true;
      runState = false;  // Keep OFF until WiFi is connected
      
      // Restore relay states immediately (safe, no motors)
      cpOn = wasCpOn;
      heatOn = wasHeatOn;
      cpWrite(cpOn);
      heatWrite(heatOn);
      
      Serial.println("⚠️ WATCHDOG RECOVERY: State restored, waiting for WiFi before starting motors");
      Serial.print("  CP: "); Serial.print(cpOn ? "ON" : "OFF");
      Serial.print(" | Heater: "); Serial.print(heatOn ? "ON" : "OFF");
      Serial.println("\n  Motors: DELAYED until WiFi connected (safety)");
    }
  }
}

void clearSystemState(){
  prefs.putBool("runState", false);
  prefs.putBool("cpOn", false);
  prefs.putBool("heatOn", false);
  prefs.putBool("shuttingDown", false);
  prefs.putULong("saveTime", 0);
}

// ---------- Logging ----------
void mqttPublishLog(const char* level, const String& msg){
  // Publish logs to both brokers (only cloud when NOT on PiSpot)
  StaticJsonDocument<240> doc;
  doc["ts"]  = millis();
  doc["lvl"] = level;
  doc["msg"] = msg;
  char buf[280];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  // Publish to LOCAL broker (always when connected - RPI bridge forwards to cloud)
  if(mqttLocal.connected()) {
    mqttLocal.publish(tLog().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
  // Publish to CLOUD broker only when NOT on PiSpot (Hospital WiFi fallback)
  if (!isOnPiSpot() && mqttCloud.connected()) {
    mqttCloud.publish(tLog().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
}
void motorLogMsg(const String& s){ Serial.println(s); pushMotorHTML(s); mqttPublishLog("INFO", s); }

// ---------- Motor helpers ----------
void m1_start(){ digitalWrite(IN1,HIGH); digitalWrite(IN2,LOW); digitalWrite(ENA,HIGH); m1Active=true;  motorLogMsg("Motor-1 ON (Drain)"); }
void m1_stop (){ digitalWrite(ENA,LOW);  digitalWrite(IN1,LOW);  digitalWrite(IN2,LOW);  m1Active=false; motorLogMsg("Motor-1 OFF"); }
void m2_start(){ digitalWrite(IN3,HIGH); digitalWrite(IN4,LOW); digitalWrite(ENB,HIGH); m2Active=true;  motorLogMsg("Motor-2 ON (Filter Clean)"); }
void m2_stop (){ digitalWrite(ENB,LOW);  digitalWrite(IN3,LOW);  digitalWrite(IN4,LOW);  m2Active=false; motorLogMsg("Motor-2 OFF"); }

// Emergency stop ALL motors (called on WiFi/system failure)
void emergencyStopMotors(){
  if (m1Active) { m1_stop(); Serial.println("⚠️ EMERGENCY: Motor-1 stopped (WiFi/system failure)"); }
  if (m2Active) { m2_stop(); Serial.println("⚠️ EMERGENCY: Motor-2 stopped (WiFi/system failure)"); }
  if (cpOn) { cpWrite(false); cpOn=false; Serial.println("⚠️ EMERGENCY: CP stopped"); }
  if (heatOn) { heatWrite(false); heatOn=false; Serial.println("⚠️ EMERGENCY: Heater stopped"); }
  // Emergency: Turn OFF all fan relays
  emergencyStopFan();
}

// Emergency: turn fan OFF (system failure)
void emergencyStopFan() {
  digitalWrite(PIN_FAN_RELAY_LOW, HIGH);   // Relay OFF
  digitalWrite(PIN_FAN_RELAY_MID, HIGH);   // Relay OFF
  digitalWrite(PIN_FAN_RELAY_HIGH, HIGH); // Relay OFF
  fanSpeed = FAN_OFF;
  fanOn = false;
  Serial.println("⚠️ EMERGENCY: Fan turned OFF");
}

// ---------- Relay writers (open-drain: LOW=ON, HIGH=OFF) ----------
inline void cpWrite(bool on){ digitalWrite(PIN_CP, on ? LOW : HIGH); }
inline void heatWrite(bool on){ digitalWrite(PIN_HEAT, on ? LOW : HIGH); }

// ---------- Controllers (gated by runState) ----------
void controlCP(float t){
  if (!runState){               // machine not running -> force OFF
    if (cpOn){ cpWrite(false); cpOn=false; cpLastOffAt=millis(); motorLogMsg("CP forced OFF (system STOPPED)"); }
    return;
  }
  if (isnan(t)) return;

  unsigned long now = millis();
  float onThresh  = tempSet + TEMP_DEADBAND;
  float offThresh = tempSet;

  if (!cpOn){
    if (t >= onThresh && (now - cpLastOffAt) >= CP_MIN_OFF_MS){
      cpWrite(true); cpOn = true; cpLastOnAt = now;
      motorLogMsg("CP ON (cooling)");
    }
  } else {
    if (t <= offThresh && (now - cpLastOnAt) >= CP_MIN_ON_MS){
      cpWrite(false); cpOn = false; cpLastOffAt = now;
      motorLogMsg("CP OFF (reached temp setpoint)");
    }
  }
}

void controlHeater(float h){
  if (!runState){               // machine not running -> force OFF
    if (heatOn){ heatWrite(false); heatOn=false; heatLastOffAt=millis(); motorLogMsg("Heater forced OFF (system STOPPED)"); }
    return;
  }
  if (isnan(h)) return;

  unsigned long now = millis();
  float onThresh  = humSet + HUM_DEADBAND;  // ON when RH above set+db (to dehumidify)
  float offThresh = humSet;                 // OFF when RH back to set

  if (!heatOn){
    if (h >= onThresh && (now - heatLastOffAt) >= HEAT_MIN_OFF_MS){
      heatWrite(true); heatOn = true; heatLastOnAt = now;
      motorLogMsg("Heater ON (dehumidify)");
    }
  } else {
    if (h <= offThresh && (now - heatLastOnAt) >= HEAT_MIN_ON_MS){
      heatWrite(false); heatOn = false; heatLastOffAt = now;
      motorLogMsg("Heater OFF (RH at setpoint)");
    }
  }
}

// ========== FAN CONTROL FUNCTIONS (3 LM2596 + 3 Relay) ==========
// Set fan speed - only ONE relay ON at a time
// Each relay connects one LM2596 output (5V, 9V, or 12V) to the fan
// NOTE: Relays are ACTIVE LOW (LOW = relay ON, HIGH = relay OFF) - matches CP/HEAT behavior
void setFanSpeed(FanSpeed speed) {
  if (speed == fanSpeed) return;  // No change needed
  
  // CRITICAL: Turn OFF all relays first (HIGH = relay OFF for ACTIVE LOW relays)
  digitalWrite(PIN_FAN_RELAY_LOW, HIGH);   // Relay OFF
  digitalWrite(PIN_FAN_RELAY_MID, HIGH);   // Relay OFF
  digitalWrite(PIN_FAN_RELAY_HIGH, HIGH); // Relay OFF
  delay(100);  // Allow relays to settle before switching (increased delay for safety)
  
  fanSpeed = speed;
  
  switch (speed) {
    case FAN_OFF:
      // All relays OFF - HIGH = relay OFF for ACTIVE LOW
      digitalWrite(PIN_FAN_RELAY_LOW, HIGH);   // Relay OFF
      digitalWrite(PIN_FAN_RELAY_MID, HIGH);   // Relay OFF
      digitalWrite(PIN_FAN_RELAY_HIGH, HIGH); // Relay OFF
      fanOn = false;
      motorLogMsg("Fan: OFF (system not running)");
      Serial.print("DEBUG: GPIO18="); Serial.print(digitalRead(PIN_FAN_RELAY_LOW));
      Serial.print(" GPIO13="); Serial.print(digitalRead(PIN_FAN_RELAY_MID));
      Serial.print(" GPIO4="); Serial.println(digitalRead(PIN_FAN_RELAY_HIGH));
      break;
      
    case FAN_LOW:
      // Connect LM2596 #1 (5V) to fan - LOW = relay ON for ACTIVE LOW
      digitalWrite(PIN_FAN_RELAY_LOW, LOW);    // Relay #1 ON (ACTIVE LOW)
      digitalWrite(PIN_FAN_RELAY_MID, HIGH);   // Relay #2 OFF (safety)
      digitalWrite(PIN_FAN_RELAY_HIGH, HIGH); // Relay #3 OFF (safety)
      delay(50);  // Allow relay to settle
      fanOn = true;
      motorLogMsg("Fan: LOW speed (5V) - GPIO18=LOW");
      Serial.print("DEBUG: GPIO18="); Serial.print(digitalRead(PIN_FAN_RELAY_LOW));
      Serial.print(" GPIO13="); Serial.print(digitalRead(PIN_FAN_RELAY_MID));
      Serial.print(" GPIO4="); Serial.println(digitalRead(PIN_FAN_RELAY_HIGH));
      break;
      
    case FAN_MID:
      // Connect LM2596 #2 (9V) to fan - LOW = relay ON for ACTIVE LOW
      digitalWrite(PIN_FAN_RELAY_LOW, HIGH);   // Relay #1 OFF (safety)
      digitalWrite(PIN_FAN_RELAY_MID, LOW);    // Relay #2 ON (ACTIVE LOW)
      digitalWrite(PIN_FAN_RELAY_HIGH, HIGH); // Relay #3 OFF (safety)
      delay(50);  // Allow relay to settle
      fanOn = true;
      motorLogMsg("Fan: MID speed (9V) - GPIO13=LOW");
      Serial.print("DEBUG: GPIO18="); Serial.print(digitalRead(PIN_FAN_RELAY_LOW));
      Serial.print(" GPIO13="); Serial.print(digitalRead(PIN_FAN_RELAY_MID));
      Serial.print(" GPIO4="); Serial.println(digitalRead(PIN_FAN_RELAY_HIGH));
      break;
      
    case FAN_HIGH:
      // Connect LM2596 #3 (12V) to fan - LOW = relay ON for ACTIVE LOW
      digitalWrite(PIN_FAN_RELAY_LOW, HIGH);   // Relay #1 OFF (safety)
      digitalWrite(PIN_FAN_RELAY_MID, HIGH);   // Relay #2 OFF (safety)
      digitalWrite(PIN_FAN_RELAY_HIGH, LOW);   // Relay #3 ON (ACTIVE LOW)
      delay(50);  // Allow relay to settle
      fanOn = true;
      motorLogMsg("Fan: HIGH speed (12V) - GPIO4=LOW");
      Serial.print("DEBUG: GPIO18="); Serial.print(digitalRead(PIN_FAN_RELAY_LOW));
      Serial.print(" GPIO13="); Serial.print(digitalRead(PIN_FAN_RELAY_MID));
      Serial.print(" GPIO4="); Serial.println(digitalRead(PIN_FAN_RELAY_HIGH));
      break;
  }
  
  publishState();  // Update state
}

// Automatic fan control based on temperature/humidity
// Throttled to prevent rapid switching (only checks every 2 seconds)
// DISABLED when in manual mode
static unsigned long lastFanControlCheck = 0;
const unsigned long FAN_CONTROL_INTERVAL = 2000;  // Check every 2 seconds

void controlFan(float temp, float hum) {
  unsigned long now = millis();
  
  // Check if manual mode has expired
  if (fanManualMode && fanManualModeUntil > 0 && now >= fanManualModeUntil) {
    fanManualMode = false;
    fanManualModeUntil = 0;
    motorLogMsg("Fan: Manual mode expired, resuming automatic control");
  }
  
  // Skip automatic control if in manual mode
  if (fanManualMode) {
    return;  // Don't override manual settings
  }
  
  // Throttle automatic control to prevent rapid switching
  if (now - lastFanControlCheck < FAN_CONTROL_INTERVAL) return;
  lastFanControlCheck = now;
  
  if (!runState) {
    // System not running -> turn fan OFF
    if (!fanManualMode && fanSpeed != FAN_OFF) {
      setFanSpeed(FAN_OFF);
    }
    return;
  }
  
  if (isnan(temp)) return;  // Need valid temperature reading
  
  // Fan always runs at minimum LOW speed (no OFF mode)
  FanSpeed targetSpeed = FAN_LOW;  // Default minimum speed
  
  // Temperature-based speed control
  if (temp >= TEMP_FAN_HIGH) {
    targetSpeed = FAN_HIGH;
  } else if (temp >= TEMP_FAN_MID) {
    targetSpeed = FAN_MID;
  } else if (temp >= TEMP_FAN_LOW) {
    targetSpeed = FAN_LOW;
  } else if (hum >= HUM_FAN_THRESHOLD) {
    // High humidity -> run at low speed
    targetSpeed = FAN_LOW;
  }
  
  // Only change if speed actually needs to change
  if (targetSpeed != fanSpeed) {
    setFanSpeed(targetSpeed);
  }
}

// ---------- System control ----------
void startSystem(){
  if (shuttingDown) return;
  if (!runState){
    runState = true;
    // Boot sequence: Motor-1 first, then Motor-2 after delay, then periodic every M2_INTERVAL
    if (!m1Active){ 
      m1_start(); 
      m1StopAt = millis() + M1_START_RUN; 
      m2ScheduledAfterM1 = false; // will be set when M1 stops
    }
    // Turn fan ON to LOW speed when system starts
    if (fanSpeed == FAN_OFF) {
      setFanSpeed(FAN_LOW);
      motorLogMsg("Fan: Turned ON (LOW speed) - system started");
    }
    motorLogMsg("[RUN] STARTED");
  }
}

void stopSystem(){
  if (!runState) return;
  runState = false;
  shuttingDown = true;
  shutdownStarted = false;   // NEW: ensure we start M1 post-drain only once
  shutdownM2Pending = false;
  // Turn fan OFF when system stops
  if (fanSpeed != FAN_OFF) {
    setFanSpeed(FAN_OFF);
    motorLogMsg("Fan: Turned OFF - system stopped");
  }
  clearSystemState(); // Clear saved state on intentional stop
  motorLogMsg("[RUN] STOP requested → Shutdown Drain");
}

void toggleSystem(){ if (runState) stopSystem(); else startSystem(); }

// ---------- Telemetry / State ----------
void publishTelemetry(){
  StaticJsonDocument<512> doc;
  if(isnan(filtTempC)) doc["temp"] = nullptr; else doc["temp"] = filtTempC;
  if(isnan(filtHum))   doc["hum"]  = nullptr; else doc["hum"]  = filtHum;
  doc["m1"]  = m1Active;
  doc["m2"]  = m2Active;
  doc["run"] = runState;
  doc["cp"]  = cpOn;
  doc["heater"] = heatOn;
  doc["fan"] = fanOn;
  doc["fanSpeed"] = (int)fanSpeed;  // 0=OFF, 1=LOW, 2=MID, 3=HIGH
  doc["tempSet"] = tempSet;
  doc["humSet"]  = humSet;
  doc["ts"]  = millis();
  char buf[576];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  // Publish to LOCAL broker (always when connected - RPI bridge forwards to cloud)
  if(mqttLocal.connected()) {
    mqttLocal.publish(tTelemetry().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
  // Publish to CLOUD broker only when NOT on PiSpot (Hospital WiFi fallback)
  if (!isOnPiSpot() && mqttCloud.connected()) {
    mqttCloud.publish(tTelemetry().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  }
}

void publishState(){
  StaticJsonDocument<640> doc;
  doc["run"]=runState; doc["m1"]=m1Active; doc["m2"]=m2Active;
  doc["cp"]=cpOn; doc["heater"]=heatOn;
  doc["fan"]=fanOn; doc["fanSpeed"]=(int)fanSpeed;
  doc["tempSet"]=tempSet; doc["humSet"]=humSet;
  
  // Publish current motor timings (in seconds)
  doc["m1_start"] = M1_START_RUN / 1000UL;
  doc["m1_post"] = M1_POST_RUN / 1000UL;
  doc["m2_interval"] = M2_INTERVAL / 1000UL;
  doc["m2_run"] = M2_RUN_TIME / 1000UL;
  doc["m2_delay"] = M2_DELAY_AFTER_M1_STOP / 1000UL;
  doc["ip"]=WiFi.localIP().toString();
  char buf[640];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  // Publish to LOCAL broker (retained - RPI bridge forwards to cloud)
  if(mqttLocal.connected()) {
    mqttLocal.publish(tState().c_str(), reinterpret_cast<const uint8_t*>(buf), n, true);
  }
  // Publish to CLOUD broker (retained) only when NOT on PiSpot (Hospital WiFi fallback)
  if (!isOnPiSpot() && mqttCloud.connected()) {
    mqttCloud.publish(tState().c_str(), reinterpret_cast<const uint8_t*>(buf), n, true);
  }
}

// ---------- Sensor read (with glitch filter) ----------
void readSensorIfDue(){
  unsigned long now = millis();
  if (now - lastSensorAt < SENSOR_PERIOD) return;
  lastSensorAt = now;

  sensors_event_t he, te;
  sht4.getEvent(&he, &te);

  bool got = (!isnan(te.temperature) && !isnan(he.relative_humidity));
  if (got){
    float newT = te.temperature;
    float newH = he.relative_humidity;

    bool acceptT = true, acceptH = true;

    // ========== SMART GLITCH FILTER FOR TEMPERATURE ==========
    if (!isnan(filtTempC)){
      // If new reading is abnormally low (sensor failure), reject it
      if (newT < TEMP_FAIL_THRESHOLD) {
        acceptT = false;
        motorLogMsg("Temp failure rejected: " + String(newT,1) + "C (sensor fail, kept " + String(filtTempC,1) + "C)");
      }
      // If current value is abnormally low (sensor was failed), accept ANY higher reading (recovery)
      else if (filtTempC < TEMP_FAIL_THRESHOLD && newT > filtTempC) {
        acceptT = true; // Always accept upward jump from failure
        motorLogMsg("Temp recovery: " + String(newT,1) + "C (recovered from failure " + String(filtTempC,1) + "C)");
      }
      // Normal jump detection (reject large jumps in either direction)
      else if (fabs(newT - filtTempC) > TEMP_JUMP_MAX) {
        acceptT = false;
      }
    }
    
    // ========== SMART GLITCH FILTER FOR HUMIDITY ==========
    if (!isnan(filtHum)){
      // If new reading is abnormally low (sensor failure), reject it
      if (newH < HUM_FAIL_THRESHOLD) {
        acceptH = false;
        motorLogMsg("Humidity failure rejected: " + String(newH,1) + "% (sensor fail, kept " + String(filtHum,1) + "%)");
      }
      // If current value is abnormally low (sensor was failed), accept ANY higher reading (recovery)
      else if (filtHum < HUM_FAIL_THRESHOLD && newH > filtHum) {
        acceptH = true; // Always accept upward jump from failure
        motorLogMsg("Humidity recovery: " + String(newH,1) + "% (recovered from failure " + String(filtHum,1) + "%)");
      }
      // Normal jump detection (reject large jumps in either direction)
      else if (fabs(newH - filtHum) > HUM_JUMP_MAX) {
        acceptH = false;
      }
    }

    if (acceptT) { filtTempC = newT; }
    else if (!isnan(filtTempC)) { motorLogMsg("Temp glitch ignored: " + String(newT,1) + "C (kept " + String(filtTempC,1) + "C)"); }

    if (acceptH) { filtHum = newH; }
    else if (!isnan(filtHum)) { motorLogMsg("Hum glitch ignored: " + String(newH,1) + "% (kept " + String(filtHum,1) + "%)"); }

    String line = "Temp: " + String((isnan(filtTempC)?newT:filtTempC),1) + " °C | Hum: " + String((isnan(filtHum)?newH:filtHum),1) + "%";
    Serial.println(line);
    pushTempHTML("Temp: " + String((isnan(filtTempC)?newT:filtTempC),1) + "&deg;C | Hum: " + String((isnan(filtHum)?newH:filtHum),1) + "%");
    mqttPublishLog("INFO", line);
    publishTelemetry();

  } else {
    Serial.println("SHT45 read failed");
    pushTempHTML("SHT45 read failed");
    mqttPublishLog("WARN", "SHT45 read failed");
  }
}

// =========================== WIFI (STA-only, dual) ===========================
enum WifiNet { NET_PRIMARY = 0, NET_SECONDARY = 1 };
WifiNet currentTry = NET_PRIMARY;
unsigned long lastWifiAttemptAt = 0;
const unsigned long WIFI_TRY_WINDOW_MS = 5000;   // try each SSID up to 5s (faster with 7s watchdog)
const unsigned long WIFI_BACKOFF_MS    = 5000;   // wait 5s between rotations (reduced hotspot hammering)

// WiFi event handler to catch association errors immediately
void WiFiEvent(WiFiEvent_t event) {
  switch(event) {
    case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
      // Check if it's an association refusal (happens when "Association refused" error occurs)
      if (WiFi.status() == WL_CONNECT_FAILED) {
        wifiAssociationRefused = true;
        Serial.println("⚠️ WiFi Association REFUSED - will reset immediately");
      }
      break;
    default:
      break;
  }
}

bool tryConnectWiFiOnce(const char* ssid, const char* pass, unsigned long windowMs){
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true, true);
  delay(50);
  WiFi.begin(ssid, pass);
  unsigned long t0 = millis();
  while (WiFi.status()!=WL_CONNECTED && millis()-t0<windowMs){
    delay(250);
    esp_task_wdt_reset(); // Feed watchdog during WiFi connection
  }
  
  // Check for WiFi association failure
  if (WiFi.status() == WL_CONNECT_FAILED || WiFi.status() == WL_DISCONNECTED) {
    consecutiveWifiFailures++;
    if (consecutiveWifiFailures >= 3) {
      Serial.println("⚠️ WiFi association failed multiple times - will reset");
      motorLogMsg("WARN: WiFi association error detected");
    }
  } else if (WiFi.status() == WL_CONNECTED) {
    consecutiveWifiFailures = 0; // Reset counter on success
  }
  
  return WiFi.status()==WL_CONNECTED;
}

void rotateWifiIfNeeded(){
  if (WiFi.status()==WL_CONNECTED) {
    // Reset failure tracking on successful connection
    if (wifiWasFailing) {
      wifiWasFailing = false;
      wifiFailStartTime = 0;
      consecutiveWifiFailures = 0;
      wifiAssociationRefused = false;
    }
    return;
  }
  
  // IMMEDIATE RESET on WiFi association error (your specific issue)
  if (wifiAssociationRefused) {
    Serial.println("⚠️ WiFi Association Error - IMMEDIATE RESET");
    motorLogMsg("ERROR: WiFi association refused - resetting ESP32");
    emergencyStopMotors(); // STOP ALL MOTORS before reset
    saveSystemState(); // Save state before reset
    delay(100);
    ESP.restart(); // Immediate restart
  }
  
  // Track WiFi failure duration
  unsigned long now = millis();
  if (!wifiWasFailing) {
    wifiWasFailing = true;
    wifiFailStartTime = now;
  }
  
  // Auto-reset if WiFi fails for too long (helps with association errors)
  if (wifiWasFailing && (now - wifiFailStartTime > WIFI_FAIL_RESET_MS)) {
    Serial.println("⚠️ WiFi failed for 15s - triggering watchdog reset");
    motorLogMsg("ERROR: WiFi failure timeout - resetting ESP32");
    emergencyStopMotors(); // STOP ALL MOTORS before reset
    saveSystemState(); // Save state before reset
    delay(100);
    esp_task_wdt_config_t quick_reset = {
      .timeout_ms = 1000,      // 1 second
      .idle_core_mask = 0,
      .trigger_panic = true
    };
    esp_task_wdt_init(&quick_reset);
    esp_task_wdt_add(NULL);
    while(1); // Trigger watchdog reset
  }
  
  if (now - lastWifiAttemptAt < WIFI_BACKOFF_MS) return;
  lastWifiAttemptAt = now;

  if (currentTry == NET_PRIMARY){
    if (w1_ssid.length()){
      motorLogMsg("Wi-Fi: trying PRIMARY SSID: " + w1_ssid);
      if (tryConnectWiFiOnce(w1_ssid.c_str(), w1_pass.c_str(), WIFI_TRY_WINDOW_MS)){
        motorLogMsg("Wi-Fi connected (PRIMARY), IP: " + WiFi.localIP().toString());
        return;
      }
    }
    currentTry = NET_SECONDARY;
  } else {
    if (w2_ssid.length()){
      motorLogMsg("Wi-Fi: trying SECONDARY SSID: " + w2_ssid);
      if (tryConnectWiFiOnce(w2_ssid.c_str(), w2_pass.c_str(), WIFI_TRY_WINDOW_MS)){
        motorLogMsg("Wi-Fi connected (SECONDARY), IP: " + WiFi.localIP().toString());
        return;
      }
    }
    currentTry = NET_PRIMARY;
  }
}

// ================================ MQTT ======================================
void publishStatusOnline(){
  // Publish to LOCAL broker (always when connected)
  if(mqttLocal.connected()) {
    mqttLocal.publish(tStatus().c_str(), "online", true);
  }
  // Publish to CLOUD broker only when NOT on PiSpot (RPI bridge forwards from local)
  if (!isOnPiSpot() && mqttCloud.connected()) {
    mqttCloud.publish(tStatus().c_str(), "online", true);
  }
}

void handleProvisioning(const char* topic, const byte* payload, unsigned int len){
  String t = String(topic);
  StaticJsonDocument<320> doc;
  if (deserializeJson(doc, payload, len)) return;

  if (t == tProvWifi()){
    if (doc.containsKey("primary")){
      w1_ssid = String((const char*)doc["primary"]["ssid"]) ;
      w1_pass = String((const char*)doc["primary"]["pass"]) ;
      prefs.putString("w1_ssid", w1_ssid);
      prefs.putString("w1_pass", w1_pass);
    }
    if (doc.containsKey("secondary")){
      w2_ssid = String((const char*)doc["secondary"]["ssid"]);
      w2_pass = String((const char*)doc["secondary"]["pass"]);
      prefs.putString("w2_ssid", w2_ssid);
      prefs.putString("w2_pass", w2_pass);
    }
    motorLogMsg("Provision: Wi-Fi credentials saved");
    StaticJsonDocument<96> ack; ack["ok"]=true; ack["msg"]="wifi saved";
    char buf[128]; size_t n = serializeJson(ack, buf, sizeof(buf));
    if(mqttLocal.connected()) mqttLocal.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
  else if (t == tProvBroker()){
    if (doc.containsKey("host")) { mqttHostLocal = String((const char*)doc["host"]); prefs.putString("mqtt_host", mqttHostLocal); }
    if (doc.containsKey("port")) { uint16_t port = (uint16_t)doc["port"].as<uint16_t>(); prefs.putUShort("mqtt_port", port); }
    motorLogMsg("Provision: Broker saved: " + mqttHostLocal);
    StaticJsonDocument<96> ack; ack["ok"]=true; ack["msg"]="broker saved";
    char buf[128]; size_t n = serializeJson(ack, buf, sizeof(buf));
    if(mqttLocal.connected()) mqttLocal.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
  else if (t == tProvMotorTimings()){
    // Motor timing provisioning (Admin only)
    if (doc.containsKey("m1_start")) { M1_START_RUN = doc["m1_start"].as<unsigned long>() * 1000UL; prefs.putULong("m1_start", M1_START_RUN); }
    if (doc.containsKey("m1_post")) { M1_POST_RUN = doc["m1_post"].as<unsigned long>() * 1000UL; prefs.putULong("m1_post", M1_POST_RUN); }
    if (doc.containsKey("m2_interval")) { M2_INTERVAL = doc["m2_interval"].as<unsigned long>() * 1000UL; prefs.putULong("m2_interval", M2_INTERVAL); }
    if (doc.containsKey("m2_run")) { M2_RUN_TIME = doc["m2_run"].as<unsigned long>() * 1000UL; prefs.putULong("m2_run", M2_RUN_TIME); }
    if (doc.containsKey("m2_delay")) { M2_DELAY_AFTER_M1_STOP = doc["m2_delay"].as<unsigned long>() * 1000UL; prefs.putULong("m2_delay", M2_DELAY_AFTER_M1_STOP); }
    
    motorLogMsg("Provision: Motor timings saved - M1:" + String(M1_START_RUN/1000) + "s M2:" + String(M2_RUN_TIME/1000) + "s Interval:" + String(M2_INTERVAL/1000) + "s");
    StaticJsonDocument<96> ack; ack["ok"]=true; ack["msg"]="motor timings saved";
    char buf[128]; size_t n = serializeJson(ack, buf, sizeof(buf));
    if(mqttLocal.connected()) mqttLocal.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
}

void onMqttMessage(char* topic, byte* payload, unsigned int len){
  String tStr(topic);
  if (tStr == tProvWifi() || tStr == tProvBroker() || tStr == tProvMotorTimings()){
    handleProvisioning(topic, payload, len);
    return;
  }

  if (tStr != tCmd()) return;

  // ========== DEBOUNCING: Ignore duplicate commands within 500ms ==========
  unsigned long now = millis();
  String cmdHash = String(topic) + String((char*)payload, len);  // Topic + payload hash
  
  // Check if this is the exact same command within debounce window
  if (cmdHash == lastCmdHash && (now - lastCmdTime) < CMD_DEBOUNCE_MS) {
    Serial.println("⚠️ Duplicate command ignored (debounce protection)");
    return;  // Ignore duplicate command
  }
  
  lastCmdTime = now;
  lastCmdHash = cmdHash;

  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, payload, len)) return;

  if (doc["start"])  startSystem();
  if (doc["stop"])   stopSystem();
  if (doc["toggle"]) toggleSystem();

  if (doc.containsKey("setpoint")){
    float sp = doc["setpoint"];
    if (sp >= 1 && sp <= 100){
      tempSet = sp; prefs.putFloat("tempSet", tempSet);
      motorLogMsg("Temp setpoint via MQTT: " + String(tempSet,1) + "C");
      publishState();
    }
  }
  if (doc.containsKey("humset")){
    float hs = doc["humset"];
    if (hs >= 10 && hs <= 90){
      humSet = hs; prefs.putFloat("humSet", humSet);
      motorLogMsg("Hum setpoint via MQTT: " + String(humSet,1) + "%");
      publishState();
    }
  }
  
  // ========== FAN CONTROL COMMANDS ==========
  // Toggle fan speed: LOW → MID → HIGH → LOW (cycles through speeds)
  // Only works when system is running (fan must be ON)
  if (doc.containsKey("fanToggle")){
    // Only toggle if system is running
    if (!runState) {
      motorLogMsg("Fan: Cannot toggle - system not running");
      return;
    }
    
    // Cycle through speeds: LOW → MID → HIGH → LOW
    FanSpeed nextSpeed = FAN_LOW;  // Default to LOW
    
    switch (fanSpeed) {
      case FAN_OFF:
        // If somehow OFF, start at LOW
        nextSpeed = FAN_LOW;
        break;
      case FAN_LOW:
        nextSpeed = FAN_MID;
        break;
      case FAN_MID:
        nextSpeed = FAN_HIGH;
        break;
      case FAN_HIGH:
        nextSpeed = FAN_LOW;
        break;
      default:
        nextSpeed = FAN_LOW;
        break;
    }
    
    // Enter manual mode when manual command is received
    fanManualMode = true;
    if (FAN_MANUAL_MODE_TIMEOUT > 0) {
      fanManualModeUntil = millis() + FAN_MANUAL_MODE_TIMEOUT;
    } else {
      fanManualModeUntil = 0;  // Never expire
    }
    setFanSpeed(nextSpeed);
    motorLogMsg("Fan toggled to: " + String((int)nextSpeed) + " (Manual mode enabled)");
  }
  
  // Legacy support: direct speed setting (0=OFF ignored when system running)
  if (doc.containsKey("fan")){
    int speed = doc["fan"].as<int>();
    if (speed >= 0 && speed <= 3){
      // Only allow speed changes when system is running
      if (!runState && speed != 0) {
        motorLogMsg("Fan: Cannot set speed - system not running");
        return;
      }
      
      FanSpeed targetSpeed = FAN_OFF;
      if (speed == 0) targetSpeed = FAN_OFF;
      else if (speed == 1) targetSpeed = FAN_LOW;
      else if (speed == 2) targetSpeed = FAN_MID;
      else if (speed == 3) targetSpeed = FAN_HIGH;
      
      // If trying to set fan ON when system not running, ignore
      if (!runState && targetSpeed != FAN_OFF) {
        return;
      }
      
      fanManualMode = true;
      if (FAN_MANUAL_MODE_TIMEOUT > 0) {
        fanManualModeUntil = millis() + FAN_MANUAL_MODE_TIMEOUT;
      } else {
        fanManualModeUntil = 0;
      }
      setFanSpeed(targetSpeed);
      if (targetSpeed == FAN_OFF) {
        motorLogMsg("Fan turned OFF via MQTT");
      } else {
        motorLogMsg("Fan speed set via MQTT: " + String((int)targetSpeed) + " (Manual mode enabled)");
      }
    }
  }
  
  // Allow re-enabling automatic fan control
  if (doc.containsKey("fanAuto")){
    bool enableAuto = doc["fanAuto"].as<bool>();
    if (enableAuto) {
      fanManualMode = false;
      fanManualModeUntil = 0;
      motorLogMsg("Fan: Automatic control enabled");
    } else {
      fanManualMode = true;
      fanManualModeUntil = 0;  // Never expire
      motorLogMsg("Fan: Manual mode enabled (automatic control disabled)");
    }
  }
}

// ========== LOCAL MQTT CONNECTION (Priority 1) ==========
void ensureMqttLocal(){
  if(mqttLocal.connected()) return;
  if (WiFi.status()!=WL_CONNECTED) return;

  unsigned long now = millis();
  static unsigned long lastLocalAttempt = 0;
  if(now - lastLocalAttempt < 2000) return;
  lastLocalAttempt = now;

  mqttLocal.setServer(mqttHostLocal.c_str(), MQTT_PORT_LOCAL);
  mqttLocal.setCallback(onMqttMessage);

  String clientId = String(AHU)+"_local_"+String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = mqttLocal.connect(clientId.c_str(),
                         MQTT_USER_LOCAL, MQTT_PASS_LOCAL,
                         tStatus().c_str(), 1, true, "offline");
  if(ok){
    mqttLocal.subscribe(tCmd().c_str(), 1);
    mqttLocal.subscribe(tProvWifi().c_str(), 1);
    mqttLocal.subscribe(tProvBroker().c_str(), 1);
    mqttLocal.subscribe(tProvMotorTimings().c_str(), 1);
    motorLogMsg("✓ LOCAL MQTT connected (" + mqttHostLocal + ":" + String(MQTT_PORT_LOCAL) + ")");
    publishStatusOnline();
    publishState();
  }else{
    Serial.print("✗ LOCAL MQTT connect failed, rc=");
    Serial.println(mqttLocal.state());
  }
}

// ========== NETWORK DETECTION ==========
// Detect if ESP32 is connected to PiSpot (10.42.0.x network)
bool isOnPiSpot() {
  if (WiFi.status() != WL_CONNECTED) return false;
  IPAddress localIP = WiFi.localIP();
  // PiSpot uses 10.42.0.x IP range
  return (localIP[0] == 10 && localIP[1] == 42 && localIP[2] == 0);
}

// ========== CLOUD MQTT CONNECTION (Priority 2) ==========
// Only connects when NOT on PiSpot (fallback: Hospital WiFi direct to cloud)
void ensureMqttCloud(){
  // If on PiSpot, disconnect from cloud (RPI bridge will handle forwarding)
  if (isOnPiSpot()) {
    if (mqttCloud.connected()) {
      mqttCloud.disconnect();
      Serial.println("⚠️ On PiSpot - Disconnected from cloud (RPI bridge handles forwarding)");
    }
    return;
  }
  
  // Only connect to cloud when NOT on PiSpot (Hospital WiFi fallback)
  if(mqttCloud.connected()) return;
  if (WiFi.status()!=WL_CONNECTED) return;

  // Only try cloud connection every 30 seconds (lower priority)
  unsigned long now = millis();
  static unsigned long lastCloudAttempt = 0;
  if(now - lastCloudAttempt < 30000) return;
  lastCloudAttempt = now;

  mqttCloud.setServer(mqttHostCloud.c_str(), MQTT_PORT_CLOUD);
  mqttCloud.setCallback(onMqttMessage);

  String clientId = String(AHU)+"_cloud_"+String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = mqttCloud.connect(clientId.c_str(),
                         MQTT_USER_CLOUD, MQTT_PASS_CLOUD,
                         tStatus().c_str(), 1, true, "offline");
  if(ok){
    mqttCloud.subscribe(tCmd().c_str(), 1);
    motorLogMsg("✓ CLOUD MQTT connected (Hospital WiFi → HiveMQ direct: " + mqttHostCloud + ":" + String(MQTT_PORT_CLOUD) + ")");
    publishStatusOnline();
    publishState();
  }else{
    Serial.print("✗ CLOUD MQTT connect failed, rc=");
    Serial.println(mqttCloud.state());
  }
}

// ---------- Serial command ----------
String serialBuf;
void handleSerial(){
  while (Serial.available()){
    char ch = Serial.read();
    if (ch == '\r' || ch == '\n'){
      serialBuf.trim();
      serialBuf.toLowerCase();
      if (serialBuf == "start")  startSystem();
      else if (serialBuf == "stop")   stopSystem();
      else if (serialBuf == "toggle") toggleSystem();
      else if (serialBuf.startsWith("set ")){      // temp
        float sp = serialBuf.substring(4).toFloat();
        if (sp>=1 && sp<=100){ tempSet=sp; prefs.putFloat("tempSet",tempSet); motorLogMsg("Temp set via Serial: "+String(tempSet,1)+"C"); publishState(); }
      }
      else if (serialBuf.startsWith("hum ")){      // humidity
        float hs = serialBuf.substring(4).toFloat();
        if (hs>=10 && hs<=90){ humSet=hs; prefs.putFloat("humSet",humSet); motorLogMsg("Hum set via Serial: "+String(humSet,1)+"%"); publishState(); }
      }
      else if (serialBuf.length()) motorLogMsg("Unknown cmd: " + serialBuf);
      mqttPublishLog("INFO", String("> ") + serialBuf);
      serialBuf = "";
    } else {
      serialBuf += ch;
      if (serialBuf.length() > 64) serialBuf = serialBuf.substring(0,64);
    }
  }
}

// ---------- Setup ----------
void setup(){
  Serial.begin(115200);
  delay(500); // Allow serial to stabilize
  
  // ========== WATCHDOG INITIALIZATION ==========
  Serial.println("\n========================================");
  Serial.println("   ALMED AHU Controller v2.0");
  Serial.println("   Watchdog Protection Enabled");
  Serial.println("========================================");
  
  // Configure watchdog timer (7 seconds timeout)
  esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT * 1000,  // Convert seconds to milliseconds
    .idle_core_mask = 0,               // Watch all cores
    .trigger_panic = true              // Enable panic so ESP32 resets
  };
  esp_task_wdt_init(&wdt_config);
  esp_task_wdt_add(NULL); // Add current thread to WDT watch
  Serial.print("✓ Watchdog enabled (");
  Serial.print(WDT_TIMEOUT);
  Serial.println("s timeout)");
  
  // Feed watchdog immediately
  esp_task_wdt_reset();

  pinMode(IN1,OUTPUT); pinMode(IN2,OUTPUT); pinMode(ENA,OUTPUT);
  pinMode(IN3,OUTPUT); pinMode(IN4,OUTPUT); pinMode(ENB,OUTPUT);
  digitalWrite(ENA,LOW); digitalWrite(ENB,LOW);
  digitalWrite(IN1,LOW); digitalWrite(IN2,LOW);
  digitalWrite(IN3,LOW); digitalWrite(IN4,LOW);

  // Relays: open-drain so ESP32 only sinks current (safe for 5V-pulled IN)
  pinMode(PIN_CP, OUTPUT_OPEN_DRAIN);
  pinMode(PIN_HEAT, OUTPUT_OPEN_DRAIN);
  digitalWrite(PIN_CP, HIGH);    // OFF at boot
  digitalWrite(PIN_HEAT, HIGH);  // OFF at boot
  cpLastOffAt = millis();
  heatLastOffAt = millis();
  
  // ========== FAN CONTROL PIN SETUP (3 LM2596 + 3 Relay) ==========
  // NOTE: Relays are ACTIVE LOW (LOW = relay ON, HIGH = relay OFF)
  pinMode(PIN_FAN_RELAY_LOW, OUTPUT);
  pinMode(PIN_FAN_RELAY_MID, OUTPUT);
  pinMode(PIN_FAN_RELAY_HIGH, OUTPUT);
  
  // Fan starts OFF - only turns on when system starts
  // Initialize to OFF: all relays HIGH (OFF)
  digitalWrite(PIN_FAN_RELAY_LOW, HIGH);   // Relay OFF
  digitalWrite(PIN_FAN_RELAY_MID, HIGH);   // Relay OFF
  digitalWrite(PIN_FAN_RELAY_HIGH, HIGH); // Relay OFF
  delay(100);  // Allow relays to settle
  fanSpeed = FAN_OFF;
  fanOn = false;
  
  Serial.println("✓ Fan control initialized (3 LM2596 + 3 relay, ACTIVE LOW)");
  Serial.println("  Fan Relay LOW:  GPIO 18 (LM2596 #1: 5V)");
  Serial.println("  Fan Relay MID:  GPIO 13 (LM2596 #2: 9V)");
  Serial.println("  Fan Relay HIGH: GPIO 4  (LM2596 #3: 12V)");
  Serial.println("  Relay Logic: LOW = ON, HIGH = OFF (ACTIVE LOW)");
  
  esp_task_wdt_reset(); // Feed watchdog

  Wire.begin(21,22);
  if (!sht4.begin()){
    Serial.println("⚠️ SHT45 not found!");
  } else {
    sht4.setPrecision(SHT4X_HIGH_PRECISION);
    sht4.setHeater(SHT4X_NO_HEATER);
    Serial.println("✓ SHT45 ready");
  }
  
  esp_task_wdt_reset(); // Feed watchdog

  prefs.begin("ahu", false);

  // Load saved setpoints
  float sp = prefs.getFloat("tempSet", tempSet);
  if (sp>=1 && sp<=100) tempSet = sp;
  float hs = prefs.getFloat("humSet", humSet);
  if (hs>=10 && hs<=90) humSet = hs;

  // Load Wi-Fi creds (primary defaults on first boot)
  w1_ssid = prefs.getString("w1_ssid", DEFAULT_W1_SSID);
  w1_pass = prefs.getString("w1_pass", DEFAULT_W1_PASS);
  w2_ssid = prefs.getString("w2_ssid", String(""));   // empty until provisioned
  w2_pass = prefs.getString("w2_pass", String(""));

  // Load broker host for LOCAL broker
  mqttHostLocal = prefs.getString("mqtt_host", String("10.42.0.1")); // you can later provision "mqtt-broker.local"
  
  // Load motor timings (if previously provisioned)
  M1_START_RUN = prefs.getULong("m1_start", M1_START_RUN);
  M1_POST_RUN = prefs.getULong("m1_post", M1_POST_RUN);
  M2_INTERVAL = prefs.getULong("m2_interval", M2_INTERVAL);
  M2_RUN_TIME = prefs.getULong("m2_run", M2_RUN_TIME);
  M2_DELAY_AFTER_M1_STOP = prefs.getULong("m2_delay", M2_DELAY_AFTER_M1_STOP);
  
  Serial.println("✓ Motor timings loaded:");
  Serial.print("  M1 Start: "); Serial.print(M1_START_RUN/1000); Serial.println("s");
  Serial.print("  M1 Post: "); Serial.print(M1_POST_RUN/1000); Serial.println("s");
  Serial.print("  M2 Interval: "); Serial.print(M2_INTERVAL/1000); Serial.println("s");
  Serial.print("  M2 Run: "); Serial.print(M2_RUN_TIME/1000); Serial.println("s");
  Serial.print("  M2 Delay: "); Serial.print(M2_DELAY_AFTER_M1_STOP/1000); Serial.println("s");
  
  esp_task_wdt_reset(); // Feed watchdog
  
  // Register WiFi event handler for immediate association error detection
  WiFi.onEvent(WiFiEvent);
  Serial.println("✓ WiFi event handler registered");
  
  // ========== MQTT BROKER CONFIGURATION ==========
  // Configure TLS for CLOUD broker (HiveMQ)
  espNetCloud.setInsecure();  // Skip certificate validation (for simplicity)
  Serial.println("✓ Local MQTT configured (Raspberry Pi:" + String(MQTT_PORT_LOCAL) + ")");
  Serial.println("✓ Cloud MQTT configured (HiveMQ:" + String(MQTT_PORT_CLOUD) + " TLS)");
  
  // ========== STATE RECOVERY (after watchdog reset) ==========
  Serial.println("\n--- Checking for previous state ---");
  restoreSystemState();
  
  Serial.println("\n✓ Boot complete. Ready for commands.");
  Serial.println("  Temp setpoint: " + String(tempSet, 1) + "°C");
  Serial.println("  Humidity setpoint: " + String(humSet, 1) + "%");
  if (runState) {
    Serial.println("  ⚠️ RECOVERED: System was running before reset");
  }
  Serial.println("========================================\n");

  // First Wi-Fi connect attempt starts immediately
  lastWifiAttemptAt = 0;
  lastLoopTime = millis();
}

// ---------- Loop ----------
void loop(){
  unsigned long now = millis();
  
  // ========== WATCHDOG MONITORING ==========
  // Feed watchdog every loop cycle
  esp_task_wdt_reset();
  
  // Check for loop hang (should never take more than LOOP_TIMEOUT_MS)
  if (now - lastLoopTime > LOOP_TIMEOUT_MS) {
    Serial.println("⚠️ CRITICAL: Loop timeout detected (>5s)!");
    motorLogMsg("ERROR: Loop hang detected - forcing reset");
    emergencyStopMotors(); // STOP ALL MOTORS before reset
    saveSystemState(); // Save state before reset
    delay(100);
    while(1); // Trigger watchdog reset
  }
  lastLoopTime = now;
  
  // Save system state periodically (every 10 seconds) when running
  static unsigned long lastStateSave = 0;
  if (runState && (now - lastStateSave > 10000)) {
    saveSystemState();
    lastStateSave = now;
  }

  // Wi-Fi maintenance (STA-only, rotate between primary & secondary)
  if (WiFi.status()!=WL_CONNECTED) rotateWifiIfNeeded();

  // ========== PENDING RECOVERY START (after WiFi connected) ==========
  // If we're waiting to start motors after watchdog recovery, do it now that WiFi is stable
  if (pendingRecoveryStart && WiFi.status() == WL_CONNECTED && mqttLocal.connected()) {
    pendingRecoveryStart = false;
    runState = true;
    // Start motor sequence (M1 will start in the running sequence below)
    motorLogMsg("⚠️ RECOVERY START: Motors starting now (WiFi connected, MQTT ready)");
    Serial.println("  System recovered and running safely");
  }

  // ========== MQTT MAINTENANCE (Priority 1: Local, Priority 2: Cloud) ==========
  if (WiFi.status()==WL_CONNECTED){ 
    // LOCAL MQTT (Priority 1)
    ensureMqttLocal();
    if(mqttLocal.connected()) mqttLocal.loop();
    
    // CLOUD MQTT (Priority 2) 
    ensureMqttCloud();
    if(mqttCloud.connected()) mqttCloud.loop();
  }

  // Sensors + telemetry
  handleSerial();
  readSensorIfDue();

  // Always evaluate controls using filtered readings (but gated by runState)
  controlCP(filtTempC);
  controlHeater(filtHum);
  controlFan(filtTempC, filtHum);

  // =================== SHUTDOWN SEQUENCE ===================
  if (shuttingDown){
    // Start M1 post-drain exactly once
    if (!shutdownStarted){
      if (m2Active) m2_stop();
      m1_start();
      m1StopAt = now + M1_POST_RUN;
      shutdownStarted = true; // <-- prevents re-starts
      motorLogMsg("Shutdown drain started (" + String(M1_POST_RUN/1000) + "s)");
      publishState();
    }

    // When M1 post-drain finishes, schedule M2 once
    if (shutdownStarted && m1Active && now >= m1StopAt){
      m1_stop();
      shutdownM2Pending = true;
      m2StartAt = now + M2_DELAY_AFTER_M1_STOP;
      motorLogMsg("Shutdown: scheduling Motor-2 in " + String(M2_DELAY_AFTER_M1_STOP/1000) + "s");
      publishState();
    }

    // Run M2 once after scheduled delay
    if (shutdownM2Pending && !m2Active && now >= m2StartAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      publishState();
    }

    // Finish shutdown after M2 completes
    if (shutdownM2Pending && m2Active && now >= m2StopAt){
      m2_stop();
      shuttingDown = false;
      shutdownStarted = false;
      shutdownM2Pending = false;
      clearSystemState(); // Clear state after complete shutdown
      motorLogMsg("System OFF");
      publishState();
    }
    delay(5);
    return;
  }

  // =================== RUNNING SEQUENCE ===================
  if (runState){
    // Stop M1 when its boot-run window is done
    if (m1Active && now >= m1StopAt) { 
      m1_stop(); 
      // Schedule first Motor-2 run after a delay
      m2ScheduledAfterM1 = true; 
      m2StartAt = now + M2_DELAY_AFTER_M1_STOP;
      motorLogMsg("Run: scheduling first Motor-2 in " + String(M2_DELAY_AFTER_M1_STOP/1000) + "s");
      publishState(); 
    }

    // Start the first M2 after M1 finished (one-time)
    if (m2ScheduledAfterM1 && !m2Active && !m1Active && now >= m2StartAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL;   // schedule next periodic run
      m2ScheduledAfterM1 = false;
      publishState();
    }

    // Start periodic M2 runs
    if (!m2Active && !m1Active && !m2ScheduledAfterM1 && now >= m2NextAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL;
      publishState();
    }
  }

  // Stop M2 when its run window is done (applies to both RUN and SHUTDOWN code paths)
  if (m2Active && now >= m2StopAt) { 
    m2_stop(); 
    publishState(); 
  }

  delay(5);
}
