#include <WiFi.h>
#include <PubSubClient.h>
#include "DHT.h"

// -------------------------
// Wi-Fi Configuration
// -------------------------
#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASS ""

// -------------------------
// Local Mosquitto Broker Configuration
// -------------------------
// For Wokwi, use 10.0.2.2 (maps to your PC)
// For real hardware on LAN, use your PC/Laptop IP (e.g. 192.168.1.xx)
#define MQTT_HOST "192.168.0.43"
#define MQTT_PORT 1883

// -------------------------
// Device & Topic Configuration
// -------------------------
#define SITE_NAME "demo"
#define UNIT_ID   "ahu-001"
String topicTelemetry = String("almed/ahu/") + SITE_NAME + "/" + UNIT_ID + "/telemetry";

// -------------------------
// DHT Sensor Configuration
// -------------------------
#define DHTPIN 21
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

// -------------------------
// MQTT Client Setup
// -------------------------
WiFiClient espClient;             // Non-secure client for local broker
PubSubClient mqttClient(espClient);

// -------------------------
// Wi-Fi Connection Function
// -------------------------
void connectWiFi() {
  Serial.print("Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi connected!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

// -------------------------
// MQTT Reconnect Function
// -------------------------
void connectMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Connecting to Mosquitto...");
    String clientId = "ESP32Client-" + String(WiFi.macAddress());
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println("connected!");
      mqttClient.publish("almed/ahu/status", "online");
    } else {
      Serial.print("failed, rc=");
      Serial.print(mqttClient.state());
      Serial.println(" retrying in 3s...");
      delay(3000);
    }
  }
}

// -------------------------
// Setup Function
// -------------------------
void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("\nALMED AHU Telemetry - Local MQTT Mode");

  dht.begin();
  connectWiFi();
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
}

// -------------------------
// Loop Function
// -------------------------
unsigned long lastSend = 0;

void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWiFi();
  if (!mqttClient.connected()) connectMQTT();
  mqttClient.loop();

  if (millis() - lastSend > 5000) {  // send every 5 seconds
    lastSend = millis();

    float humidity = dht.readHumidity();
    float temperature = dht.readTemperature();
    if (isnan(humidity) || isnan(temperature)) {
      Serial.println("⚠️ DHT read failed");
      return;
    }

    char payload[150];
    snprintf(payload, sizeof(payload),
      "{\"site\":\"%s\",\"unitId\":\"%s\",\"temperature\":%.2f,\"humidity\":%.2f}",
      SITE_NAME, UNIT_ID, temperature, humidity
    );

    bool ok = mqttClient.publish(topicTelemetry.c_str(), payload, true);
    Serial.print("📤 Publish -> ");
    Serial.println(ok ? payload : "Failed to publish");
  }
}
