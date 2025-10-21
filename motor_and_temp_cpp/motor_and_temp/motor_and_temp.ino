#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ---------- Wi-Fi (RPi hotspot) ----------
#define WIFI_SSID "snorlax"
#define WIFI_PASS "12345678"
#define AP_SSID   "ALMED-ESP32"
#define AP_PASS   "12345678"
WebServer server(80);

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

const unsigned long M1_START_RUN = 10UL * 1000UL;
const unsigned long M1_POST_RUN  = 10UL * 1000UL;
const unsigned long M2_INTERVAL  = 30UL * 1000UL;    // TEST
const unsigned long M2_RUN_TIME  = 10UL * 1000UL;    // TEST

bool runState = false, m1Active = false, m2Active = false, shuttingDown = false;
unsigned long m1StopAt = 0, m2StopAt = 0, m2NextAt = 0;

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
const uint16_t MQTT_PORT = 1883;

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

unsigned long lastMqttAttempt = 0;
IPAddress brokerIP;

// ---------- Preferences ----------
Preferences prefs;

// ---------- Forward declarations ----------
void handleRoot();
void handleToggle();
void handleSet();     // temp setpoint
void handleSetHum();  // humidity setpoint

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
    if (!m1Active){ m1_start(); m1StopAt = millis() + M1_START_RUN; }
    m2NextAt = millis() + M2_INTERVAL;
    motorLogMsg("[RUN] STARTED");
  }
}
void stopSystem(){
  if (!runState) return;
  runState = false;
  shuttingDown = true;
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

    // visible log
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

// ---------- HTML ----------
static const char PAGE_TMPL[] PROGMEM = R"rawliteral(
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="3">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ALMED AHU</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f7f9fa; color: #222; margin: 0; }
    .wrap { max-width: 1100px; margin: 16px auto; padding: 0 12px; }
    .row  { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 12px; }
    .card { background: #fff; padding: 12px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,.1); }
    .btn  { padding: 10px 20px; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; }
    .on   { background: #28a745; color: #fff; }
    .off  { background: #e74c3c; color: #fff; }
    .pill { padding: 4px 10px; border-radius: 999px; color: #fff; font-size: 12px; }
    .pill.run  { background: #28a745; }
    .pill.stop { background: #e74c3c; }
    .mono { font-family: ui-monospace, Consolas, Monaco, monospace; white-space: pre-wrap; }
    form.inline { display:flex; gap:8px; align-items:center; }
    input[type=number]{padding:8px;border:1px solid #ccc;border-radius:8px;width:90px;}
    @media (max-width: 900px) { .row { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="row">
      <div class="card">
        <h3>ALMED AHU</h3>
        <div>Status: %RUNSTATE%</div>
        <div>Motor-1 (Drain): <b>%M1%</b></div>
        <div>Motor-2 (Filter): <b>%M2%</b></div>
        <div>CP (Compressor): <b>%CP%</b></div>
        <div>Heater (Dehumidify): <b>%HEAT%</b></div>
        <div>Temp Set: <b>%TEMPSET%</b> &deg;C (db %TEMPDB%&deg;C)</div>
        <div>Hum Set: <b>%HUMSET%</b> %RH (db %HUMDB%%)</div>
        <div>Temp: <b>%TEMP%</b> &deg;C &nbsp; Humidity: <b>%HUM%</b> %</div>
        <br>
        <form action="/toggle"><button class="btn %BTNCLASS%">%BTNTEXT%</button></form>
        <br>
        <form class="inline" action="/set" method="get">
          <label>Temp Set (°C):</label>
          <input name="sp" type="number" step="0.1" min="1" max="100" value="%TEMPSET%">
          <button class="btn on" type="submit">Update</button>
        </form>
        <br>
        <form class="inline" action="/set_hum" method="get">
          <label>Hum Set (%RH):</label>
          <input name="hsp" type="number" step="0.5" min="10" max="90" value="%HUMSET%">
          <button class="btn on" type="submit">Update</button>
        </form>
      </div>
      <div class="card">
        <h3>Temperature Log (last 10)</h3>
        <div class="mono">%TEMPLOG%</div>
      </div>
    </div>

    <div class="row">
      <div class="card">
        <h3>Motor/CP/Heater Log (last 10)</h3>
        <div class="mono">%MOTORLOG%</div>
      </div>
      <div class="card">
        <h3>Notes</h3>
        <div class="mono">MQTT: {"setpoint": 23.5} and {"humset": 55}. Page refreshes every 3s.</div>
      </div>
    </div>
  </div>
</body>
</html>
)rawliteral";

String page(){
  String html = FPSTR(PAGE_TMPL);
  html.replace("%RUNSTATE%", runState ? "<span class='pill run'>RUNNING</span>" : "<span class='pill stop'>STOPPED</span>");
  html.replace("%M1%", m1Active ? "ON" : "OFF");
  html.replace("%M2%", m2Active ? "ON" : "OFF");
  html.replace("%CP%", cpOn ? "ON" : "OFF");
  html.replace("%HEAT%", heatOn ? "ON" : "OFF");
  html.replace("%TEMPSET%", String(tempSet,1));
  html.replace("%TEMPDB%", String(TEMP_DEADBAND,1));
  html.replace("%HUMSET%", String(humSet,1));
  html.replace("%HUMDB%", String(HUM_DEADBAND,1));
  html.replace("%TEMP%", isnan(filtTempC) ? "--" : String(filtTempC,1));
  html.replace("%HUM%",  isnan(filtHum)   ? "--" : String(filtHum,1));
  html.replace("%BTNCLASS%", runState ? "off" : "on");
  html.replace("%BTNTEXT%", runState ? "STOP" : "START");
  html.replace("%TEMPLOG%", renderNewestFirst(tempBuf, tempHead, tempCount));
  html.replace("%MOTORLOG%", renderNewestFirst(motorBuf, motorHead, motorCount));
  return html;
}

// ---------- Web handlers ----------
void handleRoot(){ server.send(200,"text/html; charset=utf-8", page()); }
void handleToggle(){ toggleSystem(); server.sendHeader("Location","/"); server.send(303); }
void handleSet(){  // temperature setpoint
  if (server.hasArg("sp")){
    float sp = server.arg("sp").toFloat();
    if (sp >= 1 && sp <= 100){
      tempSet = sp;
      prefs.putFloat("tempSet", tempSet);
      motorLogMsg("Temp setpoint updated via Web: " + String(tempSet,1) + "C");
      publishState();
    }
  }
  server.sendHeader("Location","/");
  server.send(303);
}
void handleSetHum(){  // humidity setpoint
  if (server.hasArg("hsp")){
    float hs = server.arg("hsp").toFloat();
    if (hs >= 10 && hs <= 90){
      humSet = hs;
      prefs.putFloat("humSet", humSet);
      motorLogMsg("Hum setpoint updated via Web: " + String(humSet,1) + "%");
      publishState();
    }
  }
  server.sendHeader("Location","/");
  server.send(303);
}

// ---------- Wi-Fi ----------
void startWeb(){
  server.on("/ping", [](){ server.send(200, "text/plain", "pong"); });
  server.on("/", handleRoot);
  server.on("/toggle", handleToggle);
  server.on("/set", handleSet);
  server.on("/set_hum", handleSetHum);
  server.onNotFound([](){ server.send(404, "text/plain", "not found"); });
  server.begin();
}
void initWiFi(){
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Wi-Fi connecting");
  unsigned long t0 = millis();
  while (WiFi.status()!=WL_CONNECTED && millis()-t0<10000){ delay(250); Serial.print("."); }
  if (WiFi.status()==WL_CONNECTED){
    Serial.print("\nWi-Fi OK, IP: "); Serial.println(WiFi.localIP());
    motorLogMsg("Wi-Fi Connected, IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWi-Fi STA failed, starting AP...");
    WiFi.mode(WIFI_AP); WiFi.softAP(AP_SSID, AP_PASS);
    IPAddress ip = WiFi.softAPIP();
    Serial.print("AP SSID: "); Serial.println(AP_SSID);
    Serial.print("AP IP  : "); Serial.println(ip);
    motorLogMsg("AP Mode: " + String(AP_SSID) + " IP: " + ip.toString());
  }
  startWeb();
}

// ---------- MQTT ----------
void onMqttMessage(char* topic, byte* payload, unsigned int len){
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
  unsigned long now = millis();
  if(now - lastMqttAttempt < 2000) return;
  lastMqttAttempt = now;

  brokerIP.fromString("10.42.0.1"); // Pi hotspot
  mqtt.setServer(brokerIP, MQTT_PORT);
  mqtt.setCallback(onMqttMessage);

  String clientId = String(AHU)+"-"+String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = mqtt.connect(clientId.c_str(),
                         MQTT_USER, MQTT_PASS,
                         tStatus().c_str(), 1, true, "offline");
  if(ok){
    mqtt.publish(tStatus().c_str(), "online", true);   // retained
    mqtt.subscribe(tCmd().c_str(), 1);
    motorLogMsg("MQTT connected to " + brokerIP.toString());
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
  float sp = prefs.getFloat("tempSet", tempSet);
  if (sp>=1 && sp<=100) tempSet = sp;
  float hs = prefs.getFloat("humSet", humSet);
  if (hs>=10 && hs<=90) humSet = hs;

  initWiFi();
  motorLogMsg("Boot complete. Send 'start' in Serial or press START on web.");
}

// ---------- Loop ----------
void loop(){
  unsigned long now = millis();
  server.handleClient();
  handleSerial();
  readSensorIfDue();

  if (WiFi.status()==WL_CONNECTED){ ensureMqtt(); if(mqtt.connected()) mqtt.loop(); }

  // Always evaluate controls using filtered readings (but gated by runState)
  controlCP(filtTempC);
  controlHeater(filtHum);

  // Shutdown drain → only Motor-1 runs for its window
  if (shuttingDown){
    if (!m1Active){
      if (m2Active) m2_stop();
      m1_start();
      m1StopAt = now + M1_POST_RUN;
      motorLogMsg("Shutdown drain started (10s)");
      publishState();
    }
    if (m1Active && now >= m1StopAt){
      m1_stop();
      shuttingDown=false;
      motorLogMsg("System OFF");
      publishState();
    }
    delay(5); return;
  }

  // While RUNNING
  if (runState){
    if (m1Active && now >= m1StopAt) { m1_stop(); publishState(); }
    if (!m2Active && !m1Active && now >= m2NextAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL;
      publishState();
    }
  }
  if (m2Active && now >= m2StopAt) { m2_stop(); publishState(); }

  delay(5);
}
