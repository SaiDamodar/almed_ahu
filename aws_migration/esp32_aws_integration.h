/*
 * ESP32 AWS IoT Core Integration
 * 
 * This file provides AWS IoT Core connectivity for ESP32 devices.
 * Replace the HiveMQ Cloud connection with AWS IoT Core.
 * 
 * SETUP INSTRUCTIONS:
 * 1. Download Amazon Root CA certificate: https://www.amazontrust.com/repository/AmazonRootCA1.pem
 * 2. Generate device certificate from AWS IoT Console
 * 3. Store certificates in SPIFFS or embed in code
 * 4. Update AWS_IOT_ENDPOINT with your endpoint
 * 5. Include this file in your main .ino file
 */

#ifndef ESP32_AWS_IOT_H
#define ESP32_AWS_IOT_H

#include <WiFiClientSecure.h>
#include <PubSubClient.h>

// ========== AWS IoT Core Configuration ==========
// Get your endpoint from AWS Console: IoT Core → Settings → Device data endpoint
#define AWS_IOT_ENDPOINT "YOUR_ENDPOINT.iot.ap-south-1.amazonaws.com"
#define AWS_IOT_PORT 8883
#define AWS_REGION "ap-south-1"

// ========== Certificate Storage ==========
// Option 1: Embed certificates in code (not recommended for production)
// Option 2: Store in SPIFFS (recommended)
// For SPIFFS, use: SPIFFS.begin() then File certFile = SPIFFS.open("/cert.pem", "r");

// Amazon Root CA (download from https://www.amazontrust.com/repository/AmazonRootCA1.pem)
const char AWS_ROOT_CA[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
MIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsF
ADA5MQswCQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6
b24gUm9vdCBDQSAxMB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTEL
MAkGA1UEBhMCVVMxDzANBgNVBAoTBkFtYXpvbjEZMBcGA1UEAwwQQW1hem9uIFJv
b3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJ4gHHKeNXj
ca9HgFB0fW7Y14h29Jlo91ghYPl0hAEvrAIthtOgQ3pOsqTQNroBvo3bSMgHFzZM
9O6II8c+6f1ucRN0WpyWgTq/Fq4rQeW2cRWjgP9n5l3QJq1yQ2H8M8+8Q6K5F8K
5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8K5F8
-----END CERTIFICATE-----
)EOF";

// Device certificate (replace with your device certificate from AWS IoT Console)
const char DEVICE_CERT[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
REPLACE_WITH_YOUR_DEVICE_CERTIFICATE
-----END CERTIFICATE-----
)EOF";

// Device private key (replace with your device private key from AWS IoT Console)
const char DEVICE_KEY[] PROGMEM = R"EOF(
-----BEGIN RSA PRIVATE KEY-----
REPLACE_WITH_YOUR_DEVICE_PRIVATE_KEY
-----END RSA PRIVATE KEY-----
)EOF";

// ========== Global AWS IoT Client ==========
WiFiClientSecure espNetAWS;
PubSubClient mqttAWS(espNetAWS);

// ========== AWS IoT Functions ==========

/**
 * Initialize AWS IoT Core connection
 * Call this in setup() after WiFi is connected
 */
bool initAWSIoT() {
  Serial.println("Initializing AWS IoT Core...");
  
  // Set up TLS certificates
  espNetAWS.setCACert(AWS_ROOT_CA);
  espNetAWS.setCertificate(DEVICE_CERT);
  espNetAWS.setPrivateKey(DEVICE_KEY);
  
  // Set server and callback
  mqttAWS.setServer(AWS_IOT_ENDPOINT, AWS_IOT_PORT);
  mqttAWS.setCallback(awsMqttCallback);
  mqttAWS.setKeepAlive(60);
  mqttAWS.setBufferSize(1024);
  
  return true;
}

/**
 * Connect to AWS IoT Core
 * Returns true if connected, false otherwise
 */
bool connectToAWS() {
  // Generate unique client ID (use MAC address)
  String clientId = "ESP32-" + String((uint32_t)ESP.getEfuseMac(), HEX);
  
  Serial.print("Connecting to AWS IoT Core as ");
  Serial.println(clientId);
  
  // Attempt connection
  if (mqttAWS.connect(clientId.c_str())) {
    Serial.println("✓ Connected to AWS IoT Core");
    
    // Subscribe to command topic (adjust topic structure as needed)
    String cmdTopic = baseTopic() + "/cmd";
    mqttAWS.subscribe(cmdTopic.c_str());
    Serial.println("✓ Subscribed to: " + cmdTopic);
    
    return true;
  } else {
    Serial.print("✗ AWS IoT connection failed: ");
    Serial.println(mqttAWS.state());
    return false;
  }
}

/**
 * Publish telemetry to AWS IoT Core
 * Use the same topic structure as before: almed/ahu/{site}/{room}/{device-id}/telemetry
 */
bool publishTelemetryToAWS(String payload) {
  String topic = baseTopic() + "/telemetry";
  
  if (mqttAWS.publish(topic.c_str(), payload.c_str())) {
    Serial.println("→ Published to AWS IoT Core: " + topic);
    return true;
  } else {
    Serial.println("✗ AWS publish failed");
    return false;
  }
}

/**
 * Publish state to AWS IoT Core
 */
bool publishStateToAWS(String payload) {
  String topic = baseTopic() + "/state";
  
  if (mqttAWS.publish(topic.c_str(), payload.c_str(), true)) { // retained
    Serial.println("→ Published state to AWS IoT Core: " + topic);
    return true;
  } else {
    Serial.println("✗ AWS state publish failed");
    return false;
  }
}

/**
 * Publish log to AWS IoT Core
 */
bool publishLogToAWS(String payload) {
  String topic = baseTopic() + "/log";
  
  if (mqttAWS.publish(topic.c_str(), payload.c_str())) {
    Serial.println("→ Published log to AWS IoT Core: " + topic);
    return true;
  } else {
    Serial.println("✗ AWS log publish failed");
    return false;
  }
}

/**
 * Publish status to AWS IoT Core
 */
bool publishStatusToAWS(String status) {
  String topic = baseTopic() + "/status";
  
  if (mqttAWS.publish(topic.c_str(), status.c_str(), true)) { // retained
    Serial.println("→ Published status to AWS IoT Core: " + topic);
    return true;
  } else {
    Serial.println("✗ AWS status publish failed");
    return false;
  }
}

/**
 * MQTT callback for AWS IoT Core messages
 * Handle commands from AWS IoT Core
 */
void awsMqttCallback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.print("← AWS IoT message received: ");
  Serial.print(topic);
  Serial.print(" -> ");
  Serial.println(message);
  
  // Parse command and execute (use your existing command handling logic)
  // Example: if (String(topic).endsWith("/cmd")) { handleCommand(message); }
}

/**
 * Maintain AWS IoT connection
 * Call this in loop() to keep connection alive
 */
void maintainAWSConnection() {
  if (!mqttAWS.connected()) {
    Serial.println("AWS IoT disconnected, attempting reconnect...");
    if (WiFi.status() == WL_CONNECTED) {
      connectToAWS();
    }
  } else {
    mqttAWS.loop();
  }
}

/**
 * Disconnect from AWS IoT Core
 */
void disconnectAWS() {
  mqttAWS.disconnect();
  Serial.println("Disconnected from AWS IoT Core");
}

#endif // ESP32_AWS_IOT_H

