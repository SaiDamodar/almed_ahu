#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>

// ===== Wi-Fi =====
#define WIFI_SSID "AlMed"
#define WIFI_PASS "AlMed123456"
#define AP_SSID  "ALMED-ESP32"
#define AP_PASS  "12345678"
WebServer server(80);

// ===== SHT45 =====
Adafruit_SHT4x sht4;
float tempC = NAN, hum = NAN;
unsigned long lastSensorAt = 0;
const unsigned long SENSOR_PERIOD = 2000; // 2 s

// ===== L298N / Motors =====
#define IN1 25
#define IN2 26
#define ENA 33
#define IN3 27
#define IN4 14
#define ENB 32

const unsigned long M1_START_RUN = 10UL * 1000UL;    // Motor-1 ON when START pressed
const unsigned long M1_POST_RUN  = 10UL * 1000UL;    // Motor-1 ON after STOP
const unsigned long M2_INTERVAL  = 30UL * 1000UL;    // TEST: 30s (prod: 15*60*1000UL)
const unsigned long M2_RUN_TIME  = 10UL * 1000UL;    // Motor-2 ON 10s

bool runState = false, m1Active = false, m2Active = false, shuttingDown = false;
unsigned long m1StopAt = 0, m2StopAt = 0, m2NextAt = 0; // m2NextAt = next scheduled start

// ===== Ring buffers for logs (last 10) =====
const int LOG_MAX = 10;
String tempBuf[LOG_MAX]; int tempHead = -1; int tempCount = 0;
String motorBuf[LOG_MAX]; int motorHead = -1; int motorCount = 0;

void pushTempHTML(const String& line)  { tempHead  = (tempHead  + 1) % LOG_MAX; tempBuf[tempHead]  = line; if (tempCount  < LOG_MAX) tempCount++; }
void pushMotorHTML(const String& line) { motorHead = (motorHead + 1) % LOG_MAX; motorBuf[motorHead] = line; if (motorCount < LOG_MAX) motorCount++; }
String renderNewestFirst(String buf[], int head, int cnt){
  if (cnt == 0) return "—";
  String out; for (int i=0;i<cnt;i++){ int idx=head-i; if(idx<0) idx+=LOG_MAX; out += buf[idx] + "<br>"; } return out;
}
void motorLogMsg(const String& s){ Serial.println(s); pushMotorHTML(s); }

// ===== Motor helpers =====
void m1_start(){ digitalWrite(IN1,HIGH); digitalWrite(IN2,LOW); digitalWrite(ENA,HIGH); m1Active=true;  motorLogMsg("Motor-1 ON (Drain)"); }
void m1_stop (){ digitalWrite(ENA,LOW);  digitalWrite(IN1,LOW);  digitalWrite(IN2,LOW);  m1Active=false; motorLogMsg("Motor-1 OFF"); }
void m2_start(){ digitalWrite(IN3,HIGH); digitalWrite(IN4,LOW); digitalWrite(ENB,HIGH); m2Active=true;  motorLogMsg("Motor-2 ON (Filter Clean)"); }
void m2_stop (){ digitalWrite(ENB,LOW);  digitalWrite(IN3,LOW);  digitalWrite(IN4,LOW);  m2Active=false; motorLogMsg("Motor-2 OFF"); }

// ===== System control =====
void startSystem(){
  if (shuttingDown) return;
  if (!runState){
    runState = true;
    // immediately run Motor-1 for 10s on START
    if (!m1Active){ m1_start(); m1StopAt = millis() + M1_START_RUN; }
    // schedule first Motor-2 cycle AFTER full interval (no immediate start)
    m2NextAt = millis() + M2_INTERVAL;
    motorLogMsg("[RUN] STARTED");
  }
}
void stopSystem(){
  if (!runState) return;
  runState = false;
  shuttingDown = true;                        // handled in loop()
  motorLogMsg("[RUN] STOP requested → Shutdown Drain");
}
void toggleSystem(){ if (runState) stopSystem(); else startSystem(); }

// ===== Sensor read =====
void readSensorIfDue(){
  unsigned long now = millis();
  if (now - lastSensorAt < SENSOR_PERIOD) return;
  lastSensorAt = now;

  sensors_event_t he, te;
  sht4.getEvent(&he, &te);
  if (!isnan(te.temperature) && !isnan(he.relative_humidity)) {
    tempC = te.temperature; hum = he.relative_humidity;
    Serial.print("Temp: "); Serial.print(tempC,1); Serial.print(" °C | Hum: "); Serial.print(hum,1); Serial.println("%");
    pushTempHTML("Temp: " + String(tempC,1) + "&deg;C | Hum: " + String(hum,1) + "%");
  } else {
    Serial.println("SHT45 read failed");
    pushTempHTML("SHT45 read failed");
  }
}

// ===== Web page =====
String page(){
  String html = R"(
  <html>
  <head>
    <meta charset='UTF-8'>
    <meta http-equiv='refresh' content='3'>
    <style>
      body{font-family:Arial;background:#f7f9fa;color:#222}
      .row{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:12px}
      .card{background:#fff;padding:12px;border-radius:10px;box-shadow:0 2px 4px rgba(0,0,0,.1)}
      .btn{padding:10px 20px;border:none;border-radius:8px;font-size:16px}
      .on{background:#28a745;color:#fff}
      .off{background:#e74c3c;color:#fff}
      .pill{padding:4px 10px;border-radius:999px;color:#fff;font-size:12px}
      .pill.run{background:#28a745}.pill.stop{background:#e74c3c}
      .mono{font-family:ui-monospace,Consolas,monaco,monospace}
    </style>
  </head>
  <body>
  <div class='row'>
    <div class='card'>
      <h3>ALMED AHU</h3>
      <div>Status: %RUNSTATE%</div>
      <div>Motor-1 (Drain): <b>%M1%</b></div>
      <div>Motor-2 (Filter): <b>%M2%</b></div>
      <div>Temp: <b>%TEMP%</b> &deg;C &nbsp; Humidity: <b>%HUM%</b> %</div>
      <br>
      <form action='/toggle'><button class='btn %BTNCLASS%'>%BTNTEXT%</button></form>
    </div>

    <div class='card'>
      <h3>Temperature Log (last 10)</h3>
      <div class='mono'>%TEMPLOG%</div>
    </div>
  </div>

  <div class='row'>
    <div class='card'>
      <h3>Motor Log (last 10)</h3>
      <div class='mono'>%MOTORLOG%</div>
    </div>
    <div class='card'>
      <h3>Notes</h3>
      <div class='mono'>Newest entries appear on top. Page refreshes every 3s.</div>
    </div>
  </div>
  </body></html>)";

  html.replace("%RUNSTATE%", runState ? "<span class='pill run'>RUNNING</span>" : "<span class='pill stop'>STOPPED</span>");
  html.replace("%M1%", m1Active ? "ON" : "OFF");
  html.replace("%M2%", m2Active ? "ON" : "OFF");
  html.replace("%TEMP%", isnan(tempC) ? "--" : String(tempC,1));
  html.replace("%HUM%",  isnan(hum)   ? "--" : String(hum,1));
  html.replace("%BTNCLASS%", runState ? "off" : "on");
  html.replace("%BTNTEXT%", runState ? "STOP" : "START");
  html.replace("%TEMPLOG%", renderNewestFirst(tempBuf, tempHead, tempCount));
  html.replace("%MOTORLOG%", renderNewestFirst(motorBuf, motorHead, motorCount));
  return html;
}

void handleRoot(){ server.send(200,"text/html",page()); }
void handleToggle(){ toggleSystem(); server.sendHeader("Location","/"); server.send(303); }

// ===== Wi-Fi =====
void startWeb(){
  server.on("/", handleRoot);
  server.on("/toggle", handleToggle);
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

// ===== Serial command parsing (start/stop/toggle) =====
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
      else if (serialBuf.length()) motorLogMsg("Unknown cmd: " + serialBuf);
      serialBuf = "";
    } else {
      serialBuf += ch;
      if (serialBuf.length() > 64) serialBuf = serialBuf.substring(0,64);
    }
  }
}

// ===== Setup =====
void setup(){
  Serial.begin(115200);

  pinMode(IN1,OUTPUT); pinMode(IN2,OUTPUT); pinMode(ENA,OUTPUT);
  pinMode(IN3,OUTPUT); pinMode(IN4,OUTPUT); pinMode(ENB,OUTPUT);
  digitalWrite(ENA,LOW); digitalWrite(ENB,LOW);
  digitalWrite(IN1,LOW); digitalWrite(IN2,LOW);
  digitalWrite(IN3,LOW); digitalWrite(IN4,LOW);

  Wire.begin(21,22);
  if (!sht4.begin()){
    motorLogMsg("SHT45 not found!");
  } else {
    sht4.setPrecision(SHT4X_HIGH_PRECISION);
    sht4.setHeater(SHT4X_NO_HEATER);
    motorLogMsg("SHT45 ready");
  }

  initWiFi();

  // >>> No motor at boot. Wait for START (web or serial).
  motorLogMsg("Boot complete. Send 'start' in Serial or press START on web.");
}

// ===== Loop =====
void loop(){
  unsigned long now = millis();
  server.handleClient();
  handleSerial();
  readSensorIfDue();

  // Shutdown drain → only Motor-1 runs for its window
  if (shuttingDown){
    if (!m1Active){
      if (m2Active) m2_stop();
      m1_start();
      m1StopAt = now + M1_POST_RUN;
      motorLogMsg("Shutdown drain started (10s)");
    }
    if (m1Active && now >= m1StopAt){
      m1_stop();
      shuttingDown=false;
      motorLogMsg("System OFF");
    }
    delay(5); return;
  }

  // While RUNNING
  if (runState){
    // stop Motor-1 after its START window
    if (m1Active && now >= m1StopAt) m1_stop();

    // schedule Motor-2 strictly by m2NextAt (never overlaps M1)
    if (!m2Active && !m1Active && now >= m2NextAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL; // schedule the next run
    }
  }

  // Stop Motor-2 after its window
  if (m2Active && now >= m2StopAt) m2_stop();

  delay(5);
}
