#include <pgmspace.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include "WiFi.h"

#define AWS_IOT_SUBSCRIBE_TOPIC "esp32/sub" // MQTT topic to subscribe to for commands

#define THINGNAME "AHU_ESP2" // Unique identifier for your device, change this

const char WIFI_SSID[] = "AlMed"; // Your WiFi SSID
const char WIFI_PASSWORD[] = "AlMed123456"; // Your WiFi password
const char AWS_IOT_ENDPOINT[] = "al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com"; // Your AWS IoT endpoint, change this

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
}


void setup()
{
  Serial.begin(115200); // Start serial communication

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
}

void loop()
{
  // Keep the MQTT connection alive
  client.loop();
  delay(1000);
}