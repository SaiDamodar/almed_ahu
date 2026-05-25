/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  ALMED AHU — Eco Touch Display
 *  ESP32 + ILI9341 3.5" / 4" SPI TFT with XPT2046 Touch Controller
 *  320 × 240 landscape
 *
 *  ── What it does ──────────────────────────────────────────────────────────
 *  • Connects to the same local WiFi / MQTT broker the AHU ESP32 uses
 *  • Auto-discovers every AHU device from their retained /status topic
 *  • Shows a scrollable touch-driven device picker
 *  • Displays live Temperature + Humidity for the selected device
 *  • Lets you raise/lower each setpoint with on-screen touch buttons
 *  • Start / Stop the AHU with a touch button
 *  • Screen lock (tap lock icon to lock; tap again to enter 6-digit passcode)
 *
 *  ── Zero changes required on esp32_main ──────────────────────────────────
 *  Device discovery is driven purely by the RETAINED
 *    almed/ahu/{site}/{room}/{ahu}/status  →  payload "online"
 *  and retained
 *    almed/ahu/{site}/{room}/{ahu}/state   →  JSON with thing, ip, run, etc.
 *  which the main ESP already publishes.
 *
 *  ── Hardware ──────────────────────────────────────────────────────────────
 *  Any ESP32 (WROOM / WROVER / DevKit)  +
 *  ILI9341 SPI TFT with on-board XPT2046 touch (very common 3.5" module)
 *
 *  ── Libraries (install via Arduino Library Manager) ──────────────────────
 *  • TFT_eSPI        by Bodmer          (>=2.5.43)
 *  • PubSubClient     by Nick O'Leary   (>=2.8)
 *  • ArduinoJson      by Benoit Blanchon (>=7 or 6.21+)
 *  • XPT2046_Touchscreen by Paul Stoffregen  (>=1.4)
 *
 *  IMPORTANT: Copy User_Setup.h from this folder into
 *    ~/Arduino/libraries/TFT_eSPI/User_Setup.h
 *  (or configure TFT_eSPI with User_Setup_Select.h to point at our file)
 * ═══════════════════════════════════════════════════════════════════════════
 */

// ─── TFT_eSPI must be included BEFORE XPT2046 ────────────────────────────────
#include <SPI.h>
#include <TFT_eSPI.h>
#include <XPT2046_Touchscreen.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ════════════════════════════════════════════════════════════════════════════
//  PIN MAP  (ILI9341 shares SPI bus with XPT2046; CS pins are separate)
// ════════════════════════════════════════════════════════════════════════════
//
//  Signal        ILI9341 pin   XPT2046 pin   ESP32 GPIO
//  ─────────────────────────────────────────────────────
//  MOSI (SDI)       6            DIN            23
//  SCK  (CLK)       7            CLK            18
//  MISO             —            DO             19   ← touch only
//  TFT CS           5            —               5
//  TFT DC/RS        4            —               2
//  TFT RST          3            —               4   (or tie to EN)
//  TFT LED          1            —              3V3  (always on)
//  Touch CS         —            CS             15
//  Touch IRQ        —            IRQ            (optional, not used here)
//  VCC              both         both           3V3
//  GND              both         both           GND
//
// ════════════════════════════════════════════════════════════════════════════

#define TOUCH_CS  15   // XPT2046 chip-select
// TFT pins are configured in User_Setup.h / TFT_eSPI config

// ─── Touch calibration ───────────────────────────────────────────────────────
// These are approximate values for a typical ILI9341 + XPT2046 module.
// Adjust after running a calibration sketch if touch is off.
#define TOUCH_X_MIN   200
#define TOUCH_X_MAX  3900
#define TOUCH_Y_MIN   300
#define TOUCH_Y_MAX  3800

// ─── WiFi ────────────────────────────────────────────────────────────────────
const char* WIFI_SSID     = "PiSpot";       // Same hotspot the AHU ESP uses
const char* WIFI_PASSWORD = "12345678";

// ─── MQTT ────────────────────────────────────────────────────────────────────
// The main AHU ESP32 is the WiFi hotspot at 10.42.0.1 and runs mosquitto there.
const char* MQTT_BROKER   = "10.42.0.1";
const int   MQTT_PORT     = 1883;
const char* MQTT_USER     = "almed";
const char* MQTT_PASS     = "Almed1234$";
const char* MQTT_CLIENT   = "eco_display_01";

// ─── Screen lock passcode ────────────────────────────────────────────────────
#define DEFAULT_PASSCODE "123123"   // Must be 6 digits

// ═══════════════════════════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════
#define MAX_DEVICES         8
#define DEVICE_STALE_MS     90000UL   // Remove device if no status for 90 s
#define DISCOVERY_WAIT_MS   5000UL    // Auto-advance from scanning screen
#define MQTT_RETRY_MS       5000UL
#define TOUCH_DEBOUNCE_MS   300UL
#define REFRESH_MS          350UL     // Display refresh interval

// ─── Display dimensions (landscape) ─────────────────────────────────────────
#define SCR_W  320
#define SCR_H  240

// ─── UI layout constants ─────────────────────────────────────────────────────
#define TOPBAR_H     26
#define BOTBAR_H     26
#define CARD_GAP      6
#define CARD_RADIUS   6

// ─── Colour palette (RGB565) ─────────────────────────────────────────────────
#define C_BG         0x0000   // Pure black
#define C_TOPBAR     0x0841   // Very dark blue-grey
#define C_CARD       0x1084   // Dark grey
#define C_CARD2      0x18A3   // Slightly lighter card
#define C_BORDER     0x2945   // Dim border
#define C_PRIMARY    0x3B9F   // Blue accent
#define C_PRIMARY_LT 0x5DDF   // Lighter blue (hover)
#define C_TEXT       0xFFFF   // White
#define C_DIM        0x8C71   // Grey text
#define C_GREEN      0x07E0   // Green
#define C_GREEN_DK   0x03E0   // Dark green (run bar)
#define C_RED        0xF800   // Red
#define C_RED_DK     0x7800   // Dark red
#define C_ORANGE     0xFD20   // Orange (lock)
#define C_YELLOW     0xFFE0   // Yellow (setpoint)
#define C_HILIGHT    0x3A4A   // Dropdown row highlight

// ═══════════════════════════════════════════════════════════════════════════
//  DATA STRUCTURES
// ═══════════════════════════════════════════════════════════════════════════

struct AhuDevice {
  bool   active;
  char   site[24];
  char   room[24];
  char   ahu[16];
  char   thingName[32];   // from /state  → doc["thing"]
  char   ip[16];          // from /state  → doc["ip"]
  bool   run;             // from /state or /telemetry
  float  temp;            // live from /telemetry
  float  hum;             // live from /telemetry
  float  tempSet;         // from /state or /telemetry
  float  humSet;          // from /state or /telemetry
  unsigned long lastSeen; // millis() of last /status or /telemetry
};

// ═══════════════════════════════════════════════════════════════════════════
//  GLOBALS
// ═══════════════════════════════════════════════════════════════════════════

TFT_eSPI          tft;
XPT2046_Touchscreen touch(TOUCH_CS);

WiFiClient        espNet;
PubSubClient      mqtt(espNet);
Preferences       prefs;

AhuDevice         devices[MAX_DEVICES];
int               deviceCount      = 0;
int               selectedIdx      = -1;   // index in devices[]

// ─── Screen state machine ────────────────────────────────────────────────────
enum Screen { SCR_SCANNING, SCR_SELECT, SCR_CONTROL, SCR_KEYPAD };
Screen  curScreen     = SCR_SCANNING;
bool    needRedraw    = true;

// ─── Dropdown state ──────────────────────────────────────────────────────────
int   listCursor      = 0;   // selected row (0-based over active devices)
int   listScroll      = 0;   // first visible row
#define LIST_ROWS     4
#define LIST_ROW_H    50
#define LIST_Y_START  (TOPBAR_H + 4)

// ─── Control screen state ────────────────────────────────────────────────────
int   editFocus       = 0;   // 0 = temp, 1 = hum

// ─── Lock ────────────────────────────────────────────────────────────────────
bool  isLocked        = true;
char  passcode[7];           // 6 digits + null
char  enteredCode[7] = "";
int   codePos         = 0;
Screen preLockScreen  = SCR_CONTROL;

// ─── Timing ──────────────────────────────────────────────────────────────────
unsigned long scanStartMs     = 0;
unsigned long lastMqttAttempt = 0;
unsigned long lastRefreshMs   = 0;
unsigned long lastTouchMs     = 0;

bool   wifiOk  = false;
bool   mqttOk  = false;

// Cmd topic built when a device is selected
char   cmdTopic[128] = "";

// ═══════════════════════════════════════════════════════════════════════════
//  FORWARD DECLARATIONS
// ═══════════════════════════════════════════════════════════════════════════
void connectWifi();
void connectMqtt();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void processStatus(const char* topic);
void processState(const char* topic, const char* json);
void processTelemetry(const char* topic, const char* json);
void parseTopic(const char* topic, char* site, char* room, char* ahu);
int  findOrAdd(const char* site, const char* room, const char* ahu);
void buildCmdTopic(int idx);
void subscribeDevice(int idx);
void unsubscribeDevice(int idx);
void pruneStale();
void sendCmd(const char* json);
void sendTempSet(float v);
void sendHumSet(float v);
void sendToggle();

// ─── Drawing functions ───────────────────────────────────────────────────────
void drawScanScreen();
void drawSelectScreen();
void drawControlScreen();
void drawKeypadScreen();
void drawCard(int x, int y, int w, int h, uint16_t bg, uint16_t border);
void drawRoundBtn(int x, int y, int w, int h, const char* label,
                  uint16_t bg, uint16_t fg);
void drawStatusBar(bool running, bool locked);

// ─── Touch helpers ───────────────────────────────────────────────────────────
bool getTouch(int* px, int* py);
bool touchInRect(int tx, int ty, int rx, int ry, int rw, int rh);

// ─── Touch-event handlers per screen ─────────────────────────────────────────
void handleTouchScan(int tx, int ty);
void handleTouchSelect(int tx, int ty);
void handleTouchControl(int tx, int ty);
void handleTouchKeypad(int tx, int ty);

// ═══════════════════════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=== ALMED Eco Touch Display ===");

  // Initialise device array
  memset(devices, 0, sizeof(devices));
  for (int i = 0; i < MAX_DEVICES; i++) devices[i].temp = devices[i].hum = NAN;

  // Load persisted settings
  prefs.begin("eco_disp", false);
  isLocked = prefs.getBool("locked", true);
  String saved = prefs.getString("passcode", DEFAULT_PASSCODE);
  saved.toCharArray(passcode, 7);
  prefs.end();

  // SPI + TFT
  SPI.begin(18, 19, 23, 5);   // SCK, MISO, MOSI, SS(unused – each device uses own CS)
  tft.init();
  tft.setRotation(1);          // Landscape, USB connector on left
  tft.fillScreen(C_BG);

  // Touch controller (shares SPI bus, separate CS)
  touch.begin();
  touch.setRotation(1);

  // Splash
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_PRIMARY, C_BG);
  tft.setTextSize(3);
  tft.drawString("ALMED", SCR_W / 2, 90);
  tft.setTextColor(C_DIM, C_BG);
  tft.setTextSize(1);
  tft.drawString("AHU Eco Touch Display  v2.0", SCR_W / 2, 130);
  tft.drawString("Connecting...", SCR_W / 2, 160);
  delay(1000);

  connectWifi();

  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(768);

  scanStartMs = millis();
  curScreen   = SCR_SCANNING;
  needRedraw  = true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOOP
// ═══════════════════════════════════════════════════════════════════════════
void loop() {
  // ── WiFi watchdog ──────────────────────────────────────────────────────────
  if (WiFi.status() != WL_CONNECTED) {
    if (wifiOk) {
      wifiOk = false;
      needRedraw = true;
    }
    connectWifi();
  } else {
    if (!wifiOk) { wifiOk = true; needRedraw = true; }
  }

  // ── MQTT watchdog ──────────────────────────────────────────────────────────
  if (wifiOk && !mqtt.connected()) {
    if (mqttOk) { mqttOk = false; needRedraw = true; }
    if (millis() - lastMqttAttempt > MQTT_RETRY_MS) {
      lastMqttAttempt = millis();
      connectMqtt();
    }
  } else if (mqtt.connected() && !mqttOk) {
    mqttOk = true;
    needRedraw = true;
  }

  mqtt.loop();

  // ── Auto-advance from scanning ─────────────────────────────────────────────
  if (curScreen == SCR_SCANNING &&
      millis() - scanStartMs > DISCOVERY_WAIT_MS) {
    curScreen  = SCR_SELECT;
    needRedraw = true;
  }

  // ── Prune stale devices ────────────────────────────────────────────────────
  pruneStale();

  // ── Touch input ────────────────────────────────────────────────────────────
  if (millis() - lastTouchMs > TOUCH_DEBOUNCE_MS) {
    int tx, ty;
    if (getTouch(&tx, &ty)) {
      lastTouchMs = millis();
      switch (curScreen) {
        case SCR_SCANNING: handleTouchScan(tx, ty);    break;
        case SCR_SELECT:   handleTouchSelect(tx, ty);  break;
        case SCR_CONTROL:  handleTouchControl(tx, ty); break;
        case SCR_KEYPAD:   handleTouchKeypad(tx, ty);  break;
      }
      needRedraw = true;
    }
  }

  // ── Redraw ─────────────────────────────────────────────────────────────────
  if (needRedraw || millis() - lastRefreshMs > REFRESH_MS) {
    lastRefreshMs = millis();
    needRedraw    = false;
    switch (curScreen) {
      case SCR_SCANNING: drawScanScreen();    break;
      case SCR_SELECT:   drawSelectScreen();  break;
      case SCR_CONTROL:  drawControlScreen(); break;
      case SCR_KEYPAD:   drawKeypadScreen();  break;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIFI  /  MQTT
// ═══════════════════════════════════════════════════════════════════════════
void connectWifi() {
  Serial.print("WiFi → ");
  Serial.println(WIFI_SSID);

  tft.fillScreen(C_BG);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_DIM, C_BG);
  tft.setTextSize(1);
  tft.drawString("Connecting to " + String(WIFI_SSID), SCR_W / 2, SCR_H / 2);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 40) {
    delay(500);
    tries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiOk = true;
    Serial.println("WiFi OK: " + WiFi.localIP().toString());
  } else {
    Serial.println("WiFi failed – will retry");
  }
}

void connectMqtt() {
  Serial.print("MQTT → ");
  // Last-will: "offline" on eco_display/status
  if (mqtt.connect(MQTT_CLIENT, MQTT_USER, MQTT_PASS,
                   "almed/eco_display/status", 1, true, "offline")) {
    mqttOk = true;
    Serial.println("connected");

    // Subscribe to ALL AHU topics – wildcard catches /status, /state, /telemetry
    mqtt.subscribe("almed/ahu/#", 1);

    // Announce ourselves
    mqtt.publish("almed/eco_display/status", "online", true);

    // If a device was already selected, re-subscribe (after reconnect)
    if (selectedIdx >= 0) {
      subscribeDevice(selectedIdx);
    }
  } else {
    Serial.print("failed rc=");
    Serial.println(mqtt.state());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MQTT CALLBACK
// ═══════════════════════════════════════════════════════════════════════════
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Null-terminate payload
  static char buf[768];
  if (length >= sizeof(buf)) length = sizeof(buf) - 1;
  memcpy(buf, payload, length);
  buf[length] = '\0';

  String t(topic);

  // ── /status ─────────────────────────────────────────────────────────────
  // payload is plain text: "online" or "offline"
  if (t.endsWith("/status")) {
    processStatus(topic);
    return;
  }

  // ── /state ──────────────────────────────────────────────────────────────
  if (t.endsWith("/state")) {
    processState(topic, buf);
    return;
  }

  // ── /telemetry ──────────────────────────────────────────────────────────
  if (t.endsWith("/telemetry")) {
    processTelemetry(topic, buf);
    return;
  }
}

// ─── Process /status (retained "online"/"offline") ───────────────────────────
void processStatus(const char* topic) {
  // topic format: almed/ahu/{site}/{room}/{ahu}/status
  char site[24], room[24], ahu[16];
  parseTopic(topic, site, room, ahu);

  // Skip malformed or empty segments
  if (strlen(site) == 0 || strlen(ahu) == 0) return;

  int idx = findOrAdd(site, room, ahu);
  if (idx < 0) return;

  devices[idx].lastSeen = millis();
  devices[idx].active   = true;

  // Re-draw list / scan screen
  if (curScreen == SCR_SCANNING || curScreen == SCR_SELECT) needRedraw = true;
}

// ─── Process /state (retained JSON) ──────────────────────────────────────────
void processState(const char* topic, const char* json) {
  char site[24], room[24], ahu[16];
  parseTopic(topic, site, room, ahu);
  if (strlen(site) == 0 || strlen(ahu) == 0) return;

  int idx = findOrAdd(site, room, ahu);
  if (idx < 0) return;

  StaticJsonDocument<512> doc;
  if (deserializeJson(doc, json)) return;

  // Extract useful fields
  if (doc.containsKey("thing")) strncpy(devices[idx].thingName, doc["thing"] | "", 31);
  if (doc.containsKey("ip"))    strncpy(devices[idx].ip,        doc["ip"]    | "", 15);
  if (doc.containsKey("run"))   devices[idx].run     = doc["run"].as<bool>();
  if (doc.containsKey("tempSet")) devices[idx].tempSet = doc["tempSet"].as<float>();
  if (doc.containsKey("humSet"))  devices[idx].humSet  = doc["humSet"].as<float>();

  devices[idx].lastSeen = millis();
  devices[idx].active   = true;

  if (curScreen == SCR_SCANNING || curScreen == SCR_SELECT) needRedraw = true;
  if (idx == selectedIdx) needRedraw = true;
}

// ─── Process /telemetry (frequent JSON) ──────────────────────────────────────
void processTelemetry(const char* topic, const char* json) {
  char site[24], room[24], ahu[16];
  parseTopic(topic, site, room, ahu);
  if (strlen(site) == 0 || strlen(ahu) == 0) return;

  int idx = findOrAdd(site, room, ahu);
  if (idx < 0) return;

  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, json)) return;

  if (doc.containsKey("temp"))    devices[idx].temp    = doc["temp"].as<float>();
  if (doc.containsKey("hum"))     devices[idx].hum     = doc["hum"].as<float>();
  if (doc.containsKey("run"))     devices[idx].run     = doc["run"].as<bool>();
  if (doc.containsKey("tempSet")) devices[idx].tempSet = doc["tempSet"].as<float>();
  if (doc.containsKey("humSet"))  devices[idx].humSet  = doc["humSet"].as<float>();

  devices[idx].lastSeen = millis();
  devices[idx].active   = true;

  if (idx == selectedIdx) needRedraw = true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  DEVICE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════

// Parse topic:  almed/ahu/{site}/{room}/{ahu}/{subtopic}
void parseTopic(const char* topic, char* site, char* room, char* ahu) {
  site[0] = room[0] = ahu[0] = '\0';

  // Count slashes to find segments
  // Expected:  0=almed  1=ahu  2=site  3=room  4=ahu_id  5=subtopic
  const char* p = topic;
  int seg = 0;
  const char* segStart = p;

  while (*p) {
    if (*p == '/') {
      int len = p - segStart;
      if (seg == 2 && len < 24) { strncpy(site, segStart, len); site[len] = '\0'; }
      if (seg == 3 && len < 24) { strncpy(room, segStart, len); room[len] = '\0'; }
      if (seg == 4 && len < 16) { strncpy(ahu,  segStart, len); ahu[len]  = '\0'; }
      seg++;
      segStart = p + 1;
    }
    p++;
  }
  // Last segment (subtopic) — we don't need it
}

int findOrAdd(const char* site, const char* room, const char* ahu) {
  // Look for existing entry
  for (int i = 0; i < MAX_DEVICES; i++) {
    if (devices[i].active &&
        strcmp(devices[i].site, site) == 0 &&
        strcmp(devices[i].room, room) == 0 &&
        strcmp(devices[i].ahu,  ahu)  == 0) {
      return i;
    }
  }
  // Find empty slot
  for (int i = 0; i < MAX_DEVICES; i++) {
    if (!devices[i].active) {
      strncpy(devices[i].site, site, 23);
      strncpy(devices[i].room, room, 23);
      strncpy(devices[i].ahu,  ahu,  15);
      devices[i].thingName[0] = '\0';
      devices[i].ip[0]        = '\0';
      devices[i].run          = false;
      devices[i].temp         = NAN;
      devices[i].hum          = NAN;
      devices[i].tempSet      = 22.0f;
      devices[i].humSet       = 55.0f;
      devices[i].lastSeen     = millis();
      devices[i].active       = true;
      deviceCount++;
      Serial.printf("New device [%d]: %s/%s/%s\n", i, site, room, ahu);
      return i;
    }
  }
  return -1;  // table full
}

void pruneStale() {
  for (int i = 0; i < MAX_DEVICES; i++) {
    if (!devices[i].active) continue;
    if (millis() - devices[i].lastSeen > DEVICE_STALE_MS) {
      Serial.printf("Prune stale [%d] %s\n", i, devices[i].ahu);
      if (i == selectedIdx) {
        // Our device went away — go back to list
        selectedIdx = -1;
        curScreen   = SCR_SELECT;
        needRedraw  = true;
      }
      memset(&devices[i], 0, sizeof(AhuDevice));
      devices[i].temp = devices[i].hum = NAN;
      deviceCount = max(0, deviceCount - 1);
      needRedraw = true;
    }
  }
}

void buildCmdTopic(int idx) {
  snprintf(cmdTopic, sizeof(cmdTopic),
           "almed/ahu/%s/%s/%s/cmd",
           devices[idx].site, devices[idx].room, devices[idx].ahu);
}

void subscribeDevice(int idx) {
  if (idx < 0 || !devices[idx].active) return;
  char base[96];
  snprintf(base, sizeof(base), "almed/ahu/%s/%s/%s",
           devices[idx].site, devices[idx].room, devices[idx].ahu);
  // /state and /telemetry are already covered by almed/ahu/#
  buildCmdTopic(idx);
  Serial.printf("Watching device: %s\n", base);
}

void unsubscribeDevice(int idx) {
  // We keep almed/ahu/# active; just clear selection
  (void)idx;
  cmdTopic[0] = '\0';
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMMANDS  →  ESP32_main
// ═══════════════════════════════════════════════════════════════════════════
void sendCmd(const char* json) {
  if (!mqttOk || selectedIdx < 0 || strlen(cmdTopic) == 0) return;
  if (isLocked) return;
  mqtt.publish(cmdTopic, json, false);
  Serial.printf("CMD → %s : %s\n", cmdTopic, json);
}

void sendTempSet(float v) {
  char buf[48];
  snprintf(buf, sizeof(buf), "{\"setpoint\":%.1f}", v);
  sendCmd(buf);
}

void sendHumSet(float v) {
  char buf[48];
  snprintf(buf, sizeof(buf), "{\"humset\":%.1f}", v);
  sendCmd(buf);
}

void sendToggle() {
  sendCmd("{\"toggle\":true}");
}

// ═══════════════════════════════════════════════════════════════════════════
//  TOUCH HELPERS
// ═══════════════════════════════════════════════════════════════════════════
bool getTouch(int* px, int* py) {
  if (!touch.touched()) return false;

  TS_Point p = touch.getPoint();

  // Map raw ADC values to screen pixels (landscape rotation 1)
  // Raw X → screen X,  Raw Y → screen Y
  *px = map(p.x, TOUCH_X_MIN, TOUCH_X_MAX, 0, SCR_W - 1);
  *py = map(p.y, TOUCH_Y_MIN, TOUCH_Y_MAX, 0, SCR_H - 1);

  // Clamp
  *px = constrain(*px, 0, SCR_W - 1);
  *py = constrain(*py, 0, SCR_H - 1);

  Serial.printf("Touch raw(%d,%d) → screen(%d,%d)\n", p.x, p.y, *px, *py);
  return true;
}

bool touchInRect(int tx, int ty, int rx, int ry, int rw, int rh) {
  return tx >= rx && tx < rx + rw && ty >= ry && ty < ry + rh;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TOUCH EVENT HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

// ─── Scanning screen — any tap skips to select ───────────────────────────────
void handleTouchScan(int tx, int ty) {
  curScreen  = SCR_SELECT;
  needRedraw = true;
}

// ─── Select screen ───────────────────────────────────────────────────────────
void handleTouchSelect(int tx, int ty) {
  // Build active-device index map
  int map_arr[MAX_DEVICES];
  int count = 0;
  for (int i = 0; i < MAX_DEVICES; i++) {
    if (devices[i].active) map_arr[count++] = i;
  }
  if (count == 0) return;

  // Scroll UP arrow  (top 26 px = top bar – already handled by select screen)
  // Row tap
  for (int row = 0; row < LIST_ROWS; row++) {
    int visIdx = listScroll + row;
    if (visIdx >= count) break;
    int ry = LIST_Y_START + row * LIST_ROW_H;
    if (touchInRect(tx, ty, 4, ry, SCR_W - 8, LIST_ROW_H - 4)) {
      // Tapped this row
      listCursor = visIdx;
      int devIdx = map_arr[visIdx];

      if (selectedIdx >= 0 && selectedIdx != devIdx) {
        unsubscribeDevice(selectedIdx);
      }
      selectedIdx = devIdx;
      subscribeDevice(selectedIdx);
      editFocus  = 0;
      curScreen  = SCR_CONTROL;
      needRedraw = true;
      return;
    }
  }

  // Scroll up button (top-right area)
  if (touchInRect(tx, ty, SCR_W - 36, TOPBAR_H, 32, 22)) {
    if (listScroll > 0) { listScroll--; listCursor = max(0, listCursor - 1); }
  }

  // Scroll down button (bottom-right area)
  if (touchInRect(tx, ty, SCR_W - 36, SCR_H - BOTBAR_H - 22, 32, 22)) {
    if (listScroll + LIST_ROWS < count) { listScroll++; listCursor = min(count-1, listCursor+1); }
  }
}

// ─── Control screen ──────────────────────────────────────────────────────────
//  Layout (y positions):
//   Top bar         0 – 25
//   Temp card      30 – 109   (80px)
//   Hum  card     114 – 193   (80px)
//   Run/action bar 197 – 239
//
//  Inside each card:
//   Big reading: left portion
//   Setpoint row (with – and + buttons): bottom of card
//   Focus toggle: tap anywhere on card to make it "active"

#define CTRL_TEMP_Y   30
#define CTRL_HUM_Y    114
#define CTRL_CARD_H   80
#define CTRL_BTN_W    44
#define CTRL_BTN_H    28
#define CTRL_BTN_Y_OFF 46   // y offset inside card for +/- row

void handleTouchControl(int tx, int ty) {
  if (selectedIdx < 0) return;
  AhuDevice& dev = devices[selectedIdx];

  // ── Lock icon (top-right of top bar) ───────────────────────────────────────
  if (touchInRect(tx, ty, SCR_W - 56, 0, 56, TOPBAR_H)) {
    if (isLocked) {
      // Go to keypad to unlock
      enteredCode[0] = '\0';
      codePos = 0;
      preLockScreen = SCR_CONTROL;
      curScreen     = SCR_KEYPAD;
    } else {
      // Lock immediately
      isLocked = true;
      prefs.begin("eco_disp", false);
      prefs.putBool("locked", isLocked);
      prefs.end();
    }
    needRedraw = true;
    return;
  }

  // ── Back button (top-left of top bar) ────────────────────────────────────
  if (touchInRect(tx, ty, 0, 0, 56, TOPBAR_H)) {
    curScreen  = SCR_SELECT;
    needRedraw = true;
    return;
  }

  // ── Temp card tap (sets focus) ────────────────────────────────────────────
  if (touchInRect(tx, ty, 4, CTRL_TEMP_Y, SCR_W - 8, CTRL_CARD_H)) {
    editFocus = 0;

    // – button (left side of bottom row)
    int btnY = CTRL_TEMP_Y + CTRL_BTN_Y_OFF;
    if (touchInRect(tx, ty, SCR_W - 2 * CTRL_BTN_W - 12, btnY,
                    CTRL_BTN_W, CTRL_BTN_H)) {
      if (!isLocked) {
        dev.tempSet = constrain(dev.tempSet - 0.5f, 16.0f, 35.0f);
        sendTempSet(dev.tempSet);
      }
    }
    // + button
    else if (touchInRect(tx, ty, SCR_W - CTRL_BTN_W - 6, btnY,
                         CTRL_BTN_W, CTRL_BTN_H)) {
      if (!isLocked) {
        dev.tempSet = constrain(dev.tempSet + 0.5f, 16.0f, 35.0f);
        sendTempSet(dev.tempSet);
      }
    }
    needRedraw = true;
    return;
  }

  // ── Hum card tap (sets focus) ─────────────────────────────────────────────
  if (touchInRect(tx, ty, 4, CTRL_HUM_Y, SCR_W - 8, CTRL_CARD_H)) {
    editFocus = 1;

    int btnY = CTRL_HUM_Y + CTRL_BTN_Y_OFF;
    if (touchInRect(tx, ty, SCR_W - 2 * CTRL_BTN_W - 12, btnY,
                    CTRL_BTN_W, CTRL_BTN_H)) {
      if (!isLocked) {
        dev.humSet = constrain(dev.humSet - 5.0f, 30.0f, 90.0f);
        sendHumSet(dev.humSet);
      }
    } else if (touchInRect(tx, ty, SCR_W - CTRL_BTN_W - 6, btnY,
                           CTRL_BTN_W, CTRL_BTN_H)) {
      if (!isLocked) {
        dev.humSet = constrain(dev.humSet + 5.0f, 30.0f, 90.0f);
        sendHumSet(dev.humSet);
      }
    }
    needRedraw = true;
    return;
  }

  // ── Run/Stop bar tap ──────────────────────────────────────────────────────
  if (touchInRect(tx, ty, 0, 197, SCR_W, SCR_H - 197)) {
    if (!isLocked) sendToggle();
    needRedraw = true;
    return;
  }
}

// ─── Keypad (passcode entry) ──────────────────────────────────────────────────
//  Layout:  4-row numeric pad (1-9, 0, ←, ✓) centred on screen
//  Top area shows masked input (●●●●●●)
#define KP_COLS  3
#define KP_ROWS  4
#define KP_BTN_W 70
#define KP_BTN_H 38
#define KP_PAD_X ((SCR_W - KP_COLS * KP_BTN_W - (KP_COLS-1)*6) / 2)
#define KP_PAD_Y 78

const char* KP_LABELS[KP_ROWS][KP_COLS] = {
  {"1","2","3"},
  {"4","5","6"},
  {"7","8","9"},
  {"<","0","✓"}
};

void handleTouchKeypad(int tx, int ty) {
  for (int row = 0; row < KP_ROWS; row++) {
    for (int col = 0; col < KP_COLS; col++) {
      int bx = KP_PAD_X + col * (KP_BTN_W + 6);
      int by = KP_PAD_Y + row * (KP_BTN_H + 6);
      if (touchInRect(tx, ty, bx, by, KP_BTN_W, KP_BTN_H)) {
        const char* lbl = KP_LABELS[row][col];

        if (strcmp(lbl, "<") == 0) {
          // Backspace
          if (codePos > 0) {
            codePos--;
            enteredCode[codePos] = '\0';
          }
        } else if (strcmp(lbl, "\xE2\x9C\x93") == 0 || strcmp(lbl, "✓") == 0) {
          // Confirm
          if (codePos == 6) {
            if (strcmp(enteredCode, passcode) == 0) {
              isLocked = false;
              prefs.begin("eco_disp", false);
              prefs.putBool("locked", false);
              prefs.end();
              curScreen = preLockScreen;
              Serial.println("Unlocked ✓");
            } else {
              // Wrong passcode — flash screen red, reset
              tft.fillScreen(C_RED_DK);
              delay(200);
              codePos = 0;
              enteredCode[0] = '\0';
              Serial.println("Wrong passcode ✗");
            }
          }
        } else {
          // Digit
          if (codePos < 6) {
            enteredCode[codePos++] = lbl[0];
            enteredCode[codePos]   = '\0';
          }
        }
        needRedraw = true;
        return;
      }
    }
  }

  // Cancel tap (outside pad)
  if (!touchInRect(tx, ty, KP_PAD_X - 10, KP_PAD_Y - 10,
                   KP_COLS * (KP_BTN_W + 6) + 20,
                   KP_ROWS * (KP_BTN_H + 6) + 20)) {
    curScreen  = preLockScreen;
    needRedraw = true;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DRAWING HELPERS
// ═══════════════════════════════════════════════════════════════════════════

void drawCard(int x, int y, int w, int h, uint16_t bg, uint16_t border) {
  tft.fillRoundRect(x, y, w, h, CARD_RADIUS, bg);
  tft.drawRoundRect(x, y, w, h, CARD_RADIUS, border);
}

void drawRoundBtn(int x, int y, int w, int h, const char* label,
                  uint16_t bg, uint16_t fg) {
  tft.fillRoundRect(x, y, w, h, 5, bg);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(fg, bg);
  tft.setTextSize(2);
  tft.drawString(label, x + w / 2, y + h / 2);
}

void drawStatusBar(bool running, bool locked) {
  uint16_t barBg = running ? C_GREEN_DK : C_RED_DK;
  tft.fillRect(0, 197, SCR_W, SCR_H - 197, barBg);

  tft.setTextDatum(ML_DATUM);
  tft.setTextColor(C_TEXT, barBg);
  tft.setTextSize(1);
  tft.drawString(running ? "  AHU: RUNNING" : "  AHU: STOPPED", 8, 197 + (SCR_H - 197) / 2);

  if (locked) {
    tft.setTextDatum(MR_DATUM);
    tft.setTextColor(C_ORANGE, barBg);
    tft.drawString("LOCKED", SCR_W - 8, 197 + (SCR_H - 197) / 2);
  } else {
    tft.setTextDatum(MR_DATUM);
    tft.setTextColor(C_DIM, barBg);
    tft.drawString("Tap to toggle", SCR_W - 8, 197 + (SCR_H - 197) / 2);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN 1 — SCANNING
// ═══════════════════════════════════════════════════════════════════════════
void drawScanScreen() {
  tft.fillScreen(C_BG);

  // Top bar
  tft.fillRect(0, 0, SCR_W, TOPBAR_H, C_TOPBAR);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_TEXT, C_TOPBAR);
  tft.setTextSize(1);
  tft.drawString("ALMED  Scanning...", SCR_W / 2, TOPBAR_H / 2);
  tft.fillCircle(SCR_W - 22, TOPBAR_H / 2, 4, mqttOk ? C_GREEN : C_RED);
  tft.fillCircle(SCR_W - 10, TOPBAR_H / 2, 4, wifiOk ? C_GREEN : C_RED);

  // Progress bar
  unsigned long elapsed = millis() - scanStartMs;
  int barW = (int)map(min(elapsed, DISCOVERY_WAIT_MS), 0, DISCOVERY_WAIT_MS, 0, SCR_W - 20);
  tft.fillRoundRect(10, TOPBAR_H + 4, SCR_W - 20, 5, 2, C_TOPBAR);
  tft.fillRoundRect(10, TOPBAR_H + 4, barW,        5, 2, C_PRIMARY);

  // Discovered devices
  tft.setTextDatum(ML_DATUM);
  tft.setTextColor(C_DIM, C_BG);
  tft.setTextSize(1);
  tft.drawString("Found devices:", 10, TOPBAR_H + 20);

  int y = TOPBAR_H + 34;
  int found = 0;
  for (int i = 0; i < MAX_DEVICES; i++) {
    if (!devices[i].active) continue;
    drawCard(6, y, SCR_W - 12, 26, C_CARD, C_PRIMARY);
    tft.fillCircle(18, y + 13, 5, C_GREEN);
    tft.setTextColor(C_TEXT, C_CARD);
    tft.setTextDatum(ML_DATUM);
    tft.setTextSize(1);

    // Compose label: "site / room / ahu  [ip]"
    char label[64];
    snprintf(label, sizeof(label), "%s / %s / %s",
             devices[i].site, devices[i].room, devices[i].ahu);
    tft.drawString(label, 28, y + 7);

    if (strlen(devices[i].ip) > 0) {
      tft.setTextColor(C_DIM, C_CARD);
      tft.setTextDatum(MR_DATUM);
      tft.drawString(devices[i].ip, SCR_W - 10, y + 7);
    }

    y += 32;
    found++;
    if (y > SCR_H - 30) break;
  }

  if (found == 0) {
    tft.setTextDatum(MC_DATUM);
    tft.setTextColor(C_DIM, C_BG);
    tft.setTextSize(1);
    tft.drawString("Waiting for AHU devices...", SCR_W / 2, SCR_H / 2);
    tft.drawString("Make sure ESP32 AHUs are powered on", SCR_W / 2, SCR_H / 2 + 16);
  }

  // Hint
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_DIM, C_BG);
  tft.setTextSize(1);
  tft.drawString("Tap anywhere to proceed", SCR_W / 2, SCR_H - 8);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN 2 — DEVICE SELECT (touch dropdown)
// ═══════════════════════════════════════════════════════════════════════════
void drawSelectScreen() {
  tft.fillScreen(C_BG);

  // Top bar (no back button here)
  tft.fillRect(0, 0, SCR_W, TOPBAR_H, C_TOPBAR);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_TEXT, C_TOPBAR);
  tft.setTextSize(1);
  tft.drawString("Select AHU Device", SCR_W / 2, TOPBAR_H / 2);
  tft.fillCircle(SCR_W - 22, TOPBAR_H / 2, 4, mqttOk ? C_GREEN : C_RED);
  tft.fillCircle(SCR_W - 10, TOPBAR_H / 2, 4, wifiOk ? C_GREEN : C_RED);

  // Build active index list
  int map_arr[MAX_DEVICES];
  int count = 0;
  for (int i = 0; i < MAX_DEVICES; i++) {
    if (devices[i].active) map_arr[count++] = i;
  }

  if (count == 0) {
    tft.setTextDatum(MC_DATUM);
    tft.setTextColor(C_DIM, C_BG);
    tft.setTextSize(1);
    tft.drawString("No AHU devices found.", SCR_W / 2, 120);
    tft.drawString("Make sure ESP32 AHUs are online.", SCR_W / 2, 138);
    tft.setTextColor(C_PRIMARY, C_BG);
    tft.drawString("Scanning...", SCR_W / 2, 165);
    return;
  }

  // Scroll up indicator
  if (listScroll > 0) {
    tft.setTextDatum(MC_DATUM);
    tft.setTextColor(C_PRIMARY, C_BG);
    tft.drawString("^", SCR_W / 2, TOPBAR_H + 6);
  }

  // Device rows
  for (int row = 0; row < LIST_ROWS; row++) {
    int visIdx = listScroll + row;
    if (visIdx >= count) break;

    int devIdx = map_arr[visIdx];
    AhuDevice& dev = devices[devIdx];

    int ry = LIST_Y_START + row * LIST_ROW_H;

    bool isSelected = (devIdx == selectedIdx);

    uint16_t bg     = C_CARD;
    uint16_t border = isSelected ? C_GREEN : C_BORDER;
    drawCard(4, ry, SCR_W - 8, LIST_ROW_H - 4, bg, border);

    // Online dot
    tft.fillCircle(16, ry + 14, 5, dev.run ? C_GREEN : C_RED);

    // Main label: site / room / ahu
    char mainLabel[64];
    if (strlen(dev.thingName) > 0) {
      snprintf(mainLabel, sizeof(mainLabel), "%s", dev.thingName);
    } else {
      snprintf(mainLabel, sizeof(mainLabel), "%s/%s/%s",
               dev.site, dev.room, dev.ahu);
    }
    tft.setTextDatum(ML_DATUM);
    tft.setTextColor(C_TEXT, bg);
    tft.setTextSize(1);
    tft.drawString(mainLabel, 28, ry + 7);

    // Sub-label: site/room/ahu + ip
    char subLabel[64];
    snprintf(subLabel, sizeof(subLabel), "%s / %s / %s",
             dev.site, dev.room, dev.ahu);
    tft.setTextColor(C_DIM, bg);
    tft.drawString(subLabel, 28, ry + 22);

    // IP on right
    if (strlen(dev.ip) > 0) {
      tft.setTextDatum(MR_DATUM);
      tft.setTextColor(C_DIM, bg);
      tft.drawString(dev.ip, SCR_W - 10, ry + 14);
    }

    // ACTIVE badge
    if (isSelected) {
      tft.setTextDatum(MR_DATUM);
      tft.setTextColor(C_GREEN, bg);
      tft.drawString("ACTIVE >", SCR_W - 10, ry + 7);
    }
  }

  // Scroll down indicator
  if (listScroll + LIST_ROWS < count) {
    tft.setTextDatum(MC_DATUM);
    tft.setTextColor(C_PRIMARY, C_BG);
    tft.drawString("v", SCR_W / 2, SCR_H - BOTBAR_H - 4);
  }

  // Bottom hint
  tft.fillRect(0, SCR_H - BOTBAR_H, SCR_W, BOTBAR_H, C_TOPBAR);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_DIM, C_TOPBAR);
  tft.setTextSize(1);
  tft.drawString("Tap a device to open control", SCR_W / 2, SCR_H - BOTBAR_H / 2);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN 3 — CONTROL
// ═══════════════════════════════════════════════════════════════════════════
void drawControlScreen() {
  if (selectedIdx < 0) { curScreen = SCR_SELECT; return; }
  AhuDevice& dev = devices[selectedIdx];

  tft.fillScreen(C_BG);

  // ── Top bar ──────────────────────────────────────────────────────────────
  tft.fillRect(0, 0, SCR_W, TOPBAR_H, C_TOPBAR);

  // Back
  tft.setTextDatum(ML_DATUM);
  tft.setTextColor(C_PRIMARY, C_TOPBAR);
  tft.setTextSize(1);
  tft.drawString("< Back", 6, TOPBAR_H / 2);

  // Device name (centre, truncated)
  char title[32];
  if (strlen(dev.thingName) > 0) {
    snprintf(title, sizeof(title), "%s", dev.thingName);
  } else {
    snprintf(title, sizeof(title), "%s/%s", dev.room, dev.ahu);
  }
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_TEXT, C_TOPBAR);
  tft.drawString(title, SCR_W / 2, TOPBAR_H / 2);

  // Lock icon (right)
  tft.setTextDatum(MR_DATUM);
  tft.setTextColor(isLocked ? C_ORANGE : C_DIM, C_TOPBAR);
  tft.drawString(isLocked ? "LOCK" : "OPEN", SCR_W - 6, TOPBAR_H / 2);

  // Status dots
  tft.fillCircle(SCR_W - 50, TOPBAR_H / 2, 4, mqttOk ? C_GREEN : C_RED);

  // ── Temperature card ─────────────────────────────────────────────────────
  bool tempFocus = (editFocus == 0);
  uint16_t tempBorder = tempFocus ? C_PRIMARY : C_BORDER;
  drawCard(4, CTRL_TEMP_Y, SCR_W - 8, CTRL_CARD_H, C_CARD, tempBorder);

  if (tempFocus) tft.fillRect(4, CTRL_TEMP_Y, 3, CTRL_CARD_H, C_PRIMARY);

  tft.setTextDatum(ML_DATUM);
  tft.setTextColor(C_DIM, C_CARD);
  tft.setTextSize(1);
  tft.drawString("TEMPERATURE", 14, CTRL_TEMP_Y + 8);

  // Big reading
  tft.setTextDatum(ML_DATUM);
  tft.setTextSize(4);
  if (!isnan(dev.temp)) {
    tft.setTextColor(C_TEXT, C_CARD);
    char tb[10]; dtostrf(dev.temp, 4, 1, tb);
    tft.drawString(tb, 14, CTRL_TEMP_Y + 22);
    tft.setTextSize(2);
    tft.setTextColor(C_DIM, C_CARD);
    tft.drawString("C", 14 + tft.textWidth(tb, 4) + 2, CTRL_TEMP_Y + 30);
  } else {
    tft.setTextColor(C_DIM, C_CARD);
    tft.drawString("---", 14, CTRL_TEMP_Y + 22);
  }

  // Setpoint label
  tft.setTextSize(1);
  tft.setTextColor(C_DIM, C_CARD);
  tft.setTextDatum(ML_DATUM);
  tft.drawString("SET:", 14, CTRL_TEMP_Y + CTRL_CARD_H - 14);
  tft.setTextColor(C_YELLOW, C_CARD);
  char tsb[8]; dtostrf(dev.tempSet, 4, 1, tsb);
  tft.drawString(tsb, 40, CTRL_TEMP_Y + CTRL_CARD_H - 14);
  tft.setTextColor(C_DIM, C_CARD);
  tft.drawString("C", 40 + tft.textWidth(tsb, 1) + 2, CTRL_TEMP_Y + CTRL_CARD_H - 14);

  // – / + buttons
  int btnY = CTRL_TEMP_Y + CTRL_BTN_Y_OFF;
  uint16_t btnBg = isLocked ? C_BORDER : C_PRIMARY;
  drawRoundBtn(SCR_W - 2 * CTRL_BTN_W - 12, btnY, CTRL_BTN_W, CTRL_BTN_H, "-", btnBg, C_TEXT);
  drawRoundBtn(SCR_W - CTRL_BTN_W - 6,      btnY, CTRL_BTN_W, CTRL_BTN_H, "+", btnBg, C_TEXT);

  // ── Humidity card ─────────────────────────────────────────────────────────
  bool humFocus  = (editFocus == 1);
  uint16_t humBorder  = humFocus ? C_PRIMARY : C_BORDER;
  drawCard(4, CTRL_HUM_Y, SCR_W - 8, CTRL_CARD_H, C_CARD, humBorder);

  if (humFocus) tft.fillRect(4, CTRL_HUM_Y, 3, CTRL_CARD_H, C_PRIMARY);

  tft.setTextDatum(ML_DATUM);
  tft.setTextColor(C_DIM, C_CARD);
  tft.setTextSize(1);
  tft.drawString("HUMIDITY", 14, CTRL_HUM_Y + 8);

  tft.setTextSize(4);
  if (!isnan(dev.hum)) {
    tft.setTextColor(C_TEXT, C_CARD);
    char hb[10]; dtostrf(dev.hum, 4, 1, hb);
    tft.drawString(hb, 14, CTRL_HUM_Y + 22);
    tft.setTextSize(2);
    tft.setTextColor(C_DIM, C_CARD);
    tft.drawString("%", 14 + tft.textWidth(hb, 4) + 2, CTRL_HUM_Y + 30);
  } else {
    tft.setTextColor(C_DIM, C_CARD);
    tft.drawString("---", 14, CTRL_HUM_Y + 22);
  }

  tft.setTextSize(1);
  tft.setTextColor(C_DIM, C_CARD);
  tft.setTextDatum(ML_DATUM);
  tft.drawString("SET:", 14, CTRL_HUM_Y + CTRL_CARD_H - 14);
  tft.setTextColor(C_YELLOW, C_CARD);
  char hsb[8]; dtostrf(dev.humSet, 4, 1, hsb);
  tft.drawString(hsb, 40, CTRL_HUM_Y + CTRL_CARD_H - 14);
  tft.setTextColor(C_DIM, C_CARD);
  tft.drawString("%", 40 + tft.textWidth(hsb, 1) + 2, CTRL_HUM_Y + CTRL_CARD_H - 14);

  int btnY2 = CTRL_HUM_Y + CTRL_BTN_Y_OFF;
  drawRoundBtn(SCR_W - 2 * CTRL_BTN_W - 12, btnY2, CTRL_BTN_W, CTRL_BTN_H, "-", btnBg, C_TEXT);
  drawRoundBtn(SCR_W - CTRL_BTN_W - 6,      btnY2, CTRL_BTN_W, CTRL_BTN_H, "+", btnBg, C_TEXT);

  // ── Status / toggle bar ───────────────────────────────────────────────────
  drawStatusBar(dev.run, isLocked);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN 4 — PASSCODE KEYPAD
// ═══════════════════════════════════════════════════════════════════════════
void drawKeypadScreen() {
  tft.fillScreen(C_BG);

  // Header
  tft.fillRect(0, 0, SCR_W, TOPBAR_H, C_TOPBAR);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_ORANGE, C_TOPBAR);
  tft.setTextSize(1);
  tft.drawString("Enter Passcode to Unlock", SCR_W / 2, TOPBAR_H / 2);

  // Masked code display
  // Draw 6 circles (filled = entered, empty = pending)
  int dotSpacing = 22;
  int dotStartX  = (SCR_W - 6 * dotSpacing) / 2 + dotSpacing / 2;
  int dotY       = TOPBAR_H + 20;
  for (int i = 0; i < 6; i++) {
    uint16_t c = (i < codePos) ? C_PRIMARY : C_BORDER;
    tft.fillCircle(dotStartX + i * dotSpacing, dotY, 7, c);
    tft.drawCircle(dotStartX + i * dotSpacing, dotY, 7, C_DIM);
  }

  // Keypad buttons
  for (int row = 0; row < KP_ROWS; row++) {
    for (int col = 0; col < KP_COLS; col++) {
      int bx = KP_PAD_X + col * (KP_BTN_W + 6);
      int by = KP_PAD_Y + row * (KP_BTN_H + 6);
      const char* lbl = KP_LABELS[row][col];

      uint16_t bg = C_CARD;
      if (strcmp(lbl, "\xE2\x9C\x93") == 0 || strcmp(lbl, "✓") == 0)  bg = C_GREEN_DK;
      if (strcmp(lbl, "<") == 0)             bg = C_RED_DK;

      tft.fillRoundRect(bx, by, KP_BTN_W, KP_BTN_H, 5, bg);
      tft.drawRoundRect(bx, by, KP_BTN_W, KP_BTN_H, 5, C_BORDER);

      tft.setTextDatum(MC_DATUM);
      tft.setTextColor(C_TEXT, bg);
      tft.setTextSize(2);
      tft.drawString(lbl, bx + KP_BTN_W / 2, by + KP_BTN_H / 2);
    }
  }

  // Cancel hint
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_DIM, C_BG);
  tft.setTextSize(1);
  tft.drawString("Tap outside keys to cancel", SCR_W / 2, SCR_H - 6);
}

