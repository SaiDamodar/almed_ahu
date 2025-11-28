#include <pgmspace.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include "WiFi.h"
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <ArduinoJson.h>

// ========== NEW SENSOR LIBRARIES (SEN66 + SDP810 Combo) ==========
#include <SensirionI2cSen66.h>
#include <SensirionI2CSdp.h>
#include <Preferences.h>
#include <esp_task_wdt.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include <HTTPClient.h>
#include <Update.h>

#define AWS_IOT_SUBSCRIBE_TOPIC "esp32/sub" // MQTT topic to subscribe to for commands
#define AWS_IOT_PUBLISH_TOPIC "esp32/pub"   // MQTT topic to publish telemetry/state

#define THINGNAME "AHU_ESP2" // Unique identifier for your device, change this

// ============ GitHub OTA Configuration (Hardcoded) ============
#define GITHUB_REPO_OWNER "ESPUpdaterzaid"
#define GITHUB_REPO_NAME "almed-esp32-firmware"
#define GITHUB_REPO_BRANCH "main"
#define GITHUB_FIRMWARE_PATH "firmware/esp32_main.ino"
// For GitHub Releases, specify the asset name (compiled .bin file)
// If using direct file download, this is the path to the .ino file
#define GITHUB_FIRMWARE_ASSET_NAME "esp32_main.ino.bin"  // Name of the .bin file in GitHub Releases
// GitHub token - set this if you want to use private repos
#define GITHUB_TOKEN "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"  // Your GitHub token for private repo access

const char WIFI_SSID[] = "ez"; // Your WiFi SSID
const char WIFI_PASSWORD[] = "12345678"; // Your WiFi password
const char AWS_IOT_ENDPOINT[] = "al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com"; // Your AWS IoT endpoint, change this

// ============ DEFAULT WiFi ============
#define DEFAULT_W1_SSID "PiSpot"
#define DEFAULT_W1_PASS "12345678"

// ========================= DEFAULT MOTOR TIMINGS (Adjustable via Admin) =========================
unsigned long M1_START_RUN = 10UL * 1000UL;
unsigned long M1_POST_RUN  = 10UL * 1000UL;
unsigned long M2_INTERVAL  = 30UL * 1000UL;
unsigned long M2_RUN_TIME  = 10UL * 1000UL;
unsigned long M2_DELAY_AFTER_M1_STOP = 5UL * 1000UL;

// ========================= WATCHDOG CONFIGURATION =========================
const unsigned long WDT_TIMEOUT = 7;
const unsigned long LOOP_TIMEOUT_MS = 5000;
const unsigned long WIFI_FAIL_RESET_MS = 15000;

// Amazon Root CA 1, necessary for secure communication
static const char AWS_CERT_CA[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
MIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsF
ADA5MQswCQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6
b24gUm9vdCBDQSAxMB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTEL
MAkGA1UEBhMCVVMxDzANBgNVBAoTBkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJv
b3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJ4gHHKeNXj
ca9HgFB0fW7Y14h29Jlo91ghYPl0hAEvrAIthtOgQ3pOsqTQNroBvo3bSMgHFzZM
9O6II8c+6zf1tRn4SWiw3te5djgdYZ6k/oI2peVKVuRF4fn9tBb6dNqcmzU5L/qw
IFAGbHrQgLKm+a/sRxmPUDgH3KKHOVj4utWp+UhnMJbulHheb4mjUcAwhmahRWa6
VOujw5H5SNz/0egwLX0tdHA114gk957EWW67c4cX8jJGKLhD+rcdqsq08p8kDi1L
93FcXmn/6pUCyziKrlA4b9v7LWIbxcceVOF34GfID5yHI9Y/QCB/IIDEgEw+OyQm
jgSubJrIqg0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC
AYYwHQYDVR0OBBYEFIQYzIU07LwMlJQuCFmcx7IQTgoIMA0GCSqGSIb3DQEBCwUA
A4IBAQCY8jdaQZChGsV2USggNiMOruYou6r4lK5IpDB/G/wkjUu0yKGX9rbxenDI
U5PMCCjjmCXPI6T53iHTfIUJrU6adTrCC2qJeHZERxhlbI1Bjjt/msv0tadQ1wUs
N+gDS63pYaACbvXy8MWy7Vu33PqUXHeeE6V/Uq2V8viTO96LXFvKWlJbYK8U90vv
o/ufQJVtMVT8QtPHRh8jrdkPSHCa2XV4cdFyQzR1bldZwgJcJmApzyMZFo6IQ6XU
5MsI+yMRQ+hDKXJioaldXgjUkK642M4UwtBV8ob2xJNDd2ZhwLnoQdeXeGADbkpy
rqXRfboQnoZsG4q5WTP468SQvvG5
-----END CERTIFICATE-----
)EOF";

static const char AWS_CERT_CRT[] PROGMEM = R"KEY(
-----BEGIN CERTIFICATE-----
MIIDWTCCAkGgAwIBAgIUXOzilRCb264lti1+7sI3sD5G1HgwDQYJKoZIhvcNAQEL
BQAwTTFLMEkGA1UECwxCQW1hem9uIFdlYiBTZXJ2aWNlcyBPPUFtYXpvbi5jb20g
SW5jLiBMPVNlYXR0bGUgU1Q9V2FzaGluZ3RvbiBDPVVTMB4XDTI1MTExMDA3MTUx
MloXDTQ5MTIzMTIzNTk1OVowHjEcMBoGA1UEAwwTQVdTIElvVCBDZXJ0aWZpY2F0
ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANT18Bh97ffPkFW6E5UX
Md90r6JWXUMo+hM5ROVoW/1c/wYiHkqtWGUho6HIPIyJ8ygAJZg5eyQtky9a+FE0
zH+hynP0Ll2OhXdKatoBfyyIx+4bm5LEJdywgVKTD0zc+JaI/4UuX8ulqRuyxvWK
mC5E4NnEhQDr1/lSF9cEoM0qoibsQEYN4wCC+uv4KCfKecWbTFnLAymO3xkNktRj
Ye4OmMn3Fn5EkXEj3wj5P5weyzNKWmsvS9zJyBSCirQlpNrtyzbKYb/zZb0+Hu8y
b7gDe7IRFdAs1cWG5Go9XT1Sw02MB3V33vbixqdOk72+Wb+HAvtd9UVotvrT+z4F
cYUCAwEAAaNgMF4wHwYDVR0jBBgwFoAUXrVaCx2/8xlSN3wyWD5M6PrX68AwHQYD
VR0OBBYEFFK2zn4bWr5tFbZKiuw+KObMYa3ZMAwGA1UdEwEB/wQCMAAwDgYDVR0P
AQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IBAQCot/qJ/RCOKgrxqn5fx4Jsj3pE
ATjhdzurlkb+pgFhPtwXmAqP56eGRlANh4DrrMHwDAj4q4D/saGUtV6XVIyWsb1r
A6DUth8ytpe4knDIr9i0ExqBkhthM2LVQsu6IS4yCjxIgseMmOhBnGP1h97eoFqu
HCMhyGClnJ8hfg0jCYwNKWaIzvAadDdu2bK9IAK5eB0IYeAoIhgNkIxiI6fio/5l
an7D5Un6/hPXZPXgO98mQXszwGv1d2FG3nbSHWaIA61siSuYx1rX1K/wSOCCv4au
l9aPPczam3kajFLLq1bnT4oVADSnVGsuP7JKYYOkvQeYJlWF38pL/zXCi2KG
-----END CERTIFICATE-----
)KEY";

static const char AWS_CERT_PRIVATE[] PROGMEM = R"KEY(
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA1PXwGH3t98+QVboTlRcx33SvolZdQyj6EzlE5Whb/Vz/BiIe
Sq1YZSGjocg8jInzKAAlmDl7JC2TL1r4UTTMf6HKc/QuXY6Fd0pq2gF/LIjH7hub
ksQl3LCBUpMPTNz4loj/hS5fy6WpG7LG9YqYLkTg2cSFAOvX+VIX1wSgzSqiJuxA
Rg3jAIL66/goJ8p5xZtMWcsDKY7fGQ2S1GNh7g6YyfcWfkSRcSPfCPk/nB7LM0pa
ay9L3MnIFIKKtCWk2u3LNsphv/NlvT4e7zJvuAN7shEV0CzVxYbkaj1dPVLDTYwH
dXfe9uLGp06Tvb5Zv4cC+131RWi2+tP7PgVxhQIDAQABAoIBAFAIAOvjX2vSuEZP
QI62AcsdOegDFtdnbduNmSOxfWiQ61Itvj6IOIEBDFJ/Qqn6KcQtkfNMHsfwzLBu
OoWiFvwcHE5JRKdqKSQ0dkVpbJaa7K/B9kxIpIX0WxViKMzU+iLwZz5wuBV7Mzsy
i2y5Ygl5XxrXrLg06ZxLyqPGnHudS0X8WToIjnL9k5TFOAbH0jSQNT3v4HonvPQo
OSRw5gQkMspzD5inJQPXpMvgtW3RF6JRXTxrAjRZgxjWlt/PTPO6yD5xb5M8NlaE
v2Ru1QMuVoQYBIgB4ldyWa834sbwfc8K8K1EPPX+VAXikBH+zpgiy29LGCJRAwtc
7HTkL/0CgYEA9knqMiNXR9Swore6TW1182HshQikUgoCZtaVnFe1eGTRCVNw7owe
H5wKuE35pJk4uT3GtJ68sm3wAbGXXlHCQE8rqwkdC9bCYULnt90vZy7GMTIE45HZ
1mO+x/1fqzPtwbrUxtoJ+V7ZKPETPwBrwsj8ziTmAiWoCv5kaEyQQB8CgYEA3Vua
gWdj74Z1keYhgurPf95CATjL0i/gNxFn6TeRSsjHPkxF4KTxwnidHtX3Xr1wXGim
wPC17UTxqqvzsHMUYM2+Z6L1cLiZvncKqR+63IbVryymJj+L4bacxAF/c2nEaucj
+ql+W+YbFAcCgZBrtNuFa0rWSztZDDuiGjHyidsCgYB83wUK3rhGByR3m8etsi33
dFLDMJp/reuB0JKSbjXoENWbcN71U72CMU+OGprURYtpAFVbBpCNtwfVFAG3JKTk
jj+JvFkpw31SauWpZ0+9dQ2vq7im2TAlbvUv2NtEplOJwfxXxf0AnoJkK7aiXshE
PjtPGY400Hre+BRYfVk16QKBgDz/3VgDsdpz5zpJfLqjEoNeMDo9+Iz3fIYwWb4+
/d7p7V4RjsAVNDovGr1AoWaONcSBYlKRAtFbym0J7aGWVOtIR0wv8AscE+IU0+8/
OzNCROh9GVw47sdIl3K8Ju8bGnGLOLL+uj+A7b1bISmrLsMsK1whx2P7+tIQLN+j
G/85AoGAWMaF0/o55an3Nz5z5O4ZZDkHbUKWHB9t2bkzY0/fUJwitRE5sAb3ObNd
iCgc/U13OUqN5j16arDYakNNtoM/gvBV7fRqXoHqCpAQEAuq/NZjJnTKO1O5BBmp
WcX63pf6TfPPd7gCgSaH74iCe0kuyNLeJUCz0VWAR9kb9uw02iQ=
-----END RSA PRIVATE KEY-----
)KEY";

// ========== AWS IoT MQTT (Cloud) ==========
WiFiClientSecure net = WiFiClientSecure();
PubSubClient client(net);

// ========== Local MQTT Broker (Raspberry Pi) ==========
WiFiClient espNet;
PubSubClient mqttLocal(espNet);

const char* MQTT_USER = "almed";
const char* MQTT_PASS = "Almed1234$";
const uint16_t MQTT_PORT = 1883;
String mqttHost = "10.42.0.1";
unsigned long lastMqttAttempt = 0;

// MQTT buffer size for large messages (increased for combo sensor data)
const int MQTT_BUFFER_SIZE = 1024;

// ---------- SHT45 ----------
Adafruit_SHT4x sht4;
float filtTempC = NAN, filtHum = NAN;
unsigned long lastSensorAt = 0;
const unsigned long SENSOR_PERIOD = 2000;

const float TEMP_JUMP_MAX = 12.0;
const float HUM_JUMP_MAX  = 18.0;
const float TEMP_FAIL_THRESHOLD = 5.0;
const float HUM_FAIL_THRESHOLD = 10.0;

// ---------- SEN66 + SDP810 Combo Sensors ----------
SensirionI2cSen66 sen66;
SensirionI2CSdp sdp810;

// Sensor detection flags
bool useSHT45 = false;      // Original sensor
bool useSEN66 = false;      // New combo: air quality sensor
bool useSDP810 = false;     // New combo: differential pressure sensor

// SEN66 readings
float sen66_pm1p0 = 0.0, sen66_pm2p5 = 0.0, sen66_pm4p0 = 0.0, sen66_pm10p0 = 0.0;
float sen66_humidity = 0.0, sen66_temperature = 0.0;
float sen66_vocIndex = 0.0, sen66_noxIndex = 0.0;
uint16_t sen66_co2 = 0;
int sen66_aqi = 0;

// SDP810 readings
float sdp810_pressure = 0.0;
float sdp810_temperature = 0.0;
String hepaStatus = "Unknown";
int hepaHealthPercent = 0;

// HEPA Filter Thresholds (Pa)
#define HEPA_MIN_NORMAL     9.0
#define HEPA_MAX_NORMAL     25.0
#define HEPA_REPLACE        40.0

// ---------- 5-Channel Relay Module (Active LOW: LOW=ON, HIGH=OFF) ----------
#define PIN_MOTOR1  32   // Relay IN1 - Motor 1 (12V DC)
#define PIN_MOTOR2  33   // Relay IN2 - Motor 2 (12V DC)
#define PIN_HEAT    19   // Relay IN3 - Heater (220V AC)
#define PIN_CP      23   // Relay IN4 - CP Compressor (220V AC)
#define PIN_SYSTEM  18   // Relay IN5 - System Master (220V AC)

bool runState = false, m1Active = false, m2Active = false, shuttingDown = false;
unsigned long m1StopAt = 0, m2StopAt = 0, m2NextAt = 0;
bool m2ScheduledAfterM1 = false;
unsigned long m2StartAt = 0;
unsigned long m2LastRunTime = 0; // Track when Motor 2 last ran (for accurate timing across resets)
bool shutdownM2Pending = false;
bool shutdownStarted = false;

// ---------- Temperature & Humidity Control ----------
bool   cpOn = false;
float  tempSet = 22.0;
const float TEMP_DEADBAND = 1.0;
const unsigned long CP_MIN_OFF_MS = 5000;
const unsigned long CP_MIN_ON_MS  = 3000;
unsigned long cpLastOnAt  = 0, cpLastOffAt = 0;

bool   heatOn = false;
float  humSet = 55.0;
const float HUM_DEADBAND = 3.0;
const unsigned long HEAT_MIN_OFF_MS = 5000;
const unsigned long HEAT_MIN_ON_MS  = 3000;
unsigned long heatLastOnAt  = 0, heatLastOffAt = 0;

// ---------- PWM Fan Control (D2 -> 0-10V Converter) ----------
#define PIN_FAN_PWM 2
enum FanSpeed { FAN_OFF = 0, FAN_LOW = 1, FAN_MED = 2, FAN_HIGH = 3 };
FanSpeed fanSpeed = FAN_OFF;

const int FAN_PWM_OFF  = 0;    // 0% = 0V
const int FAN_PWM_LOW  = 128;  // 50% = 5V
const int FAN_PWM_MED  = 179;  // 70% = 7V
const int FAN_PWM_HIGH = 230;  // 90% = 9V

const int FAN_PWM_FREQ = 25000;
const int FAN_PWM_RESOLUTION = 8;

// ---------- Ring buffers for logs ----------
const int LOG_MAX = 10;
String tempBuf[LOG_MAX]; int tempHead = -1; int tempCount = 0;
String motorBuf[LOG_MAX]; int motorHead = -1; int motorCount = 0;

void pushTempHTML(const String& line)  { tempHead  = (tempHead  + 1) % LOG_MAX; tempBuf[tempHead]  = line; if (tempCount  < LOG_MAX) tempCount++; }
void pushMotorHTML(const String& line) { motorHead = (motorHead + 1) % LOG_MAX; motorBuf[motorHead] = line; if (motorCount < LOG_MAX) motorCount++; }

// ---------- Local MQTT Topics (for Raspberry Pi) ----------
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
String tProvMotorTimings(){ return baseTopic()+"/provision/motor_timings"; }
String tProvAck()         { return baseTopic()+"/provision/ack"; }
String tProvWifi()        { return baseTopic()+"/provision/wifi"; }
String tProvBroker()      { return baseTopic()+"/provision/broker"; }

// ---------- Preferences ----------
Preferences prefs;
String w1_ssid, w1_pass, w2_ssid, w2_pass;

// ---------- Watchdog & State Recovery ----------
unsigned long lastLoopTime = 0;
unsigned long wifiFailStartTime = 0;
bool wifiWasFailing = false;
int consecutiveWifiFailures = 0;
bool wifiAssociationRefused = false;
bool pendingRecoveryStart = false;

// ---------- State Persistence ----------
void saveSystemState(){
  unsigned long now = millis();
  prefs.putBool("runState", runState);
  prefs.putBool("cpOn", cpOn);
  prefs.putBool("heatOn", heatOn);
  prefs.putBool("shuttingDown", shuttingDown);
  prefs.putInt("fanSpeed", (int)fanSpeed);
  prefs.putULong("saveTime", now);
  
  // Save motor timing state (time remaining until next M2 run)
  // CRITICAL: Save when Motor 2 last ran (relative to saveTime) for accurate timing across resets
  if (runState && !shuttingDown) {
    if (m2ScheduledAfterM1 && m2StartAt > now) {
      // M2 is scheduled after M1, save time remaining until m2StartAt
      unsigned long remaining = m2StartAt - now;
      prefs.putULong("m2StartAtRemaining", remaining);
      prefs.putBool("m2ScheduledAfterM1", true);
      prefs.putULong("m2NextAtRemaining", 0); // Not set yet
      // Save last run time if available
      if (m2LastRunTime > 0 && m2LastRunTime <= now) {
        prefs.putULong("m2LastRunTime", now - m2LastRunTime); // Elapsed since last run
      } else {
        prefs.putULong("m2LastRunTime", 0);
      }
    } else if (m2NextAt > now) {
      // M2 has a scheduled next run time
      unsigned long remaining = m2NextAt - now;
      prefs.putULong("m2NextAtRemaining", remaining);
      prefs.putBool("m2ScheduledAfterM1", false);
      prefs.putULong("m2StartAtRemaining", 0);
      // CRITICAL: Save when Motor 2 last ran (relative to saveTime)
      // This allows us to calculate elapsed time even across reboots
      if (m2LastRunTime > 0 && m2LastRunTime <= now) {
        prefs.putULong("m2LastRunTime", now - m2LastRunTime); // Elapsed since last run
      } else {
        prefs.putULong("m2LastRunTime", 0);
      }
    } else {
      // M2 can run immediately (time has passed) - save that it's due
      prefs.putULong("m2NextAtRemaining", 0);
      prefs.putULong("m2StartAtRemaining", 0);
      prefs.putBool("m2ScheduledAfterM1", false);
      // Save last run time if available
      if (m2LastRunTime > 0 && m2LastRunTime <= now) {
        prefs.putULong("m2LastRunTime", now - m2LastRunTime);
      } else {
        prefs.putULong("m2LastRunTime", 0);
      }
    }
  } else {
    // System not running, clear motor timing
    prefs.putULong("m2NextAtRemaining", 0);
    prefs.putULong("m2StartAtRemaining", 0);
    prefs.putBool("m2ScheduledAfterM1", false);
    prefs.putULong("m2LastRunTime", 0);
  }
}

void restoreSystemState(){
  unsigned long saveTime = prefs.getULong("saveTime", 0);
  unsigned long now = millis();
  if (saveTime == 0 || now < 300000) {
    bool wasRunning = prefs.getBool("runState", false);
    bool wasCpOn = prefs.getBool("cpOn", false);
    bool wasHeatOn = prefs.getBool("heatOn", false);
    bool wasShuttingDown = prefs.getBool("shuttingDown", false);
    int savedFanSpd = prefs.getInt("fanSpeed", 0);
    
    if (wasRunning && !wasShuttingDown) {
      pendingRecoveryStart = true;
      runState = false;
      cpOn = wasCpOn;
      heatOn = wasHeatOn;
      cpWrite(cpOn);
      heatWrite(heatOn);
      
      if (savedFanSpd >= 0 && savedFanSpd <= 3) {
        setFanSpeed((FanSpeed)savedFanSpd);
      }
      
      // Restore motor timing state
      // CRITICAL FIX: Use m2LastRunTime to calculate accurate remaining time even across reboots
      bool rebootDetected = (saveTime > 0 && saveTime > now);
      unsigned long elapsedSinceSave = 0;
      if (!rebootDetected && saveTime > 0 && now > saveTime) {
        // Normal case: calculate exact elapsed time since save
        elapsedSinceSave = now - saveTime;
      }
      // Note: On reboot, we can't know elapsedSinceSave, but we'll use m2LastRunTime instead
      
      bool savedM2ScheduledAfterM1 = prefs.getBool("m2ScheduledAfterM1", false);
      unsigned long savedM2StartAtRemaining = prefs.getULong("m2StartAtRemaining", 0);
      unsigned long savedM2NextAtRemaining = prefs.getULong("m2NextAtRemaining", 0);
      unsigned long savedM2LastRunElapsed = prefs.getULong("m2LastRunTime", 0); // Elapsed since Motor 2 last ran (at save time)
      
      if (savedM2ScheduledAfterM1 && savedM2StartAtRemaining > 0) {
        // M2 was scheduled after M1
        if (rebootDetected) {
          // Reboot: Use saved remaining time directly
          if (savedM2StartAtRemaining > 0 && savedM2StartAtRemaining < M2_INTERVAL) {
            m2StartAt = now + savedM2StartAtRemaining;
            m2ScheduledAfterM1 = true;
            m2NextAt = 0;
          } else {
            m2NextAt = now + M2_INTERVAL;
            m2ScheduledAfterM1 = false;
            m2StartAt = 0;
          }
        } else if (elapsedSinceSave >= savedM2StartAtRemaining) {
          m2NextAt = now + M2_INTERVAL;
          m2ScheduledAfterM1 = false;
          m2StartAt = 0;
        } else {
          m2StartAt = now + (savedM2StartAtRemaining - elapsedSinceSave);
          m2ScheduledAfterM1 = true;
          m2NextAt = 0;
        }
      } else if (savedM2NextAtRemaining > 0 || savedM2LastRunElapsed > 0) {
        // M2 had a scheduled next run time OR we have last run time info
        if (rebootDetected) {
          // CRITICAL: On reboot, we save every 2 seconds when M2 is waiting
          // So savedM2NextAtRemaining should be recent (within 2 seconds)
          // Use it directly, but subtract a small safety margin (2 seconds) to account for time since last save
          if (savedM2NextAtRemaining > 0 && savedM2NextAtRemaining <= M2_INTERVAL) {
            // Subtract 2 seconds as safety margin (worst case: save happened 2 seconds ago)
            unsigned long remaining = (savedM2NextAtRemaining > 2000) ? (savedM2NextAtRemaining - 2000) : 0;
            m2NextAt = now + remaining;
          } else if (savedM2LastRunElapsed > 0 && savedM2LastRunElapsed < M2_INTERVAL) {
            // Fallback: Calculate from last run time
            // remaining = M2_INTERVAL - savedM2LastRunElapsed - 2 seconds safety margin
            unsigned long remaining = (savedM2LastRunElapsed + 2000 < M2_INTERVAL) ? (M2_INTERVAL - savedM2LastRunElapsed - 2000) : 0;
            m2NextAt = now + remaining;
          } else {
            // Invalid data, wait for normal interval
            m2NextAt = now + M2_INTERVAL;
          }
          m2ScheduledAfterM1 = false;
          m2StartAt = 0;
        } else {
          // No reboot: Calculate accurately using elapsed time since save
          if (elapsedSinceSave >= savedM2NextAtRemaining) {
            // Time has passed, wait for next interval
            m2NextAt = now + M2_INTERVAL;
          } else {
            // Still waiting - calculate accurate remaining time
            m2NextAt = now + (savedM2NextAtRemaining - elapsedSinceSave);
          }
          m2ScheduledAfterM1 = false;
          m2StartAt = 0;
        }
      } else {
        // No motor timing saved
        m2NextAt = now + M2_INTERVAL;
        m2ScheduledAfterM1 = false;
        m2StartAt = 0;
      }
      
      // Restore m2LastRunTime for future saves
      if (savedM2LastRunElapsed > 0) {
        // Calculate when Motor 2 last ran: now - (saved elapsed + time since save)
        if (rebootDetected) {
          // Can't know exact time, but we know it was at least savedM2LastRunElapsed ago
          m2LastRunTime = (now >= savedM2LastRunElapsed) ? (now - savedM2LastRunElapsed) : 0;
        } else {
          m2LastRunTime = (now >= (savedM2LastRunElapsed + elapsedSinceSave)) ? (now - savedM2LastRunElapsed - elapsedSinceSave) : 0;
        }
      }
      
      Serial.println("⚠️ WATCHDOG RECOVERY: State restored, waiting for WiFi");
      Serial.print("  CP: "); Serial.print(cpOn ? "ON" : "OFF");
      Serial.print(" | Heater: "); Serial.print(heatOn ? "ON" : "OFF");
      Serial.print(" | Fan: "); Serial.println(savedFanSpd);
      Serial.print("  [DEBUG] savedM2NextAtRemaining: "); Serial.print(savedM2NextAtRemaining / 1000); Serial.println("s");
      Serial.print("  [DEBUG] savedM2LastRunElapsed: "); Serial.print(savedM2LastRunElapsed / 1000); Serial.println("s");
      Serial.print("  [DEBUG] rebootDetected: "); Serial.println(rebootDetected ? "YES" : "NO");
      if (m2ScheduledAfterM1) {
        unsigned long remaining = (m2StartAt > now) ? (m2StartAt - now) : 0;
        Serial.print("  M2 scheduled after M1 in: "); Serial.print(remaining / 1000); Serial.println("s");
      } else if (m2NextAt > now) {
        unsigned long remaining = m2NextAt - now;
        Serial.print("  M2 next run in: "); Serial.print(remaining / 1000); Serial.println("s");
      } else {
        Serial.println("  Motors: DELAYED until WiFi connected");
      }
    }
  }
}

void clearSystemState(){
  prefs.putBool("runState", false);
  prefs.putBool("cpOn", false);
  prefs.putBool("heatOn", false);
  prefs.putBool("shuttingDown", false);
  prefs.putInt("fanSpeed", 0);
  prefs.putULong("saveTime", 0);
  prefs.putULong("m2NextAtRemaining", 0);
  prefs.putULong("m2StartAtRemaining", 0);
  prefs.putBool("m2ScheduledAfterM1", false);
  prefs.putULong("m2LastRunTime", 0);
}

// ---------- Logging (Simplified - Serial only to avoid MQTT overload) ----------
void motorLogMsg(const String& s){ 
  Serial.println(s); 
  pushMotorHTML(s);
  // MQTT logging disabled to keep connection stable
}

// ---------- AQI Calculation (EPA PM2.5 Standard) ----------
int calculateAQI(float pm25) {
  if (pm25 < 0) return 0;
  if (pm25 > 500.4) return 500;
  
  // EPA breakpoints: {Clow, Chigh, Ilow, Ihigh}
  float breakpoints[][4] = {
    {0.0, 12.0, 0, 50},        // Good
    {12.1, 35.4, 51, 100},     // Moderate
    {35.5, 55.4, 101, 150},    // Unhealthy for Sensitive
    {55.5, 150.4, 151, 200},   // Unhealthy
    {150.5, 250.4, 201, 300},  // Very Unhealthy
    {250.5, 500.4, 301, 500}   // Hazardous
  };
  
  for (int i = 0; i < 6; i++) {
    if (pm25 >= breakpoints[i][0] && pm25 <= breakpoints[i][1]) {
      float Ilow = breakpoints[i][2], Ihigh = breakpoints[i][3];
      float Clow = breakpoints[i][0], Chigh = breakpoints[i][1];
      return (int)((Ihigh - Ilow) / (Chigh - Clow) * (pm25 - Clow) + Ilow);
    }
  }
  return 0;
}

// ---------- HEPA Filter Status ----------
void updateHEPAStatus(float pressure) {
  float absP = abs(pressure);
  
  if (absP < HEPA_MIN_NORMAL) {
    hepaStatus = "Weak Airflow/Leak";
    hepaHealthPercent = 0;
  } else if (absP <= HEPA_MAX_NORMAL) {
    hepaStatus = "Normal";
    hepaHealthPercent = (int)(100.0 * (HEPA_REPLACE - absP) / (HEPA_REPLACE - HEPA_MIN_NORMAL));
  } else if (absP <= HEPA_REPLACE) {
    hepaStatus = "Clogging";
    hepaHealthPercent = (int)(100.0 * (HEPA_REPLACE - absP) / (HEPA_REPLACE - HEPA_MIN_NORMAL));
  } else {
    hepaStatus = "Replace Required";
    hepaHealthPercent = 0;
  }
  hepaHealthPercent = constrain(hepaHealthPercent, 0, 100);
}

// ---------- Relay Control (Active LOW: LOW=ON, HIGH=OFF) ----------
inline void systemWrite(bool on){ digitalWrite(PIN_SYSTEM, on ? LOW : HIGH); }
inline void cpWrite(bool on){ digitalWrite(PIN_CP, on ? LOW : HIGH); }
inline void heatWrite(bool on){ digitalWrite(PIN_HEAT, on ? LOW : HIGH); }

// ---------- Motor Control (Active LOW relay) ----------
void m1_start(){ digitalWrite(PIN_MOTOR1, LOW); m1Active=true; motorLogMsg("Motor-1 ON (Drain)"); }
void m1_stop (){ digitalWrite(PIN_MOTOR1, HIGH); m1Active=false; motorLogMsg("Motor-1 OFF"); }
void m2_start(){ digitalWrite(PIN_MOTOR2, LOW); m2Active=true; motorLogMsg("Motor-2 ON (Filter Clean)"); }
void m2_stop (){ digitalWrite(PIN_MOTOR2, HIGH); m2Active=false; motorLogMsg("Motor-2 OFF"); }

// ---------- Fan Control (PWM to Voltage) ----------
void setFanSpeed(FanSpeed speed){
  fanSpeed = speed;
  int pwmValue = FAN_PWM_OFF;
  String speedName = "OFF";
  
  switch(speed){
    case FAN_LOW:  pwmValue = FAN_PWM_LOW;  speedName = "LOW (5V)";  break;
    case FAN_MED:  pwmValue = FAN_PWM_MED;  speedName = "MED (7V)";  break;
    case FAN_HIGH: pwmValue = FAN_PWM_HIGH; speedName = "HIGH (9V)"; break;
    default:       pwmValue = FAN_PWM_OFF;  speedName = "OFF"; break;
  }
  
  ledcWrite(PIN_FAN_PWM, pwmValue);
  motorLogMsg("Fan speed: " + speedName);
}

// ---------- Emergency Stop ----------
void emergencyStopMotors(){
  if (m1Active) { m1_stop(); Serial.println("⚠️ EMERGENCY: Motor-1 stopped"); }
  if (m2Active) { m2_stop(); Serial.println("⚠️ EMERGENCY: Motor-2 stopped"); }
  if (cpOn) { cpWrite(false); cpOn=false; Serial.println("⚠️ EMERGENCY: CP stopped"); }
  if (heatOn) { heatWrite(false); heatOn=false; Serial.println("⚠️ EMERGENCY: Heater stopped"); }
  if (fanSpeed != FAN_OFF) { setFanSpeed(FAN_OFF); Serial.println("⚠️ EMERGENCY: Fan stopped"); }
  systemWrite(false);
}

// ---------- Controllers ----------
void controlCP(float t){
  if (!runState){
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
  if (!runState){
    if (heatOn){ heatWrite(false); heatOn=false; heatLastOffAt=millis(); motorLogMsg("Heater forced OFF (system STOPPED)"); }
    return;
  }
  if (isnan(h)) return;

  unsigned long now = millis();
  float onThresh  = humSet + HUM_DEADBAND;
  float offThresh = humSet;

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

// ---------- System Control ----------
void startSystem(){
  motorLogMsg("[startSystem] Called - runState:" + String(runState) + " shuttingDown:" + String(shuttingDown));
  
  if (shuttingDown) {
    motorLogMsg("[RUN] Cannot start - system is shutting down");
    return;
  }
  if (!runState){
    motorLogMsg("[startSystem] Starting system...");
    runState = true;
    shuttingDown = false;  // Ensure shutdown flag is clear
    shutdownStarted = false;
    shutdownM2Pending = false;
    
    motorLogMsg("[startSystem] Turning on system relay");
    systemWrite(true);
    
    if (fanSpeed == FAN_OFF) {
      motorLogMsg("[startSystem] Starting fan at LOW");
      setFanSpeed(FAN_LOW);
    }
    
    if (!m1Active){ 
      motorLogMsg("[startSystem] Starting Motor-1 for " + String(M1_START_RUN/1000) + "s");
      m1_start(); 
      m1StopAt = millis() + M1_START_RUN; 
      m2ScheduledAfterM1 = false;
    }
    motorLogMsg("[RUN] STARTED - System is now running");
    publishStateLocal();  // Dashboard-compatible: publish state on start
  } else {
    motorLogMsg("[RUN] Already running");
  }
}

void stopSystem(){
  motorLogMsg("[stopSystem] Called - runState:" + String(runState));
  
  if (!runState) {
    motorLogMsg("[RUN] Already stopped");
    return;
  }
  motorLogMsg("[stopSystem] Initiating shutdown sequence");
  runState = false;
  shuttingDown = true;
  shutdownStarted = false;
  shutdownM2Pending = false;
  setFanSpeed(FAN_OFF);
  clearSystemState();
  motorLogMsg("[RUN] STOP requested → Entering shutdown mode");
  publishStateLocal();  // Dashboard-compatible: publish state on stop
}

void toggleSystem(){ if (runState) stopSystem(); else startSystem(); }

// ---------- Telemetry / State (Published separately to AWS and Local) ----------
void publishTelemetryAWS(){
  if(!client.connected()) return;
  
  StaticJsonDocument<768> doc;  // Increased for combo sensor data
  doc["type"] = "telemetry";
  if(isnan(filtTempC)) doc["temp"] = nullptr; else doc["temp"] = filtTempC;
  if(isnan(filtHum))   doc["hum"]  = nullptr; else doc["hum"]  = filtHum;
  doc["m1"]  = m1Active;
  doc["m2"]  = m2Active;
  doc["run"] = runState;
  doc["cp"]  = cpOn;
  doc["heater"] = heatOn;
  doc["fan"] = (fanSpeed != FAN_OFF);
  doc["fanSpeed"] = (int)fanSpeed;
  doc["tempSet"] = tempSet;
  doc["humSet"]  = humSet;
  doc["ip"]=WiFi.localIP().toString();
  doc["thing"]=THINGNAME;
  doc["ts"]  = millis();
  
  // Indicate which sensor type is active
  doc["sensorType"] = useSEN66 ? "combo" : "sht45";
  
  // Add SEN66 data if combo sensors active
  if (useSEN66) {
    doc["aqi"] = sen66_aqi;
    doc["pm1p0"] = sen66_pm1p0;
    doc["pm2p5"] = sen66_pm2p5;
    doc["pm4p0"] = sen66_pm4p0;
    doc["pm10p0"] = sen66_pm10p0;
    doc["voc"] = sen66_vocIndex;
    doc["nox"] = sen66_noxIndex;
    doc["co2"] = sen66_co2;
  }
  
  // Add SDP810 data if combo sensors active
  if (useSDP810) {
    doc["diffPressure"] = sdp810_pressure;
    doc["hepaStatus"] = hepaStatus;
    doc["hepaHealth"] = hepaHealthPercent;
  }
  
  char buf[768];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  bool success = client.publish(AWS_IOT_PUBLISH_TOPIC, reinterpret_cast<const uint8_t*>(buf), n, false);
  if (success) {
    Serial.println("✓ Telemetry → AWS (esp32/pub)");
  }
}

void publishTelemetryLocal(){
  if(!mqttLocal.connected()) {
    Serial.println("⚠️ [Local MQTT] Not connected - skipping telemetry");
    return;
  }
  
  // Dashboard-compatible format (extended for combo sensors)
  StaticJsonDocument<768> doc;  // Increased for combo sensor data
  if(isnan(filtTempC)) doc["temp"] = nullptr; else doc["temp"] = filtTempC;
  if(isnan(filtHum))   doc["hum"]  = nullptr; else doc["hum"]  = filtHum;
  doc["m1"]  = m1Active;
  doc["m2"]  = m2Active;
  doc["run"] = runState;
  doc["cp"]  = cpOn;
  doc["heater"] = heatOn;
  doc["fan"] = (fanSpeed != FAN_OFF);
  doc["fanSpeed"] = (int)fanSpeed;
  doc["tempSet"] = tempSet;
  doc["humSet"]  = humSet;
  doc["ts"]  = millis();
  
  // Indicate which sensor type is active
  doc["sensorType"] = useSEN66 ? "combo" : "sht45";
  
  // Add SEN66 data if combo sensors active
  if (useSEN66) {
    doc["aqi"] = sen66_aqi;
    doc["pm1p0"] = sen66_pm1p0;
    doc["pm2p5"] = sen66_pm2p5;
    doc["pm4p0"] = sen66_pm4p0;
    doc["pm10p0"] = sen66_pm10p0;
    doc["voc"] = sen66_vocIndex;
    doc["nox"] = sen66_noxIndex;
    doc["co2"] = sen66_co2;
  }
  
  // Add SDP810 data if combo sensors active
  if (useSDP810) {
    doc["diffPressure"] = sdp810_pressure;
    doc["hepaStatus"] = hepaStatus;
    doc["hepaHealth"] = hepaHealthPercent;
  }
  
  char buf[896];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  bool success = mqttLocal.publish(tTelemetry().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
  if (success) {
    Serial.println("✓ Telemetry → Local MQTT (" + tTelemetry() + ")");
  } else {
    Serial.println("❌ Telemetry publish to Local MQTT FAILED!");
  }
}

void publishStateAWS(){
  if(!client.connected()) return;
  
  StaticJsonDocument<512> doc;
  doc["type"] = "state";
  doc["run"]=runState; doc["m1"]=m1Active; doc["m2"]=m2Active;
  doc["cp"]=cpOn; doc["heater"]=heatOn;
  doc["fan"]=(fanSpeed != FAN_OFF);
  doc["fanSpeed"]=(int)fanSpeed;
  doc["tempSet"]=tempSet; doc["humSet"]=humSet;
  
  doc["m1_start"] = M1_START_RUN / 1000UL;
  doc["m1_post"] = M1_POST_RUN / 1000UL;
  doc["m2_interval"] = M2_INTERVAL / 1000UL;
  doc["m2_run"] = M2_RUN_TIME / 1000UL;
  doc["m2_delay"] = M2_DELAY_AFTER_M1_STOP / 1000UL;
  doc["ip"]=WiFi.localIP().toString();
  doc["thing"]=THINGNAME;
  doc["ts"]  = millis();
  
  char buf[512];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  bool success = client.publish(AWS_IOT_PUBLISH_TOPIC, reinterpret_cast<const uint8_t*>(buf), n, false);
  if (success) {
    Serial.println("✓ State → AWS (esp32/pub)");
  }
}

void publishStateLocal(){
  if(!mqttLocal.connected()) return;
  
  // Dashboard-compatible format (exact match to original backup)
  StaticJsonDocument<512> doc;
  doc["run"]=runState; doc["m1"]=m1Active; doc["m2"]=m2Active;
  doc["cp"]=cpOn; doc["heater"]=heatOn;
  doc["fan"]=(fanSpeed != FAN_OFF);
  doc["fanSpeed"]=(int)fanSpeed;
  doc["tempSet"]=tempSet; doc["humSet"]=humSet;
  
  doc["m1_start"] = M1_START_RUN / 1000UL;
  doc["m1_post"] = M1_POST_RUN / 1000UL;
  doc["m2_interval"] = M2_INTERVAL / 1000UL;
  doc["m2_run"] = M2_RUN_TIME / 1000UL;
  doc["m2_delay"] = M2_DELAY_AFTER_M1_STOP / 1000UL;
  doc["ip"]=WiFi.localIP().toString();
  char buf[384];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  mqttLocal.publish(tState().c_str(), reinterpret_cast<const uint8_t*>(buf), n, true);
}

// ---------- Sensor Read ----------
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
      if (newT < TEMP_FAIL_THRESHOLD) {
        acceptT = false;
        motorLogMsg("Temp failure rejected: " + String(newT,1) + "C");
      }
      else if (filtTempC < TEMP_FAIL_THRESHOLD && newT > filtTempC) {
        acceptT = true;
        motorLogMsg("Temp recovery: " + String(newT,1) + "C");
      }
      else if (fabs(newT - filtTempC) > TEMP_JUMP_MAX) {
        acceptT = false;
      }
    }
    
    if (!isnan(filtHum)){
      if (newH < HUM_FAIL_THRESHOLD) {
        acceptH = false;
        motorLogMsg("Humidity failure rejected: " + String(newH,1) + "%");
      }
      else if (filtHum < HUM_FAIL_THRESHOLD && newH > filtHum) {
        acceptH = true;
        motorLogMsg("Humidity recovery: " + String(newH,1) + "%");
      }
      else if (fabs(newH - filtHum) > HUM_JUMP_MAX) {
        acceptH = false;
      }
    }

    if (acceptT) { filtTempC = newT; }
    else if (!isnan(filtTempC)) { motorLogMsg("Temp glitch ignored: " + String(newT,1) + "C"); }

    if (acceptH) { filtHum = newH; }
    else if (!isnan(filtHum)) { motorLogMsg("Hum glitch ignored: " + String(newH,1) + "%"); }

    String line = "Temp: " + String((isnan(filtTempC)?newT:filtTempC),1) + " °C | Hum: " + String((isnan(filtHum)?newH:filtHum),1) + "%";
    Serial.println(line);
    pushTempHTML("Temp: " + String((isnan(filtTempC)?newT:filtTempC),1) + "&deg;C | Hum: " + String((isnan(filtHum)?newH:filtHum),1) + "%");
    
    // Publish telemetry to local MQTT (dashboard-compatible)
    publishTelemetryLocal();

  } else {
    Serial.println("SHT45 read failed");
    pushTempHTML("SHT45 read failed");
  }
}

// ---------- Read SEN66 + SDP810 Combo Sensors ----------
void readComboSensorsIfDue() {
  unsigned long now = millis();
  if (now - lastSensorAt < SENSOR_PERIOD) return;
  lastSensorAt = now;
  
  static char errMsg[64];
  
  // Read SEN66 (Air Quality)
  if (useSEN66) {
    int16_t err = sen66.readMeasuredValues(
      sen66_pm1p0, sen66_pm2p5, sen66_pm4p0, sen66_pm10p0,
      sen66_humidity, sen66_temperature,
      sen66_vocIndex, sen66_noxIndex, sen66_co2
    );
    
    if (err == 0) {
      // Update filtered values for control logic
      filtTempC = sen66_temperature;
      filtHum = sen66_humidity;
      sen66_aqi = calculateAQI(sen66_pm2p5);
      
      Serial.printf("[SEN66] T:%.1f°C H:%.1f%% PM2.5:%.1f AQI:%d CO2:%d\n",
                    sen66_temperature, sen66_humidity, sen66_pm2p5, sen66_aqi, sen66_co2);
    } else {
      errorToString(err, errMsg, sizeof(errMsg));
      Serial.printf("[SEN66] Read error: %s\n", errMsg);
    }
  }
  
  // Read SDP810 (Differential Pressure)
  if (useSDP810) {
    uint16_t err = sdp810.readMeasurement(sdp810_pressure, sdp810_temperature);
    
    if (err == 0) {
      updateHEPAStatus(sdp810_pressure);
      Serial.printf("[SDP810] Pressure:%.2fPa HEPA:%s (%d%%)\n",
                    sdp810_pressure, hepaStatus.c_str(), hepaHealthPercent);
    } else {
      errorToString(err, errMsg, sizeof(errMsg));
      Serial.printf("[SDP810] Read error: %s\n", errMsg);
    }
  }
  
  // Publish telemetry
  publishTelemetryLocal();
}

// ---------- Serial Commands (Standalone Control) ----------
// NOTE: System works completely standalone via Serial Monitor
// Future: Push button will replace Serial commands (see PUSH_BUTTON_DIAGRAM.md)
String serialBuf;
void handleSerial(){
  while (Serial.available()){
    char ch = Serial.read();
    if (ch == '\r' || ch == '\n'){
      serialBuf.trim();
      serialBuf.toLowerCase();
      if (serialBuf == "start")  startSystem();  // Standalone: works without WiFi/MQTT
      else if (serialBuf == "stop")   stopSystem();  // Standalone: works without WiFi/MQTT
      else if (serialBuf == "toggle") toggleSystem();  // Standalone: works without WiFi/MQTT
      else if (serialBuf.startsWith("set ")){
        float sp = serialBuf.substring(4).toFloat();
        if (sp>=1 && sp<=100){ 
          tempSet=sp; 
          prefs.putFloat("tempSet",tempSet); 
          motorLogMsg("Temp set: "+String(tempSet,1)+"C"); 
          if(client.connected()) publishStateAWS();
          if(mqttLocal.connected()) publishStateLocal();
        }
      }
      else if (serialBuf.startsWith("hum ")){
        float hs = serialBuf.substring(4).toFloat();
        if (hs>=10 && hs<=90){ 
          humSet=hs; 
          prefs.putFloat("humSet",humSet); 
          motorLogMsg("Hum set: "+String(humSet,1)+"%"); 
          if(client.connected()) publishStateAWS();
          if(mqttLocal.connected()) publishStateLocal();
        }
      }
      else if (serialBuf.startsWith("fan ")){
        String fanCmd = serialBuf.substring(4);
        if (fanCmd == "off" || fanCmd == "0") { 
          setFanSpeed(FAN_OFF); 
          prefs.putInt("fanSpeed", 0); 
          if(client.connected()) publishStateAWS();
          if(mqttLocal.connected()) publishStateLocal();
        }
        else if (fanCmd == "low" || fanCmd == "1") { 
          setFanSpeed(FAN_LOW); 
          prefs.putInt("fanSpeed", 1); 
          if(client.connected()) publishStateAWS();
          if(mqttLocal.connected()) publishStateLocal();
        }
        else if (fanCmd == "med" || fanCmd == "2") { 
          setFanSpeed(FAN_MED); 
          prefs.putInt("fanSpeed", 2); 
          if(client.connected()) publishStateAWS();
          if(mqttLocal.connected()) publishStateLocal();
        }
        else if (fanCmd == "high" || fanCmd == "3") { 
          setFanSpeed(FAN_HIGH); 
          prefs.putInt("fanSpeed", 3); 
          if(client.connected()) publishStateAWS();
          if(mqttLocal.connected()) publishStateLocal();
        }
      }
      else if (serialBuf.length()) motorLogMsg("Unknown cmd: " + serialBuf);
      serialBuf = "";
    } else {
      serialBuf += ch;
      if (serialBuf.length() > 64) serialBuf = serialBuf.substring(0,64);
    }
  }
}

// Function to handle incoming MQTT messages
void messageHandler(char* topic, byte* payload, unsigned int length) 
{
  // Print raw message to Serial
  Serial.println("\n========================================");
  Serial.print("📩 AWS Message Received from: ");
  Serial.println(topic);
  Serial.print("  Payload length: ");
  Serial.println(length);
  Serial.print("  Payload: ");
  for (unsigned int i = 0; i < length && i < 200; i++) {  // Limit to 200 chars for readability
    Serial.print((char)payload[i]);
  }
  if (length > 200) Serial.print("...");
  Serial.println();
  Serial.println("========================================\n");

  // Parse JSON command - increase buffer size for OTA commands
  StaticJsonDocument<1024> doc;  // Increased from 320 to handle OTA commands
  DeserializationError error = deserializeJson(doc, payload, length);
  if (error) {
    Serial.print("❌ JSON parse failed: ");
    Serial.println(error.c_str());
    return;
  }

  // Show what we received
  String cmdStr;
  serializeJson(doc, cmdStr);
  Serial.println("📝 Command: " + cmdStr);
  
  // Handle test message
  if (doc.containsKey("type") && doc["type"] == "test") {
    Serial.println("🧪 TEST MESSAGE RECEIVED!");
    Serial.println("  Message: " + String(doc["message"] | "No message"));
    Serial.println("  Timestamp: " + String(doc["timestamp"] | 0));
    Serial.println("✓ MQTT is working! ESP32 can receive messages.");
    return;
  }
  
  // Handle OTA Update command FIRST (before other commands)
  if (doc.containsKey("type") && doc["type"] == "ota_update") {
    Serial.println("🔄 OTA Update command detected!");
    handleOTAUpdate(doc);
    return; // Don't process other commands during OTA
  }
  
  // Handle motor timing provisioning
  if (doc.containsKey("m1_start")) { 
    M1_START_RUN = doc["m1_start"].as<unsigned long>() * 1000UL; 
    prefs.putULong("m1_start", M1_START_RUN); 
    Serial.println("✓ M1 start time updated: " + String(M1_START_RUN/1000) + "s");
  }
  if (doc.containsKey("m1_post")) { 
    M1_POST_RUN = doc["m1_post"].as<unsigned long>() * 1000UL; 
    prefs.putULong("m1_post", M1_POST_RUN); 
    Serial.println("✓ M1 post time updated: " + String(M1_POST_RUN/1000) + "s");
  }
  if (doc.containsKey("m2_interval")) { 
    M2_INTERVAL = doc["m2_interval"].as<unsigned long>() * 1000UL; 
    prefs.putULong("m2_interval", M2_INTERVAL); 
    Serial.println("✓ M2 interval updated: " + String(M2_INTERVAL/1000) + "s");
  }
  if (doc.containsKey("m2_run")) { 
    M2_RUN_TIME = doc["m2_run"].as<unsigned long>() * 1000UL; 
    prefs.putULong("m2_run", M2_RUN_TIME); 
    Serial.println("✓ M2 run time updated: " + String(M2_RUN_TIME/1000) + "s");
  }
  if (doc.containsKey("m2_delay")) { 
    M2_DELAY_AFTER_M1_STOP = doc["m2_delay"].as<unsigned long>() * 1000UL; 
    prefs.putULong("m2_delay", M2_DELAY_AFTER_M1_STOP); 
    Serial.println("✓ M2 delay updated: " + String(M2_DELAY_AFTER_M1_STOP/1000) + "s");
  }

  bool stateChanged = false;
  
  if (doc.containsKey("start") && doc["start"] == true)  { 
    Serial.println("→ START"); 
    startSystem(); 
    stateChanged = true;
  }
  else if (doc.containsKey("stop") && doc["stop"] == true)   { 
    Serial.println("→ STOP"); 
    stopSystem(); 
    stateChanged = true;
  }
  else if (doc.containsKey("toggle") && doc["toggle"] == true) { 
    Serial.println("→ TOGGLE"); 
    toggleSystem(); 
    stateChanged = true;
  }

  if (doc.containsKey("setpoint")){
    float sp = doc["setpoint"];
    if (sp >= 1 && sp <= 100){
      tempSet = sp; prefs.putFloat("tempSet", tempSet);
      Serial.println("✓ Temp setpoint: " + String(tempSet,1) + "°C");
      stateChanged = true;
    }
  }
  if (doc.containsKey("humset")){
    float hs = doc["humset"];
    if (hs >= 10 && hs <= 90){
      humSet = hs; prefs.putFloat("humSet", humSet);
      Serial.println("✓ Humidity setpoint: " + String(humSet,1) + "%");
      stateChanged = true;
    }
  }
  if (doc.containsKey("fan")){
    int fanCmd = doc["fan"];
    if (fanCmd >= 0 && fanCmd <= 3){
      if (!runState && fanCmd != 0){
        Serial.println("❌ Fan rejected: system not running");
      } else {
        Serial.println("✓ Fan speed: " + String(fanCmd));
        setFanSpeed((FanSpeed)fanCmd);
        prefs.putInt("fanSpeed", fanCmd);
        stateChanged = true;
      }
    } else {
      Serial.println("❌ Invalid fan speed: " + String(fanCmd));
    }
  }
  
  // Handle fanToggle
  if (doc.containsKey("fanToggle") && doc["fanToggle"] == true){
    if (!runState){
      Serial.println("❌ Fan toggle rejected: system not running");
    } else {
      FanSpeed newSpeed;
      switch(fanSpeed){
        case FAN_OFF:
        case FAN_LOW:  newSpeed = FAN_MED;  break;
        case FAN_MED:  newSpeed = FAN_HIGH; break;
        case FAN_HIGH: newSpeed = FAN_LOW;  break;
        default:       newSpeed = FAN_LOW;  break;
      }
      Serial.println("✓ Fan toggle: " + String((int)fanSpeed) + " → " + String((int)newSpeed));
      setFanSpeed(newSpeed);
      prefs.putInt("fanSpeed", (int)newSpeed);
      stateChanged = true;
    }
  }
  
  // Send updated state immediately after AWS command
  if (stateChanged) {
    Serial.println("📤 Sending updated state...");
    if (client.connected()) {
      publishStateAWS();
      publishTelemetryAWS();
    }
    if (mqttLocal.connected()) {
      publishStateLocal();
      publishTelemetryLocal();
    }
  }
}

// ---------- OTA Update Handler ----------
void handleOTAUpdate(JsonDocument& doc) {
  Serial.println("\n========================================");
  Serial.println("🔄 Starting OTA Update Process");
  Serial.println("========================================");

  if (!WiFi.isConnected()) {
    Serial.println("❌ OTA Failed: WiFi not connected");
    publishOTAStatus("error", "WiFi not connected");
    return;
  }
  
  // Extract OTA parameters from MQTT command (minimal - ESP32 uses hardcoded values)
  String version = doc["version"] | "latest";
  String commitSha = doc["commit_sha"] | "";
  
  // Use hardcoded GitHub values (defined at top of file)
  String repoOwner = String(GITHUB_REPO_OWNER);
  String repoName = String(GITHUB_REPO_NAME);
  String githubToken = String(GITHUB_TOKEN);
  String firmwareAssetName = String(GITHUB_FIRMWARE_ASSET_NAME);
  
  // Log OTA parameters
  Serial.println("📋 OTA Parameters:");
  Serial.println("  Version: " + version);
  Serial.println("  Commit SHA: " + commitSha);
  Serial.println("  Repo: " + repoOwner + "/" + repoName + " (hardcoded)");
  Serial.println("  Asset: " + firmwareAssetName + " (hardcoded)");
  Serial.println("  Token: " + (githubToken.length() > 0 ? "***" + githubToken.substring(githubToken.length()-4) : "Not provided"));
  
  Serial.println("\n📥 Fetching latest release from GitHub...");
  publishOTAStatus("downloading", "Fetching release info from GitHub...");
  
  // CRITICAL: Feed watchdog before starting long OTA process
  esp_task_wdt_reset();
  
  // Step 1: Get latest release info
  String releasesUrl = "https://api.github.com/repos/" + repoOwner + "/" + repoName + "/releases/latest";
  
  WiFiClientSecure client_ota;
  client_ota.setInsecure(); // Skip certificate validation for GitHub
  
  HTTPClient http;
  http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
  http.setUserAgent("ESP32-OTA-Client");
  http.setTimeout(30000); // 30 second timeout
  
  Serial.println("  Releases API: " + releasesUrl);
  http.begin(client_ota, releasesUrl);
  http.addHeader("Authorization", "token " + githubToken);
  http.addHeader("Accept", "application/vnd.github.v3+json");
  
  int httpCode = http.GET();
  Serial.println("  HTTP Response Code: " + String(httpCode));
  
  if (httpCode != HTTP_CODE_OK) {
    String errorResponse = http.getString();
    Serial.println("❌ Failed to fetch release info: HTTP " + String(httpCode));
    Serial.println("  Response: " + errorResponse.substring(0, 200));
    http.end();
    publishOTAStatus("error", "Failed to fetch release: HTTP " + String(httpCode));
    return;
  }
  
  // Parse release JSON
  StaticJsonDocument<4096> releaseDoc;
  DeserializationError error = deserializeJson(releaseDoc, http.getStream());
  http.end();
  
  if (error) {
    Serial.println("❌ Failed to parse release JSON: " + String(error.c_str()));
    publishOTAStatus("error", "Failed to parse release JSON");
    return;
  }
  
  String latestVersion = releaseDoc["tag_name"].as<String>();
  Serial.println("✓ Latest release found: " + latestVersion);
  Serial.println("  Searching for asset: " + firmwareAssetName);
  
  // Step 2: Find the firmware asset in the release
  String firmwareUrl = "";
  JsonArray assets = releaseDoc["assets"].as<JsonArray>();
  
  for (JsonObject asset : assets) {
    String assetName = asset["name"].as<String>();
    Serial.println("  Found asset: " + assetName);
    
    if (assetName == firmwareAssetName) {
      String assetId = asset["id"].as<String>();
      firmwareUrl = "https://api.github.com/repos/" + repoOwner + "/" + repoName + "/releases/assets/" + assetId;
      Serial.println("✓ Found matching asset! ID: " + assetId);
      break;
    }
  }
  
  if (firmwareUrl.length() == 0) {
    Serial.println("❌ Error: Could not find asset '" + firmwareAssetName + "' in the release.");
    Serial.println("  Available assets:");
    for (JsonObject asset : assets) {
      Serial.println("    - " + asset["name"].as<String>());
    }
    publishOTAStatus("error", "Firmware asset not found in release");
    return;
  }
  
  // Step 3: Download firmware binary from asset URL
  Serial.println("\n📥 Downloading firmware binary...");
  Serial.println("  Asset URL: " + firmwareUrl);
  publishOTAStatus("installing", "Downloading firmware binary...");
  
  // Feed watchdog before starting download
  esp_task_wdt_reset();
  
  http.begin(client_ota, firmwareUrl);
  http.addHeader("Accept", "application/octet-stream");  // CRITICAL: Get binary, not JSON
  http.addHeader("Authorization", "token " + githubToken);
  http.setUserAgent("ESP32-OTA-Client");
  
  httpCode = http.GET();
  Serial.println("  HTTP Response Code: " + String(httpCode));
  
  if (httpCode != HTTP_CODE_OK) {
    String errorResponse = http.getString();
    Serial.println("❌ Download failed: HTTP " + String(httpCode));
    Serial.println("  Response: " + errorResponse.substring(0, 200));
    http.end();
    publishOTAStatus("error", "Download failed: HTTP " + String(httpCode));
    return;
  }
  
  // Get firmware size
  int contentLength = http.getSize();
  Serial.println("  Content Length: " + String(contentLength) + " bytes");
  
  if (contentLength <= 0) {
    Serial.println("❌ Error: Invalid content length");
    http.end();
    publishOTAStatus("error", "Invalid content length");
    return;
  }
  
  // Start OTA update
  if (!Update.begin(contentLength)) {
    Serial.println("❌ Update.begin() failed: " + String(Update.errorString()));
    http.end();
    publishOTAStatus("error", "Update.begin() failed: " + String(Update.errorString()));
    return;
  }
  
  Serial.println("✓ Update.begin() successful");
  Serial.println("📦 Writing firmware to flash...");
  Serial.println("  ⚠️ This may take 30-60 seconds for large files. Watchdog will be fed during update.");
  
  // Feed watchdog before starting write loop
  esp_task_wdt_reset();
  
  // Use chunked reading approach (from reference code)
  WiFiClient* stream = http.getStreamPtr();
  uint8_t buff[1024];
  size_t totalWritten = 0;
  int lastProgress = -1;
  
      while (totalWritten < contentLength) {
        // CRITICAL: Feed watchdog during OTA update to prevent timeout
        esp_task_wdt_reset();
        
        int available = stream->available();
        if (available > 0) {
          int readLen = stream->read(buff, min((size_t)available, sizeof(buff)));
          if (readLen < 0) {
            Serial.println("❌ Error reading from stream");
            Update.abort();
            http.end();
            publishOTAStatus("error", "Stream read error");
            return;
          }
          
          if (Update.write(buff, readLen) != readLen) {
            Serial.println("❌ Update.write failed: " + String(Update.errorString()));
            Serial.println("  Written so far: " + String(totalWritten) + " bytes");
            Serial.println("  Attempted to write: " + String(readLen) + " bytes");
            Update.abort();
            http.end();
            publishOTAStatus("error", "Write failed: " + String(Update.errorString()));
            return;
          }
          
          totalWritten += readLen;
          int progress = (int)((totalWritten * 100L) / contentLength);
          if (progress > lastProgress && (progress % 5 == 0 || progress == 100)) {
            Serial.print("  Progress: " + String(progress) + "%");
            if (progress == 100) {
              Serial.println();
            } else {
              Serial.print("\r");
            }
            lastProgress = progress;
          }
        }
        delay(1);
      }
  Serial.println();
  
  http.end();
  
  // Verify and finalize
  if (totalWritten != contentLength) {
    Serial.println("❌ Error: Write incomplete. Wrote " + String(totalWritten) + " of " + String(contentLength) + " bytes");
    Update.abort();
    publishOTAStatus("error", "Write incomplete");
    return;
  }
  
  if (!Update.end()) {
    Serial.println("❌ Update.end() failed: " + String(Update.errorString()));
    publishOTAStatus("error", "Update.end() failed: " + String(Update.errorString()));
    Update.abort();
    return;
  }
  
  if (Update.isFinished()) {
    Serial.println("✓ OTA Update successful!");
    Serial.println("  Version: " + latestVersion);
    Serial.println("  Commit: " + commitSha);
    // Save version info to preferences for tracking
    prefs.putString("ota_version", latestVersion);
    prefs.putString("ota_commit", commitSha);
    prefs.putString("ota_updated_at", String(millis() / 1000));
    publishOTAStatus("success", "OTA update completed. Version: " + latestVersion + ". Rebooting...");
    delay(2000);
    ESP.restart();
  } else {
    Serial.println("❌ OTA Update failed: Update not finished");
    publishOTAStatus("error", "Update not finished");
    Update.abort();
  }
  
  Serial.println("========================================\n");
}

void publishOTAStatus(String status, String message) {
  if (!client.connected()) return;
  
  StaticJsonDocument<256> doc;
  doc["type"] = "ota_status";
  doc["status"] = status;
  doc["message"] = message;
  doc["thing"] = THINGNAME;
  doc["ts"] = millis();
  
  char buf[256];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  client.publish(AWS_IOT_PUBLISH_TOPIC, reinterpret_cast<const uint8_t*>(buf), n, false);
  
  // Also publish to local MQTT
  if (mqttLocal.connected()) {
    mqttLocal.publish((baseTopic() + "/ota/status").c_str(), (uint8_t*)buf, n, false);
  }
}

void publishStatusOnline(){
  if(!client.connected()) {
    Serial.println("❌ Cannot publish status - not connected");
    return;
  }
  
  StaticJsonDocument<128> doc;
  doc["type"] = "status";
  doc["status"] = "online";
  doc["thing"] = THINGNAME;
  doc["ip"] = WiFi.localIP().toString();
  
  char buf[128];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  
  bool success = client.publish(AWS_IOT_PUBLISH_TOPIC, reinterpret_cast<const uint8_t*>(buf), n, false);
  if (success) {
    Serial.println("✓ Status 'online' sent to esp32/pub (AWS)");
  } else {
    Serial.println("❌ Status publish failed!");
  }
}

// ========== Local MQTT Functions ==========
void publishStatusOnlineLocal(){
  if(!mqttLocal.connected()) {
    Serial.println("❌ Local MQTT not connected - cannot publish status");
        return;
      }
  bool success = mqttLocal.publish(tStatus().c_str(), "online", true);
  if (success) {
    Serial.println("✓ Status 'online' sent to Local MQTT: " + tStatus());
  } else {
    Serial.println("❌ Failed to publish status to Local MQTT");
  }
}

void onMqttMessageLocal(char* topic, byte* payload, unsigned int len){
  Serial.println("\n========================================");
  Serial.print("📩 Local MQTT Message from: ");
  Serial.println(topic);
  Serial.print("  Payload: ");
  for (unsigned int i = 0; i < len; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
  Serial.println("========================================\n");
  
  String tStr(topic);
  StaticJsonDocument<320> doc;
  if (deserializeJson(doc, payload, len)) return;

  // Handle provisioning
  if (tStr == tProvWifi()){
    if (doc.containsKey("primary")){
      w1_ssid = String((const char*)doc["primary"]["ssid"]);
      w1_pass = String((const char*)doc["primary"]["pass"]);
      prefs.putString("w1_ssid", w1_ssid);
      prefs.putString("w1_pass", w1_pass);
      Serial.println("✓ Primary WiFi saved: " + w1_ssid);
    }
    if (doc.containsKey("secondary")){
      w2_ssid = String((const char*)doc["secondary"]["ssid"]);
      w2_pass = String((const char*)doc["secondary"]["pass"]);
      prefs.putString("w2_ssid", w2_ssid);
      prefs.putString("w2_pass", w2_pass);
      Serial.println("✓ Secondary WiFi saved: " + w2_ssid);
    }
    motorLogMsg("Provision: Wi-Fi saved");
    // Send ACK
    StaticJsonDocument<96> ack; 
    ack["ok"] = true; 
    ack["msg"] = "wifi saved";
    char buf[128]; 
    size_t n = serializeJson(ack, buf, sizeof(buf));
    mqttLocal.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
    Serial.println("✓ ACK sent to: " + tProvAck());
    return;
  }
  else if (tStr == tProvBroker()){
    if (doc.containsKey("host")) { 
      mqttHost = String((const char*)doc["host"]); 
      prefs.putString("mqtt_host", mqttHost); 
    motorLogMsg("Provision: Broker saved: " + mqttHost);
      Serial.println("✓ Broker host updated: " + mqttHost);
    }
    // Send ACK
    StaticJsonDocument<96> ack; 
    ack["ok"] = true; 
    ack["msg"] = "broker saved";
    char buf[128]; 
    size_t n = serializeJson(ack, buf, sizeof(buf));
    mqttLocal.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
    Serial.println("✓ ACK sent to: " + tProvAck());
    return;
  }
  else if (tStr == tProvMotorTimings()){
    if (doc.containsKey("m1_start")) { M1_START_RUN = doc["m1_start"].as<unsigned long>() * 1000UL; prefs.putULong("m1_start", M1_START_RUN); }
    if (doc.containsKey("m1_post")) { M1_POST_RUN = doc["m1_post"].as<unsigned long>() * 1000UL; prefs.putULong("m1_post", M1_POST_RUN); }
    if (doc.containsKey("m2_interval")) { M2_INTERVAL = doc["m2_interval"].as<unsigned long>() * 1000UL; prefs.putULong("m2_interval", M2_INTERVAL); }
    if (doc.containsKey("m2_run")) { M2_RUN_TIME = doc["m2_run"].as<unsigned long>() * 1000UL; prefs.putULong("m2_run", M2_RUN_TIME); }
    if (doc.containsKey("m2_delay")) { M2_DELAY_AFTER_M1_STOP = doc["m2_delay"].as<unsigned long>() * 1000UL; prefs.putULong("m2_delay", M2_DELAY_AFTER_M1_STOP); }
    motorLogMsg("Provision: Motor timings saved");
    Serial.println("✓ Motor timings saved (Local)");
    // Send ACK
    StaticJsonDocument<96> ack; 
    ack["ok"] = true; 
    ack["msg"] = "motor timings saved";
    char buf[128]; 
    size_t n = serializeJson(ack, buf, sizeof(buf));
    mqttLocal.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
    Serial.println("✓ ACK sent to: " + tProvAck());
    return;
  }

  if (tStr != tCmd()) return;

  // Handle commands (same as AWS)
  bool stateChanged = false;
  
  if (doc.containsKey("start") && doc["start"] == true)  { Serial.println("→ START (Local)"); startSystem(); stateChanged = true; }
  else if (doc.containsKey("stop") && doc["stop"] == true)   { Serial.println("→ STOP (Local)"); stopSystem(); stateChanged = true; }
  else if (doc.containsKey("toggle") && doc["toggle"] == true) { Serial.println("→ TOGGLE (Local)"); toggleSystem(); stateChanged = true; }

  if (doc.containsKey("setpoint")){
    float sp = doc["setpoint"];
    if (sp >= 1 && sp <= 100){ tempSet = sp; prefs.putFloat("tempSet", tempSet); Serial.println("✓ Temp setpoint: " + String(tempSet,1) + "°C (Local)"); stateChanged = true; }
  }
  if (doc.containsKey("humset")){
    float hs = doc["humset"];
    if (hs >= 10 && hs <= 90){ humSet = hs; prefs.putFloat("humSet", humSet); Serial.println("✓ Humidity setpoint: " + String(humSet,1) + "% (Local)"); stateChanged = true; }
  }
  if (doc.containsKey("fan")){
    int fanCmd = doc["fan"];
    if (fanCmd >= 0 && fanCmd <= 3){
      if (!runState && fanCmd != 0){ Serial.println("❌ Fan rejected (Local)"); }
      else { Serial.println("✓ Fan speed: " + String(fanCmd) + " (Local)"); setFanSpeed((FanSpeed)fanCmd); prefs.putInt("fanSpeed", fanCmd); stateChanged = true; }
    }
  }
  
  // Handle fanToggle (cycle through LOW → MED → HIGH → LOW, skip OFF when running)
  if (doc.containsKey("fanToggle") && doc["fanToggle"] == true){
    if (!runState){
      Serial.println("❌ Fan toggle rejected: system not running (Local)");
      } else {
      FanSpeed newSpeed;
      switch(fanSpeed){
        case FAN_OFF:
        case FAN_LOW:  newSpeed = FAN_MED;  break;
        case FAN_MED:  newSpeed = FAN_HIGH; break;
        case FAN_HIGH: newSpeed = FAN_LOW;  break;
        default:       newSpeed = FAN_LOW;  break;
      }
      Serial.println("✓ Fan toggle (Local): " + String((int)fanSpeed) + " → " + String((int)newSpeed));
      setFanSpeed(newSpeed);
      prefs.putInt("fanSpeed", (int)newSpeed);
      stateChanged = true;
    }
  }
  
  if (stateChanged) {
    Serial.println("📤 Sending updated state...");
    if (client.connected()) {
      publishStateAWS();
      publishTelemetryAWS();
    }
    if (mqttLocal.connected()) {
      publishStateLocal();
      publishTelemetryLocal();
    }
  }
}

void ensureMqtt(){
  if(mqttLocal.connected()) return;
  if (WiFi.status()!=WL_CONNECTED) return;

  unsigned long now = millis();
  if(now - lastMqttAttempt < 2000) return;
  lastMqttAttempt = now;

  mqttLocal.setServer(mqttHost.c_str(), MQTT_PORT);
  mqttLocal.setBufferSize(MQTT_BUFFER_SIZE);  // Set buffer size for combo sensor data
  mqttLocal.setCallback(onMqttMessageLocal);

  String clientId = String(AHU)+"-"+String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = mqttLocal.connect(clientId.c_str(),
                         MQTT_USER, MQTT_PASS,
                         tStatus().c_str(), 1, true, "offline");
  if(ok){
    publishStatusOnlineLocal();
    mqttLocal.subscribe(tCmd().c_str(), 1);
    mqttLocal.subscribe(tProvWifi().c_str(), 1);
    mqttLocal.subscribe(tProvBroker().c_str(), 1);
    mqttLocal.subscribe(tProvMotorTimings().c_str(), 1);
    Serial.println("✓ Local MQTT connected: " + mqttHost);
    
    // Publish initial state to local MQTT
    publishStateLocal();
    publishTelemetryLocal();
  }else{
    Serial.println("✗ Local MQTT connect failed");
  }
}


void setup()
{
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  
  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n========================================");
  Serial.println("   ALMED AHU Controller v2.0");
  Serial.println("   AWS IoT Cloud Edition");
  Serial.println("========================================");
  Serial.println("HELLO");
  Serial.println("========================================");
  
  esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT * 1000,
    .idle_core_mask = 0,
    .trigger_panic = true
  };
  esp_task_wdt_init(&wdt_config);
  esp_task_wdt_add(NULL);
  Serial.print("✓ Watchdog enabled (");
  Serial.print(WDT_TIMEOUT);
  Serial.println("s timeout)");
  
  esp_task_wdt_reset();

  // 5-Channel Relay Init
  pinMode(PIN_MOTOR1, OUTPUT);
  pinMode(PIN_MOTOR2, OUTPUT);
  pinMode(PIN_HEAT, OUTPUT);
  pinMode(PIN_CP, OUTPUT);
  pinMode(PIN_SYSTEM, OUTPUT);
  
  digitalWrite(PIN_MOTOR1, HIGH);
  digitalWrite(PIN_MOTOR2, HIGH);
  digitalWrite(PIN_HEAT, HIGH);
  digitalWrite(PIN_CP, HIGH);
  digitalWrite(PIN_SYSTEM, HIGH);
  
  cpLastOffAt = millis();
  heatLastOffAt = millis();
  Serial.println("✓ 5-channel relay module initialized (Active LOW)");
  
  // PWM Fan Init
  ledcAttach(PIN_FAN_PWM, FAN_PWM_FREQ, FAN_PWM_RESOLUTION);
  ledcWrite(PIN_FAN_PWM, FAN_PWM_OFF);
  Serial.println("✓ PWM fan control initialized (25 kHz, 8-bit)");
  
  esp_task_wdt_reset();

  Wire.begin(21,22);
  
  // ========== AUTO-DETECT SENSORS ==========
  Serial.println("\n--- Detecting Sensors ---");
  
  // Try SEN66 first (combo sensor)
  sen66.begin(Wire, SEN66_I2C_ADDR_6B);
  int16_t sen66Err = sen66.deviceReset();
  if (sen66Err == 0) {
    delay(1200);  // SEN66 needs warmup after reset
    sen66Err = sen66.startContinuousMeasurement();
    if (sen66Err == 0) {
      useSEN66 = true;
      Serial.println("✓ SEN66 detected and ready (Air Quality Sensor)");
    }
  }
  
  // Try SDP810 (differential pressure)
  sdp810.begin(Wire, SDP8XX_I2C_ADDRESS_0);
  sdp810.stopContinuousMeasurement();
  delay(100);
  uint16_t sdp810Err = sdp810.startContinuousMeasurementWithDiffPressureTCompAndAveraging();
  if (sdp810Err == 0) {
    useSDP810 = true;
    Serial.println("✓ SDP810 detected and ready (HEPA Pressure Sensor)");
  }
  
  // If combo sensors not found, try SHT45 (original sensor)
  if (!useSEN66) {
    if (!sht4.begin()){
      Serial.println("⚠️ SHT45 not found!");
    } else {
      sht4.setPrecision(SHT4X_HIGH_PRECISION);
      sht4.setHeater(SHT4X_NO_HEATER);
      useSHT45 = true;
      Serial.println("✓ SHT45 detected and ready (Original Sensor)");
    }
  }
  
  // Print sensor configuration summary
  Serial.println("\n--- Sensor Configuration ---");
  if (useSEN66 || useSDP810) {
    Serial.println("  Mode: COMBO SENSORS (SEN66 + SDP810)");
    Serial.println("  Data: AQI, PM, VOC, NOx, CO2, HEPA Status");
  } else if (useSHT45) {
    Serial.println("  Mode: ORIGINAL (SHT45 only)");
    Serial.println("  Data: Temperature, Humidity");
  } else {
    Serial.println("  ⚠️ WARNING: No sensors detected!");
  }
  
  esp_task_wdt_reset();

  prefs.begin("ahu", false);

  // Display OTA version info if available (from previous OTA update)
  String otaVersion = prefs.getString("ota_version", "");
  String otaCommit = prefs.getString("ota_commit", "");
  if (otaVersion.length() > 0 || otaCommit.length() > 0) {
    Serial.println("📦 Previous OTA Update Info:");
    if (otaVersion.length() > 0) Serial.println("  Version: " + otaVersion);
    if (otaCommit.length() > 0) Serial.println("  Commit: " + otaCommit.substring(0, 7));
  }

  float sp = prefs.getFloat("tempSet", tempSet);
  if (sp>=1 && sp<=100) tempSet = sp;
  float hs = prefs.getFloat("humSet", humSet);
  if (hs>=10 && hs<=90) humSet = hs;
  
  int savedFan = prefs.getInt("fanSpeed", 0);
  if (savedFan >= 0 && savedFan <= 3) fanSpeed = (FanSpeed)savedFan;

  M1_START_RUN = prefs.getULong("m1_start", M1_START_RUN);
  M1_POST_RUN = prefs.getULong("m1_post", M1_POST_RUN);
  M2_INTERVAL = prefs.getULong("m2_interval", M2_INTERVAL);
  M2_RUN_TIME = prefs.getULong("m2_run", M2_RUN_TIME);
  M2_DELAY_AFTER_M1_STOP = prefs.getULong("m2_delay", M2_DELAY_AFTER_M1_STOP);
  
  // Load WiFi credentials
  w1_ssid = prefs.getString("w1_ssid", DEFAULT_W1_SSID);
  w1_pass = prefs.getString("w1_pass", DEFAULT_W1_PASS);
  w2_ssid = prefs.getString("w2_ssid", String(""));
  w2_pass = prefs.getString("w2_pass", String(""));
  
  // Load Local MQTT broker host
  mqttHost = prefs.getString("mqtt_host", String("10.42.0.1"));
  
  esp_task_wdt_reset();
  
  Serial.println("\n--- Checking for previous state ---");
  restoreSystemState();
  
  Serial.println("\n✓ Preferences loaded");
  Serial.println("  Temp setpoint: " + String(tempSet, 1) + "°C");
  Serial.println("  Humidity setpoint: " + String(humSet, 1) + "%");
  
  esp_task_wdt_reset();

  // ========== STANDALONE MODE: Non-blocking WiFi ==========
  // Start WiFi connection but don't wait - system works without it
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  WiFi.setAutoReconnect(true);  // Auto-reconnect on disconnect
  WiFi.persistent(true);         // Save WiFi credentials to flash
  
  Serial.println("\n📡 WiFi: Starting connection (non-blocking)");
  Serial.println("  ⚠️  System will work standalone even without WiFi");
  Serial.println("  ⚠️  WiFi will reconnect automatically in background");

  // Configure WiFiClientSecure to use the AWS IoT device credentials
  net.setCACert(AWS_CERT_CA);
  net.setCertificate(AWS_CERT_CRT);
  net.setPrivateKey(AWS_CERT_PRIVATE);

  // Connect to the MQTT broker on the AWS endpoint
  client.setServer(AWS_IOT_ENDPOINT, 8883);
  
  // Set MQTT buffer size (important for AWS IoT)
  client.setBufferSize(MQTT_BUFFER_SIZE);
  
  // Set keep-alive to 60 seconds (AWS IoT default is 1200s, but 60s is safer)
  client.setKeepAlive(60);
  
  // Set socket timeout
  client.setSocketTimeout(15);

  // Set the function to handle messages
  client.setCallback(messageHandler);

  Serial.println("\n☁️  AWS IoT: Configuration ready (will connect when WiFi available)");
  Serial.println("  ⚠️  System works standalone - MQTT is optional");

  Serial.println("\n📡 MQTT Configuration (Optional):");
  Serial.println("  ☁️  AWS IoT (Cloud):");
  Serial.println("      📥 Subscribe: " + String(AWS_IOT_SUBSCRIBE_TOPIC));
  Serial.println("      📤 Publish:   " + String(AWS_IOT_PUBLISH_TOPIC));
  Serial.println("  🏠 Local MQTT (Pi): " + mqttHost);
  Serial.println("      📥 Subscribe: " + tCmd());
  Serial.println("      📤 Publish:   " + tTelemetry() + ", " + tState());
  Serial.println("\n✅ STANDALONE MODE ENABLED");
  Serial.println("  - System works without WiFi/MQTT");
  Serial.println("  - Control via Serial Monitor: 'start' / 'stop'");
  Serial.println("  - WiFi/MQTT reconnect automatically in background");
  Serial.println("  - System state preserved during reconnections");
  Serial.println("========================================\n");

  // Try initial AWS IoT connection if WiFi is already connected
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("📡 WiFi already connected, attempting AWS IoT connection...");
    if (client.connect(THINGNAME)) {
      Serial.println("✓ AWS IoT connected on startup");
      bool subResult = client.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
      Serial.print("📥 Subscribed to: " + String(AWS_IOT_SUBSCRIBE_TOPIC));
      Serial.println(subResult ? " ✓" : " ✗ FAILED");
      publishStatusOnline();
    } else {
      Serial.println("✗ AWS IoT connection failed on startup (will retry in loop)");
    }
  }

  // Restore system state if needed (standalone mode)
  if (pendingRecoveryStart) {
    pendingRecoveryStart = false;
    runState = true;
    motorLogMsg("⚠️ RECOVERY START: System recovered and running (standalone mode)");
  }

  lastLoopTime = millis();
}

void loop()
{
  unsigned long now = millis();
  
  esp_task_wdt_reset();
  
  if (now - lastLoopTime > LOOP_TIMEOUT_MS) {
    Serial.println("⚠️ CRITICAL: Loop timeout!");
    motorLogMsg("ERROR: Loop hang - resetting");
    emergencyStopMotors();
    saveSystemState();
    delay(100);
    while(1);
  }
  lastLoopTime = now;
  
  static unsigned long lastStateSave = 0;
  // Save more frequently when Motor 2 is waiting to preserve accurate timing
  // This is critical to prevent flooding if ESP resets during M2 wait period
  unsigned long saveInterval = 10000; // Default: 10 seconds
  if (runState && !shuttingDown && m2NextAt > now && (m2NextAt - now) < 60000) {
    // Motor 2 is waiting and has less than 60s remaining - save every 2 seconds for accuracy
    saveInterval = 2000;
  }
  if (runState && (now - lastStateSave > saveInterval)) {
    saveSystemState();
    lastStateSave = now;
  }

  // ========== STANDALONE MODE: WiFi Reconnection (Non-blocking) ==========
  static unsigned long lastWifiCheck = 0;
  static bool wifiWasConnected = false;
  
  if (now - lastWifiCheck > 2000) {  // Check WiFi status every 2 seconds
    lastWifiCheck = now;
    bool wifiConnected = (WiFi.status() == WL_CONNECTED);
    
    if (wifiConnected && !wifiWasConnected) {
      // WiFi just connected
      Serial.println("\n✓ WiFi Connected!");
      Serial.println("  IP: " + WiFi.localIP().toString());
      motorLogMsg("WiFi: Connected - " + WiFi.localIP().toString());
      wifiWasConnected = true;
    } 
    else if (!wifiConnected && wifiWasConnected) {
      // WiFi just disconnected
      Serial.println("\n⚠️ WiFi Disconnected (system continues running)");
      motorLogMsg("WiFi: Disconnected - system continues standalone");
      wifiWasConnected = false;
    }
    else if (!wifiConnected && !wifiWasConnected) {
      // WiFi still disconnected - try to reconnect (non-blocking)
      static unsigned long lastWifiReconnectAttempt = 0;
      if (now - lastWifiReconnectAttempt > 10000) {  // Try every 10 seconds
        lastWifiReconnectAttempt = now;
        Serial.print("📡 Attempting WiFi reconnection...");
        WiFi.disconnect();
        delay(100);
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
        // Don't wait - just start the connection attempt
      }
    }
  }

  // ========== AWS IoT MQTT (Cloud) - Only if WiFi connected ==========
  // Keep the AWS MQTT connection alive - MUST call this every loop
  if (client.connected()) {
    client.loop();
  }
  
  // Simple reconnection logic for AWS - only try if WiFi connected and MQTT disconnected
  if (WiFi.status() == WL_CONNECTED && !client.connected()) {
    static unsigned long lastReconnectAttempt = 0;
    if (now - lastReconnectAttempt > 15000) { // Wait 15 seconds between attempts
      lastReconnectAttempt = now;
      Serial.println("⚠️ AWS IoT disconnected, reconnecting...");
      esp_task_wdt_reset();
      
      if (client.connect(THINGNAME)) {
        Serial.println("✓ AWS IoT reconnected");
        // Resubscribe to command topic
        bool subResult = client.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
        Serial.print("📥 Resubscribed to: " + String(AWS_IOT_SUBSCRIBE_TOPIC));
        Serial.println(subResult ? " ✓" : " ✗ FAILED");
        // Send status on reconnection
        publishStatusOnline();
        publishStateAWS();
        publishTelemetryAWS();
      } else {
        Serial.print("✗ AWS reconnection failed, state: ");
        Serial.println(client.state());
      }
    }
  }
  
  // Debug: Log MQTT connection status periodically
  static unsigned long lastMqttStatusLog = 0;
  if (now - lastMqttStatusLog > 30000) { // Every 30 seconds
    lastMqttStatusLog = now;
    if (client.connected()) {
      Serial.println("[DEBUG] AWS IoT MQTT: Connected, subscribed to: " + String(AWS_IOT_SUBSCRIBE_TOPIC));
    } else {
      Serial.println("[DEBUG] AWS IoT MQTT: Disconnected (WiFi: " + String(WiFi.status() == WL_CONNECTED ? "OK" : "OFF") + ")");
    }
  }

  // ========== Local MQTT (Raspberry Pi) - Only if WiFi connected ==========
  // Ensure local MQTT connection and handle messages (non-blocking)
  if (WiFi.status() == WL_CONNECTED) {
    ensureMqtt();
    if (mqttLocal.connected()) {
      mqttLocal.loop();
    }
  }

  handleSerial();
  
  // Read appropriate sensors based on what's detected
  if (useSEN66 || useSDP810) {
    readComboSensorsIfDue();
  } else if (useSHT45) {
    readSensorIfDue();
  }
  
  // Debug: Log sensor mode periodically
  static unsigned long lastSensorModeLog = 0;
  if (now - lastSensorModeLog > 30000) {
    lastSensorModeLog = now;
    Serial.printf("[DEBUG] Sensor Mode: SEN66=%s SDP810=%s SHT45=%s\n", 
                  useSEN66 ? "YES" : "NO", 
                  useSDP810 ? "YES" : "NO", 
                  useSHT45 ? "YES" : "NO");
  }

  // Publish to AWS every 5 seconds
  static unsigned long lastAWS = 0;
  if (client.connected() && (now - lastAWS >= 2000)) {
    lastAWS = now;
    publishTelemetryAWS();
    publishStateAWS();
  }
  
  // Publish to Local MQTT every 2 seconds (everything: telemetry, state, status)
  static unsigned long lastLocal = 0;
  if (mqttLocal.connected()) {
    unsigned long timeSinceLastPublish = now - lastLocal;
    if (timeSinceLastPublish >= 2000) {
      lastLocal = now;
      Serial.print("📤 [Local MQTT] Publishing all data every 2s (elapsed: ");
      Serial.print(timeSinceLastPublish);
      Serial.println("ms)...");
      publishTelemetryLocal();
      publishStateLocal();
      publishStatusOnlineLocal();
      Serial.println("✓ [Local MQTT] All data published!");
    }
  } else {
    // Reset timer if disconnected to publish immediately on reconnect
    if (lastLocal != 0) {
      Serial.println("⚠️ [Local MQTT] Disconnected - resetting timer");
      lastLocal = 0;
    }
  }

  controlCP(filtTempC);
  controlHeater(filtHum);

  // =================== SHUTDOWN SEQUENCE ===================
  if (shuttingDown){
    if (!shutdownStarted){
      motorLogMsg("[SHUTDOWN] Starting shutdown sequence");
      if (m2Active) m2_stop();
      m1_start();
      m1StopAt = now + M1_POST_RUN;
      shutdownStarted = true;
      motorLogMsg("[SHUTDOWN] M1 post-drain (" + String(M1_POST_RUN/1000) + "s)");
    }

    if (shutdownStarted && m1Active && now >= m1StopAt){
      m1_stop();
      shutdownM2Pending = true;
      m2StartAt = now + M2_DELAY_AFTER_M1_STOP;
      motorLogMsg("[SHUTDOWN] M1 done, M2 in " + String(M2_DELAY_AFTER_M1_STOP/1000) + "s");
    }

    if (shutdownM2Pending && !m2Active && now >= m2StartAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      motorLogMsg("[SHUTDOWN] M2 final clean (" + String(M2_RUN_TIME/1000) + "s)");
    }

    if (shutdownM2Pending && m2Active && now >= m2StopAt){
      m2_stop();
      systemWrite(false);
      shuttingDown = false;
      shutdownStarted = false;
      shutdownM2Pending = false;
      clearSystemState();
      motorLogMsg("[SHUTDOWN] Complete - System OFF");
    }
    delay(5);
    return;
  }

  // =================== RUNNING SEQUENCE ===================
  if (runState && !shuttingDown){
    // M1 boot drain complete
    if (m1Active && now >= m1StopAt) { 
      motorLogMsg("[RUN] M1 timer expired - stopping M1");
      m1_stop(); 
      m2ScheduledAfterM1 = true; 
      m2StartAt = now + M2_DELAY_AFTER_M1_STOP;
      motorLogMsg("[RUN] M1 boot done, M2 in " + String(M2_DELAY_AFTER_M1_STOP/1000) + "s");
    }

    // First M2 run after M1
    if (m2ScheduledAfterM1 && !m2Active && !m1Active && now >= m2StartAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL;
      m2LastRunTime = now; // CRITICAL: Record when Motor 2 last ran
      m2ScheduledAfterM1 = false;
      motorLogMsg("[RUN] First M2 cycle (" + String(M2_RUN_TIME/1000) + "s), next in " + String(M2_INTERVAL/1000) + "s");
      // CRITICAL: Save state immediately after M2 runs to preserve accurate timing
      saveSystemState();
    }

    // Periodic M2 runs
    if (!m2Active && !m1Active && !m2ScheduledAfterM1 && now >= m2NextAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL;
      m2LastRunTime = now; // CRITICAL: Record when Motor 2 last ran
      motorLogMsg("[RUN] Periodic M2 (" + String(M2_RUN_TIME/1000) + "s)");
      // CRITICAL: Save state immediately after M2 runs to preserve accurate timing
      saveSystemState();
    }
  }

  // Stop M2 when time is up (both run and shutdown modes)
  if (m2Active && now >= m2StopAt) { 
    m2_stop(); 
  }

  delay(5);
}