#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ========================= USER TIMINGS (CHANGE HERE) =========================
// Motor-1 (drain) run time right after START pressed
const unsigned long M1_START_RUN = 10UL * 1000UL;   // 10 s
// Motor-1 (drain) run time during SHUTDOWN (post-drain)
const unsigned long M1_POST_RUN  = 10UL * 1000UL;   // 10 s
// Motor-2 (filter clean) run every M2_INTERVAL while running
const unsigned long M2_INTERVAL  = 30UL * 1000UL;   // 30 s
// How long Motor-2 runs each time
const unsigned long M2_RUN_TIME  = 10UL * 1000UL;   // 10 s
// Delay before Motor-2 starts AFTER Motor-1 stops (boot & shutdown)
const unsigned long M2_DELAY_AFTER_M1_STOP = 5UL * 1000UL; // 5 s
// ============================================================================

// ============ DEFAULT / FIRST-BOOT PRIMARY WIFI (Pi hotspot or your lab) ============
#define DEFAULT_W1_SSID "snorlax"
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

// ---------- MQTT ----------
WiFiClient espNet;
PubSubClient mqtt(espNet);

const char* MQTT_USER = "almed";
const char* MQTT_PASS = "Almed1234$";
uint16_t MQTT_PORT = 1883;

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
String tProvAck()         { return baseTopic()+"/provision/ack"; }

unsigned long lastMqttAttempt = 0;

// ---------- Preferences ----------
Preferences prefs;
// Wi-Fi creds + broker host (in prefs)
String w1_ssid, w1_pass, w2_ssid, w2_pass;
String mqttHost = "10.42.0.1";  // default is Pi hotspot IP (can be changed to "mqtt-broker.local")

// ---------- Logging ----------
void mqttPublishLog(const char* level, const String& msg){
  if(!mqtt.connected()) return;
  StaticJsonDocument<240> doc;
  doc["ts"]  = millis();
  doc["lvl"] = level;
  doc["msg"] = msg;
  char buf[280];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  mqtt.publish(tLog().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
}
void motorLogMsg(const String& s){ Serial.println(s); pushMotorHTML(s); mqttPublishLog("INFO", s); }

// ---------- Motor helpers ----------
void m1_start(){ digitalWrite(IN1,HIGH); digitalWrite(IN2,LOW); digitalWrite(ENA,HIGH); m1Active=true;  motorLogMsg("Motor-1 ON (Drain)"); }
void m1_stop (){ digitalWrite(ENA,LOW);  digitalWrite(IN1,LOW);  digitalWrite(IN2,LOW);  m1Active=false; motorLogMsg("Motor-1 OFF"); }
void m2_start(){ digitalWrite(IN3,HIGH); digitalWrite(IN4,LOW); digitalWrite(ENB,HIGH); m2Active=true;  motorLogMsg("Motor-2 ON (Filter Clean)"); }
void m2_stop (){ digitalWrite(ENB,LOW);  digitalWrite(IN3,LOW);  digitalWrite(IN4,LOW);  m2Active=false; motorLogMsg("Motor-2 OFF"); }

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
    motorLogMsg("[RUN] STARTED");
  }
}

void stopSystem(){
  if (!runState) return;
  runState = false;
  shuttingDown = true;
  shutdownStarted = false;   // NEW: ensure we start M1 post-drain only once
  shutdownM2Pending = false;
  motorLogMsg("[RUN] STOP requested → Shutdown Drain");
}

void toggleSystem(){ if (runState) stopSystem(); else startSystem(); }

// ---------- Telemetry / State ----------
void publishTelemetry(){
  if(!mqtt.connected()) return;
  StaticJsonDocument<384> doc;
  if(isnan(filtTempC)) doc["temp"] = nullptr; else doc["temp"] = filtTempC;
  if(isnan(filtHum))   doc["hum"]  = nullptr; else doc["hum"]  = filtHum;
  doc["m1"]  = m1Active;
  doc["m2"]  = m2Active;
  doc["run"] = runState;
  doc["cp"]  = cpOn;
  doc["heater"] = heatOn;
  doc["tempSet"] = tempSet;
  doc["humSet"]  = humSet;
  doc["ts"]  = millis();
  char buf[448];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  mqtt.publish(tTelemetry().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
}

void publishState(){
  if(!mqtt.connected()) return;
  StaticJsonDocument<320> doc;
  doc["run"]=runState; doc["m1"]=m1Active; doc["m2"]=m2Active;
  doc["cp"]=cpOn; doc["heater"]=heatOn;
  doc["tempSet"]=tempSet; doc["humSet"]=humSet;
  doc["ip"]=WiFi.localIP().toString();
  char buf[384];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  mqtt.publish(tState().c_str(), reinterpret_cast<const uint8_t*>(buf), n, true); // retained
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

    if (!isnan(filtTempC)){
      if (fabs(newT - filtTempC) > TEMP_JUMP_MAX) acceptT = false;
    }
    if (!isnan(filtHum)){
      if (fabs(newH - filtHum) > HUM_JUMP_MAX) acceptH = false;
    }

    if (acceptT) { filtTempC = newT; }
    else { motorLogMsg("Temp glitch ignored: " + String(newT,1) + "C (kept " + String(filtTempC,1) + "C)"); }

    if (acceptH) { filtHum = newH; }
    else { motorLogMsg("Hum glitch ignored: " + String(newH,1) + "% (kept " + String(filtHum,1) + "%)"); }

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
const unsigned long WIFI_TRY_WINDOW_MS = 15000;  // try each SSID up to 15s
const unsigned long WIFI_BACKOFF_MS    = 5000;   // wait 5s between rotations

bool tryConnectWiFiOnce(const char* ssid, const char* pass, unsigned long windowMs){
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true, true);
  delay(50);
  WiFi.begin(ssid, pass);
  unsigned long t0 = millis();
  while (WiFi.status()!=WL_CONNECTED && millis()-t0<windowMs){
    delay(250);
  }
  return WiFi.status()==WL_CONNECTED;
}

void rotateWifiIfNeeded(){
  if (WiFi.status()==WL_CONNECTED) return;
  unsigned long now = millis();
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
  if(!mqtt.connected()) return;
  mqtt.publish(tStatus().c_str(), "online", true); // retained
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
    mqtt.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
  else if (t == tProvBroker()){
    if (doc.containsKey("host")) { mqttHost = String((const char*)doc["host"]); prefs.putString("mqtt_host", mqttHost); }
    if (doc.containsKey("port")) { MQTT_PORT = (uint16_t)doc["port"].as<uint16_t>(); prefs.putUShort("mqtt_port", MQTT_PORT); }
    motorLogMsg("Provision: Broker saved: " + mqttHost + ":" + String(MQTT_PORT));
    StaticJsonDocument<96> ack; ack["ok"]=true; ack["msg"]="broker saved";
    char buf[128]; size_t n = serializeJson(ack, buf, sizeof(buf));
    mqtt.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
}

void onMqttMessage(char* topic, byte* payload, unsigned int len){
  String tStr(topic);
  if (tStr == tProvWifi() || tStr == tProvBroker()){
    handleProvisioning(topic, payload, len);
    return;
  }

  if (tStr != tCmd()) return;

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
}

void ensureMqtt(){
  if(mqtt.connected()) return;
  if (WiFi.status()!=WL_CONNECTED) return;

  unsigned long now = millis();
  if(now - lastMqttAttempt < 2000) return;
  lastMqttAttempt = now;

  mqtt.setServer(mqttHost.c_str(), MQTT_PORT);
  mqtt.setCallback(onMqttMessage);

  String clientId = String(AHU)+"-"+String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = mqtt.connect(clientId.c_str(),
                         MQTT_USER, MQTT_PASS,
                         tStatus().c_str(), 1, true, "offline");
  if(ok){
    publishStatusOnline();
    mqtt.subscribe(tCmd().c_str(), 1);
    mqtt.subscribe(tProvWifi().c_str(), 1);
    mqtt.subscribe(tProvBroker().c_str(), 1);
    motorLogMsg("MQTT connected to " + mqttHost + ":" + String(MQTT_PORT));
    publishState();
  }else{
    motorLogMsg("MQTT connect failed");
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

  Wire.begin(21,22);
  if (!sht4.begin()){
    motorLogMsg("SHT45 not found!");
  } else {
    sht4.setPrecision(SHT4X_HIGH_PRECISION);
    sht4.setHeater(SHT4X_NO_HEATER);
    motorLogMsg("SHT45 ready");
  }

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

  // Load broker host/port
  mqttHost = prefs.getString("mqtt_host", String("10.42.0.1")); // you can later provision "mqtt-broker.local"
  MQTT_PORT = prefs.getUShort("mqtt_port", 1883);

  motorLogMsg("Boot complete. Send 'start' in Serial or via MQTT cmd.");

  // First Wi-Fi connect attempt starts immediately
  lastWifiAttemptAt = 0;
}

// ---------- Loop ----------
void loop(){
  unsigned long now = millis();

  // Wi-Fi maintenance (STA-only, rotate between primary & secondary)
  if (WiFi.status()!=WL_CONNECTED) rotateWifiIfNeeded();

  // MQTT maintenance
  if (WiFi.status()==WL_CONNECTED){ ensureMqtt(); if(mqtt.connected()) mqtt.loop(); }

  // Sensors + telemetry
  handleSerial();
  readSensorIfDue();

  // Always evaluate controls using filtered readings (but gated by runState)
  controlCP(filtTempC);
  controlHeater(filtHum);

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
