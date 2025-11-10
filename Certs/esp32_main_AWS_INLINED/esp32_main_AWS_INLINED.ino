#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <esp_task_wdt.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// ================== AWS IoT (AHU_AWS sequence) INTEGRATION START ==================
#include <WiFiClientSecure.h>
#include <PubSubClient.h>

// Keep original WiFi connect logic from ESP32 main.
// Use the existing WiFi connection; do NOT override SSID/PASS here.

// AHU_AWS properties (kept identical)
#define AWS_IOT_SUBSCRIBE_TOPIC "esp32/sub" // MQTT topic to subscribe to for commands
#define THINGNAME "AHU_ESP2" // Unique identifier for your device, change this

#ifndef AWS_IOT_PORT
#define AWS_IOT_PORT 8883
#endif

// Device certificates (from AHU_AWS)
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

#define lamp1 19 // GPIO pin for lamp 1
#define lamp2 21 // GPIO pin for lamp 2
#define lamp3 22 // GPIO pin for lamp 3
#define lamp4 23 // GPIO pin for lamp 4

WiFiClientSecure net = WiFiClientSecure();
PubSubClient client(net);

// Function to handle incoming MQTT messages
void messageHandler(char* topic, byte* payload, unsigned int length) 
{
  Serial.print("Incoming message on topic [");
  Serial.print(topic);
  Serial.print("]: ");

  // Construct message from payload
  String received_msg = "";
  for (int i = 0; i < length; i++) 
  {
    received_msg += (char)payload[i];
    Serial.print((char)payload[i]);
  }
  Serial.println();

  // Control the lamps based on the received message
  // Check for commands and actuate corresponding lamp
  if (received_msg == "ON1") 
  {
    digitalWrite(lamp1, HIGH); // Turn on lamp 1
    Serial.println("Lamp1 turned on");
  }
  else if (received_msg == "OFF1") 
  {
    digitalWrite(lamp1, LOW); // Turn off lamp 1
    Serial.println("Lamp1 turned off");
  }
  
  // Repeat for other lamps...
  else if (received_msg == "ON2") 
  {
    digitalWrite(lamp2, HIGH);
    Serial.println("Lamp2 turned on");
  }
  else if (received_msg == "OFF2") 
  {
    digitalWrite(lamp2, LOW);
    Serial.println("Lamp2 turned off");
  }
  
  else if (received_msg == "ON3") 
  {
    digitalWrite(lamp3, HIGH);
    Serial.println("Lamp3 turned on");
  }
  else if (received_msg == "OFF3") 
  {
    digitalWrite(lamp3, LOW);
    Serial.println("Lamp3 turned off");
  }
  
  else if (received_msg == "ON4") 
  {
    digitalWrite(lamp4, HIGH);
    Serial.println("Lamp4 turned on");
  }
  else if (received_msg == "OFF4") 
  {
    digitalWrite(lamp4, LOW);
    Serial.println("Lamp4 turned off");
  }
}


void setup()
{
  Serial.begin(115200); // Start serial communication

  // Initialize GPIO pins for lamps as outputs and set them off
  pinMode(lamp1, OUTPUT);
  pinMode(lamp2, OUTPUT);
  pinMode(lamp3, OUTPUT);
  pinMode(lamp4, OUTPUT);

  digitalWrite(lamp1, LOW);
  digitalWrite(lamp2, LOW);
  digitalWrite(lamp3, LOW);
  digitalWrite(lamp4, LOW);

  WiFi.mode(WIFI_STA); // Set WiFi to station mode
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD); // Connect to WiFi network

  Serial.println("Connecting to Wi-Fi");

  // Wait for connection
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }

  // Configure WiFiClientSecure to use the AWS IoT device credentials
  net.setCACert(AWS_CERT_CA);
  net.setCertificate(AWS_CERT_CRT);
  net.setPrivateKey(AWS_CERT_PRIVATE);

  // Connect to the MQTT broker on the AWS endpoint
  client.setServer(AWS_IOT_ENDPOINT, 8883);

  // Set the function to handle messages
  client.setCallback(messageHandler);

  Serial.println("Connecting to AWS IOT");

  // Attempt to connect to AWS IoT
  while (!client.connect(THINGNAME))
  {
    Serial.print(".");
    delay(100);
  }

  // Check if connection was successful
  if (!client.connected())
  {
    Serial.println("AWS IoT Timeout!");
    return;
  }

  // Subscribe to the MQTT topic for receiving commands
  client.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);

  Serial.println("AWS IoT Connected!");

  awsInit(); // AHU_AWS → initialize AWS IoT after WiFi
}

void loop()
{
  awsTick(); // AHU_AWS → service AWS MQTT

  // Keep the MQTT connection alive
  client.loop();
  delay(1000);
}
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

// GPIOs used by AHU_AWS (guarded so we don't redefine if main already has them)
#ifndef AHU_AWS_PINS_DEFINED
#define AHU_AWS_PINS_DEFINED
#define lamp1 19
#define lamp2 21
#define lamp3 22
#define lamp4 23
#endif

WiFiClientSecure awsNet;
PubSubClient awsClient(awsNet);

// Forward decls
void messageHandlerAWS(char* topic, byte* payload, unsigned int length);
bool awsEnsureConnected();

// Initialize AWS MQTT after WiFi is up
void awsInit()
{
  awsNet.setCACert(AWS_CERT_CA);
  awsNet.setCertificate(AWS_CERT_CRT);
  awsNet.setPrivateKey(AWS_CERT_PRIVATE);

  awsClient.setServer(AWS_IOT_ENDPOINT, AWS_IOT_PORT);
  awsClient.setCallback(messageHandlerAWS);

  // configure AHU_AWS GPIOs
  #ifdef lamp1
  pinMode(lamp1, OUTPUT);
  #endif
  #ifdef lamp2
  pinMode(lamp2, OUTPUT);
  #endif
  #ifdef lamp3
  pinMode(lamp3, OUTPUT);
  #endif
  #ifdef lamp4
  pinMode(lamp4, OUTPUT);
  #endif

  awsEnsureConnected();
}

// Keep connection alive (call this in loop())
void awsTick()
{
  if (!awsClient.connected())
  {
    awsEnsureConnected();
  }
  awsClient.loop();
}

bool awsEnsureConnected()
{
  if (awsClient.connected()) return true;

  // Use existing WiFi connection state from main
  if (WiFi.status() != WL_CONNECTED) return false;

  // Build client id from THINGNAME if present
  String clientId = String(THINGNAME);
  if (awsClient.connect(clientId.c_str()))
  {
    awsClient.subscribe(AWS_IOT_SUBSCRIBE_TOPIC);
    return true;
  }
  return false;
}

// Original AHU_AWS message handler, renamed:
void messageHandlerAWS(char* topic, byte* payload, unsigned int length) 
{
  Serial.print("Incoming message on topic [");
  Serial.print(topic);
  Serial.print("]: ");

  // Construct message from payload
  String received_msg = "";
  for (int i = 0; i < length; i++) 
  {
    received_msg += (char)payload[i];
    Serial.print((char)payload[i]);
  }
  
// ================== AWS IoT (AHU_AWS sequence) INTEGRATION END ==================

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

// ============ DEFAULT WiFi ============
#define DEFAULT_W1_SSID "PiSpot"
#define DEFAULT_W1_PASS "12345678"

// ---------- SHT45 ----------
Adafruit_SHT4x sht4;
float filtTempC = NAN, filtHum = NAN;
unsigned long lastSensorAt = 0;
const unsigned long SENSOR_PERIOD = 2000;

const float TEMP_JUMP_MAX = 12.0;
const float HUM_JUMP_MAX  = 18.0;
const float TEMP_FAIL_THRESHOLD = 5.0;
const float HUM_FAIL_THRESHOLD = 10.0;

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

// ---------- MQTT (Local Pi only) ----------
WiFiClient espNet;
PubSubClient mqtt(espNet);

const char* MQTT_USER = "almed";
const char* MQTT_PASS = "Almed1234$";
const uint16_t MQTT_PORT = 1883;
unsigned long lastMqttAttempt = 0;

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
String tProvWifi()        { return baseTopic()+"/provision/wifi"; }
String tProvBroker()      { return baseTopic()+"/provision/broker"; }
String tProvMotorTimings(){ return baseTopic()+"/provision/motor_timings"; }
String tProvAck()         { return baseTopic()+"/provision/ack"; }

// ---------- Preferences ----------
Preferences prefs;
String w1_ssid, w1_pass, w2_ssid, w2_pass;
String mqttHost = "10.42.0.1";

// ---------- Watchdog & State Recovery ----------
unsigned long lastLoopTime = 0;
unsigned long wifiFailStartTime = 0;
bool wifiWasFailing = false;
int consecutiveWifiFailures = 0;
bool wifiAssociationRefused = false;
bool pendingRecoveryStart = false;

// ---------- State Persistence ----------
void saveSystemState(){
  prefs.putBool("runState", runState);
  prefs.putBool("cpOn", cpOn);
  prefs.putBool("heatOn", heatOn);
  prefs.putBool("shuttingDown", shuttingDown);
  prefs.putInt("fanSpeed", (int)fanSpeed);
  prefs.putULong("saveTime", millis());
}

void restoreSystemState(){
  unsigned long saveTime = prefs.getULong("saveTime", 0);
  if (saveTime == 0 || millis() < 300000) {
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
      
      Serial.println("⚠️ WATCHDOG RECOVERY: State restored, waiting for WiFi");
      Serial.print("  CP: "); Serial.print(cpOn ? "ON" : "OFF");
      Serial.print(" | Heater: "); Serial.print(heatOn ? "ON" : "OFF");
      Serial.print(" | Fan: "); Serial.println(savedFanSpd);
      Serial.println("  Motors: DELAYED until WiFi connected");
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
}

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
    publishState();
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
  publishState();
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
  doc["fan"] = (fanSpeed != FAN_OFF);
  doc["fanSpeed"] = (int)fanSpeed;
  doc["tempSet"] = tempSet;
  doc["humSet"]  = humSet;
  doc["ts"]  = millis();
  char buf[448];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  mqtt.publish(tTelemetry().c_str(), reinterpret_cast<const uint8_t*>(buf), n, false);
}

void publishState(){
  if(!mqtt.connected()) return;
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
  mqtt.publish(tState().c_str(), reinterpret_cast<const uint8_t*>(buf), n, true);
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
    mqttPublishLog("INFO", line);
    publishTelemetry();

  } else {
    Serial.println("SHT45 read failed");
    pushTempHTML("SHT45 read failed");
    mqttPublishLog("WARN", "SHT45 read failed");
  }
}

// =========================== WiFi ===========================
enum WifiNet { NET_PRIMARY = 0, NET_SECONDARY = 1 };
WifiNet currentTry = NET_PRIMARY;
unsigned long lastWifiAttemptAt = 0;
const unsigned long WIFI_TRY_WINDOW_MS = 15000;
const unsigned long WIFI_BACKOFF_MS    = 5000;

void WiFiEvent(WiFiEvent_t event) {
  switch(event) {
    case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
      if (WiFi.status() == WL_CONNECT_FAILED) {
        wifiAssociationRefused = true;
        Serial.println("⚠️ WiFi Association REFUSED");
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
    esp_task_wdt_reset();
  }
  
  if (WiFi.status() == WL_CONNECT_FAILED || WiFi.status() == WL_DISCONNECTED) {
    consecutiveWifiFailures++;
    if (consecutiveWifiFailures >= 3) {
      Serial.println("⚠️ WiFi association failed multiple times");
      motorLogMsg("WARN: WiFi association error");
    }
  } else if (WiFi.status() == WL_CONNECTED) {
    consecutiveWifiFailures = 0;
  }
  
  return WiFi.status()==WL_CONNECTED;
}

void rotateWifiIfNeeded(){
  if (WiFi.status()==WL_CONNECTED) {
    if (wifiWasFailing) {
      wifiWasFailing = false;
      wifiFailStartTime = 0;
      consecutiveWifiFailures = 0;
      wifiAssociationRefused = false;
    }
    return;
  }
  
  if (wifiAssociationRefused) {
    Serial.println("⚠️ WiFi Association Error - IMMEDIATE RESET");
    motorLogMsg("ERROR: WiFi association refused - resetting ESP32");
    emergencyStopMotors();
    saveSystemState();
    delay(100);
    ESP.restart();
  }
  
  unsigned long now = millis();
  if (!wifiWasFailing) {
    wifiWasFailing = true;
    wifiFailStartTime = now;
  }
  
  if (wifiWasFailing && (now - wifiFailStartTime > WIFI_FAIL_RESET_MS)) {
    Serial.println("⚠️ WiFi failed for 15s - resetting");
    motorLogMsg("ERROR: WiFi failure timeout - resetting ESP32");
    emergencyStopMotors();
    saveSystemState();
    delay(100);
    esp_task_wdt_config_t quick_reset = {
      .timeout_ms = 1000,
      .idle_core_mask = 0,
      .trigger_panic = true
    };
    esp_task_wdt_init(&quick_reset);
    esp_task_wdt_add(NULL);
    while(1);
  }
  
  if (now - lastWifiAttemptAt < WIFI_BACKOFF_MS) return;
  lastWifiAttemptAt = now;

  if (currentTry == NET_PRIMARY){
    if (w1_ssid.length()){
      motorLogMsg("Wi-Fi: trying PRIMARY: " + w1_ssid);
      if (tryConnectWiFiOnce(w1_ssid.c_str(), w1_pass.c_str(), WIFI_TRY_WINDOW_MS)){
        motorLogMsg("Wi-Fi connected (PRIMARY), IP: " + WiFi.localIP().toString());
        return;
      }
    }
    currentTry = NET_SECONDARY;
  } else {
    if (w2_ssid.length()){
      motorLogMsg("Wi-Fi: trying SECONDARY: " + w2_ssid);
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
  mqtt.publish(tStatus().c_str(), "online", true);
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
    motorLogMsg("Provision: Wi-Fi saved");
    StaticJsonDocument<96> ack; ack["ok"]=true; ack["msg"]="wifi saved";
    char buf[128]; size_t n = serializeJson(ack, buf, sizeof(buf));
    mqtt.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
  else if (t == tProvBroker()){
    if (doc.containsKey("host")) { mqttHost = String((const char*)doc["host"]); prefs.putString("mqtt_host", mqttHost); }
    motorLogMsg("Provision: Broker saved: " + mqttHost);
    StaticJsonDocument<96> ack; ack["ok"]=true; ack["msg"]="broker saved";
    char buf[128]; size_t n = serializeJson(ack, buf, sizeof(buf));
    mqtt.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
  else if (t == tProvMotorTimings()){
    if (doc.containsKey("m1_start")) { M1_START_RUN = doc["m1_start"].as<unsigned long>() * 1000UL; prefs.putULong("m1_start", M1_START_RUN); }
    if (doc.containsKey("m1_post")) { M1_POST_RUN = doc["m1_post"].as<unsigned long>() * 1000UL; prefs.putULong("m1_post", M1_POST_RUN); }
    if (doc.containsKey("m2_interval")) { M2_INTERVAL = doc["m2_interval"].as<unsigned long>() * 1000UL; prefs.putULong("m2_interval", M2_INTERVAL); }
    if (doc.containsKey("m2_run")) { M2_RUN_TIME = doc["m2_run"].as<unsigned long>() * 1000UL; prefs.putULong("m2_run", M2_RUN_TIME); }
    if (doc.containsKey("m2_delay")) { M2_DELAY_AFTER_M1_STOP = doc["m2_delay"].as<unsigned long>() * 1000UL; prefs.putULong("m2_delay", M2_DELAY_AFTER_M1_STOP); }
    
    motorLogMsg("Provision: Motor timings saved");
    StaticJsonDocument<96> ack; ack["ok"]=true; ack["msg"]="motor timings saved";
    char buf[128]; size_t n = serializeJson(ack, buf, sizeof(buf));
    mqtt.publish(tProvAck().c_str(), (uint8_t*)buf, n, false);
  }
}

void onMqttMessage(char* topic, byte* payload, unsigned int len){
  String tStr(topic);
  if (tStr == tProvWifi() || tStr == tProvBroker() || tStr == tProvMotorTimings()){
    handleProvisioning(topic, payload, len);
    return;
  }

  if (tStr != tCmd()) return;

  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, payload, len)) return;

  // Debug: Show what we received
  String cmdStr;
  serializeJson(doc, cmdStr);
  motorLogMsg("MQTT CMD: " + cmdStr);

  if (doc.containsKey("start") && doc["start"] == true)  { motorLogMsg("→ START"); startSystem(); }
  else if (doc.containsKey("stop") && doc["stop"] == true)   { motorLogMsg("→ STOP"); stopSystem(); }
  else if (doc.containsKey("toggle") && doc["toggle"] == true) { motorLogMsg("→ TOGGLE"); toggleSystem(); }

  if (doc.containsKey("setpoint")){
    float sp = doc["setpoint"];
    if (sp >= 1 && sp <= 100){
      tempSet = sp; prefs.putFloat("tempSet", tempSet);
      motorLogMsg("Temp setpoint: " + String(tempSet,1) + "C");
      publishState();
    }
  }
  if (doc.containsKey("humset")){
    float hs = doc["humset"];
    if (hs >= 10 && hs <= 90){
      humSet = hs; prefs.putFloat("humSet", humSet);
      motorLogMsg("Hum setpoint: " + String(humSet,1) + "%");
      publishState();
    }
  }
  if (doc.containsKey("fan")){
    int fanCmd = doc["fan"];
    motorLogMsg("Fan CMD: " + String(fanCmd));
    if (fanCmd >= 0 && fanCmd <= 3){
      if (!runState && fanCmd != 0){
        motorLogMsg("→ Fan rejected: system not running");
      } else {
        motorLogMsg("→ Fan speed: " + String(fanCmd));
        setFanSpeed((FanSpeed)fanCmd);
        prefs.putInt("fanSpeed", fanCmd);
        publishState();
      }
    } else {
      motorLogMsg("→ Invalid fan speed: " + String(fanCmd));
    }
  }
  
  // Handle fanToggle (cycle through LOW → MED → HIGH → LOW, skip OFF when running)
  if (doc.containsKey("fanToggle") && doc["fanToggle"] == true){
    if (!runState){
      motorLogMsg("Fan toggle rejected: system not running");
    } else {
      FanSpeed newSpeed;
      switch(fanSpeed){
        case FAN_OFF:
        case FAN_LOW:  newSpeed = FAN_MED;  break;
        case FAN_MED:  newSpeed = FAN_HIGH; break;
        case FAN_HIGH: newSpeed = FAN_LOW;  break;
        default:       newSpeed = FAN_LOW;  break;
      }
      motorLogMsg("Fan toggle: " + String((int)fanSpeed) + " → " + String((int)newSpeed));
      setFanSpeed(newSpeed);
      prefs.putInt("fanSpeed", (int)newSpeed);
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
    mqtt.subscribe(tProvMotorTimings().c_str(), 1);
    motorLogMsg("MQTT connected: " + mqttHost);
    publishState();
  }else{
    motorLogMsg("MQTT connect failed");
  }
}

// ---------- Serial Commands ----------
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
      else if (serialBuf.startsWith("set ")){
        float sp = serialBuf.substring(4).toFloat();
        if (sp>=1 && sp<=100){ tempSet=sp; prefs.putFloat("tempSet",tempSet); motorLogMsg("Temp set: "+String(tempSet,1)+"C"); publishState(); }
      }
      else if (serialBuf.startsWith("hum ")){
        float hs = serialBuf.substring(4).toFloat();
        if (hs>=10 && hs<=90){ humSet=hs; prefs.putFloat("humSet",humSet); motorLogMsg("Hum set: "+String(humSet,1)+"%"); publishState(); }
      }
      else if (serialBuf.startsWith("fan ")){
        String fanCmd = serialBuf.substring(4);
        if (fanCmd == "off" || fanCmd == "0") { setFanSpeed(FAN_OFF); prefs.putInt("fanSpeed", 0); publishState(); }
        else if (fanCmd == "low" || fanCmd == "1") { setFanSpeed(FAN_LOW); prefs.putInt("fanSpeed", 1); publishState(); }
        else if (fanCmd == "med" || fanCmd == "2") { setFanSpeed(FAN_MED); prefs.putInt("fanSpeed", 2); publishState(); }
        else if (fanCmd == "high" || fanCmd == "3") { setFanSpeed(FAN_HIGH); prefs.putInt("fanSpeed", 3); publishState(); }
      }
      else if (serialBuf.length()) motorLogMsg("Unknown cmd: " + serialBuf);
      serialBuf = "";
    } else {
      serialBuf += ch;
      if (serialBuf.length() > 64) serialBuf = serialBuf.substring(0,64);
    }
  }
}

// ---------- Setup ----------
void setup(){
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  
  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n========================================");
  Serial.println("   ALMED AHU Controller v2.0");
  Serial.println("   Local MQTT Only");
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
  if (!sht4.begin()){
    Serial.println("⚠️ SHT45 not found!");
  } else {
    sht4.setPrecision(SHT4X_HIGH_PRECISION);
    sht4.setHeater(SHT4X_NO_HEATER);
    Serial.println("✓ SHT45 ready");
  }
  
  esp_task_wdt_reset();

  prefs.begin("ahu", false);

  float sp = prefs.getFloat("tempSet", tempSet);
  if (sp>=1 && sp<=100) tempSet = sp;
  float hs = prefs.getFloat("humSet", humSet);
  if (hs>=10 && hs<=90) humSet = hs;
  
  int savedFan = prefs.getInt("fanSpeed", 0);
  if (savedFan >= 0 && savedFan <= 3) fanSpeed = (FanSpeed)savedFan;

  w1_ssid = prefs.getString("w1_ssid", DEFAULT_W1_SSID);
  w1_pass = prefs.getString("w1_pass", DEFAULT_W1_PASS);
  w2_ssid = prefs.getString("w2_ssid", String(""));
  w2_pass = prefs.getString("w2_pass", String(""));

  mqttHost = prefs.getString("mqtt_host", String("10.42.0.1"));
  
  M1_START_RUN = prefs.getULong("m1_start", M1_START_RUN);
  M1_POST_RUN = prefs.getULong("m1_post", M1_POST_RUN);
  M2_INTERVAL = prefs.getULong("m2_interval", M2_INTERVAL);
  M2_RUN_TIME = prefs.getULong("m2_run", M2_RUN_TIME);
  M2_DELAY_AFTER_M1_STOP = prefs.getULong("m2_delay", M2_DELAY_AFTER_M1_STOP);
  
  esp_task_wdt_reset();
  
  WiFi.onEvent(WiFiEvent);
  Serial.println("✓ WiFi event handler registered");
  
  Serial.println("\n--- Checking for previous state ---");
  restoreSystemState();
  
  Serial.println("\n✓ Boot complete. Ready.");
  Serial.println("  Temp setpoint: " + String(tempSet, 1) + "°C");
  Serial.println("  Humidity setpoint: " + String(humSet, 1) + "%");
  Serial.println("========================================\n");

  lastWifiAttemptAt = 0;
  lastLoopTime = millis();
}

// ---------- Loop ----------
void loop(){
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
  if (runState && (now - lastStateSave > 10000)) {
    saveSystemState();
    lastStateSave = now;
  }

  if (WiFi.status()!=WL_CONNECTED) rotateWifiIfNeeded();

  if (pendingRecoveryStart && WiFi.status() == WL_CONNECTED && mqtt.connected()) {
    pendingRecoveryStart = false;
    runState = true;
    motorLogMsg("⚠️ RECOVERY START: Motors starting now");
    Serial.println("  System recovered and running");
  }

  if (WiFi.status()==WL_CONNECTED){ ensureMqtt(); if(mqtt.connected()) mqtt.loop(); }

  handleSerial();
  readSensorIfDue();

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
      publishState();
    }

    if (shutdownStarted && m1Active && now >= m1StopAt){
      m1_stop();
      shutdownM2Pending = true;
      m2StartAt = now + M2_DELAY_AFTER_M1_STOP;
      motorLogMsg("[SHUTDOWN] M1 done, M2 in " + String(M2_DELAY_AFTER_M1_STOP/1000) + "s");
      publishState();
    }

    if (shutdownM2Pending && !m2Active && now >= m2StartAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      motorLogMsg("[SHUTDOWN] M2 final clean (" + String(M2_RUN_TIME/1000) + "s)");
      publishState();
    }

    if (shutdownM2Pending && m2Active && now >= m2StopAt){
      m2_stop();
      systemWrite(false);
      shuttingDown = false;
      shutdownStarted = false;
      shutdownM2Pending = false;
      clearSystemState();
      motorLogMsg("[SHUTDOWN] Complete - System OFF");
      publishState();
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
      publishState(); 
    }

    // First M2 run after M1
    if (m2ScheduledAfterM1 && !m2Active && !m1Active && now >= m2StartAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL;
      m2ScheduledAfterM1 = false;
      motorLogMsg("[RUN] First M2 cycle (" + String(M2_RUN_TIME/1000) + "s), next in " + String(M2_INTERVAL/1000) + "s");
      publishState();
    }

    // Periodic M2 runs
    if (!m2Active && !m1Active && !m2ScheduledAfterM1 && now >= m2NextAt){
      m2_start();
      m2StopAt = now + M2_RUN_TIME;
      m2NextAt = now + M2_INTERVAL;
      motorLogMsg("[RUN] Periodic M2 (" + String(M2_RUN_TIME/1000) + "s)");
      publishState();
    }
  }

  // Stop M2 when time is up (both run and shutdown modes)
  if (m2Active && now >= m2StopAt) { 
    m2_stop(); 
    publishState(); 
  }

  delay(5);
}