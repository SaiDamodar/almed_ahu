#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Update.h>
#include <WiFiClientSecure.h>

// ============ GitHub OTA Configuration (Hardcoded) ============
#define GITHUB_REPO_OWNER "ESPUpdaterzaid"
#define GITHUB_REPO_NAME "almed-esp32-firmware"
#define GITHUB_REPO_BRANCH "main"
#define GITHUB_FIRMWARE_PATH "firmware/esp32_main.ino"
// For GitHub Releases, specify the asset name (compiled .bin file)
#define GITHUB_FIRMWARE_ASSET_NAME "esp32_main.ino.bin"  // Name of the .bin file in GitHub Releases
// GitHub token - set this if you want to use private repos
#define GITHUB_TOKEN "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"  // Your GitHub token for private repo access

const char WIFI_SSID[] = "ez"; // Your WiFi SSID
const char WIFI_PASSWORD[] = "12345678"; // Your WiFi password

// ========== Relay Pins (from esp32_main.ino) ==========
const int PIN_MOTOR1 = 32;   // Relay IN1 - Motor 1 (12V DC)
const int PIN_MOTOR2 = 33;   // Relay IN2 - Motor 2 (12V DC)
const int PIN_HEAT = 19;     // Relay IN3 - Heater (220V AC)
const int PIN_CP = 23;       // Relay IN4 - CP Compressor (220V AC)
const int PIN_SYSTEM = 18;   // Relay IN5 - System Master (220V AC)

// Relay array for testing (Active LOW: LOW=ON, HIGH=OFF)
const int relays[] = {PIN_MOTOR1, PIN_MOTOR2, PIN_HEAT, PIN_CP, PIN_SYSTEM};
const int N = sizeof(relays) / sizeof(relays[0]);
const char* relayNames[] = {"MOTOR1", "MOTOR2", "HEAT", "CP", "SYSTEM"};

// ========== Local MQTT Broker (Raspberry Pi) ==========
WiFiClient espNet;
PubSubClient mqttLocal(espNet);

const char* MQTT_USER = "almed";
const char* MQTT_PASS = "Almed1234$";
const uint16_t MQTT_PORT = 1883;
String mqttHost = "10.42.0.1";

// ========== Local MQTT Topics ==========
const char* ORG  = "almed";
const char* SITE = "hospitalA";
const char* ROOM = "icu1";
const char* AHU  = "ahu-01";

String baseTopic()        { return String(ORG)+"/ahu/"+SITE+"/"+ROOM+"/"+AHU; }
String tCmd()             { return baseTopic()+"/cmd"; }
String tStatus()          { return baseTopic()+"/status"; }

// ========== OTA Status Publishing ==========
void publishOTAStatus(String status, String message) {
  if (!mqttLocal.connected()) return;
  
  StaticJsonDocument<256> doc;
  doc["type"] = "ota_status";
  doc["status"] = status;
  doc["message"] = message;
  doc["ts"] = millis();
  
  char buf[256];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  mqttLocal.publish((baseTopic() + "/ota/status").c_str(), (uint8_t*)buf, n, false);
}

// ========== OTA Update Handler (from esp32_main.ino) ==========
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
  Serial.println("  ⚠️ This may take 30-60 seconds for large files.");
  
  // Use chunked reading approach
  WiFiClient* stream = http.getStreamPtr();
  uint8_t buff[1024];
  size_t totalWritten = 0;
  int lastProgress = -1;
  
  while (totalWritten < contentLength) {
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

// ========== MQTT Message Handler ==========
void onMqttMessageLocal(char* topic, byte* payload, unsigned int len){
  Serial.println("\n========================================");
  Serial.print("📩 MQTT Message from: ");
  Serial.println(topic);
  Serial.print("  Payload: ");
  for (unsigned int i = 0; i < len; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
  Serial.println("========================================\n");
  
  String tStr(topic);
  StaticJsonDocument<1024> doc;
  if (deserializeJson(doc, payload, len)) return;

  // Handle OTA Update command
  if (doc.containsKey("type") && doc["type"] == "ota_update") {
    Serial.println("🔄 OTA Update command detected!");
    handleOTAUpdate(doc);
    return; // Don't process other commands during OTA
  }
}

// ========== MQTT Connection ==========
void ensureMqtt(){
  if(mqttLocal.connected()) return;
  if (WiFi.status()!=WL_CONNECTED) return;

  static unsigned long lastMqttAttempt = 0;
  unsigned long now = millis();
  if(now - lastMqttAttempt < 2000) return;  // Rate limit reconnection attempts
  lastMqttAttempt = now;

  mqttLocal.setServer(mqttHost.c_str(), MQTT_PORT);
  mqttLocal.setCallback(onMqttMessageLocal);
  mqttLocal.setSocketTimeout(1);

  String clientId = String(AHU)+"-relay-test-"+String((uint32_t)ESP.getEfuseMac(), HEX);
  bool ok = mqttLocal.connect(clientId.c_str(),
                         MQTT_USER, MQTT_PASS,
                         tStatus().c_str(), 1, true, "offline");
  if(ok){
    mqttLocal.publish(tStatus().c_str(), "online", true);
    mqttLocal.subscribe(tCmd().c_str(), 1);
    Serial.println("✓ Local MQTT connected: " + mqttHost);
    Serial.println("  → OTA updates available via MQTT");
  }else{
    Serial.println("✗ Local MQTT connect failed (will retry in 2s)");
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n========================================");
  Serial.println("   ESP32 RELAY TEST");
  Serial.println("   OTA Update Enabled");
  Serial.println("========================================");
  
  // Initialize all relay pins (Active LOW: LOW=ON, HIGH=OFF)
  for (int i = 0; i < N; i++) {
    pinMode(relays[i], OUTPUT);
    digitalWrite(relays[i], HIGH);  // Start with all relays OFF
  }
  delay(500);
  
  Serial.println("\n✓ Relay pins initialized:");
  for (int i = 0; i < N; i++) {
    Serial.printf("  %s: PIN %d\n", relayNames[i], relays[i]);
  }
  
  // Start WiFi (non-blocking)
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  WiFi.setAutoReconnect(true);
  
  Serial.println("\n📡 WiFi: Connecting...");
  Serial.println("  SSID: " + String(WIFI_SSID));
  Serial.println("  → OTA updates require WiFi connection");
  Serial.println("  → Send OTA command via MQTT: " + tCmd());
  Serial.println("\n🔄 Starting relay test cycle...");
  Serial.println("  Each relay will turn ON for 1 second, then OFF for 0.5 seconds");
  Serial.println("========================================\n");
}

void loop() {
  // Handle WiFi and MQTT (for OTA updates)
  if (WiFi.status() == WL_CONNECTED) {
    ensureMqtt();
    if (mqttLocal.connected()) {
      mqttLocal.loop();
    }
  }
  
  // Relay test cycle
  for (int i = 0; i < N; i++) {
    Serial.printf("→ Testing %s (PIN %d): ", relayNames[i], relays[i]);
    
    // Turn ON relay (Active LOW: LOW=ON)
    digitalWrite(relays[i], LOW);
    Serial.println("ON");
    delay(1000);
    
    // Turn OFF relay (Active LOW: HIGH=OFF)
    digitalWrite(relays[i], HIGH);
    Serial.println("  OFF");
    delay(500);
  }
  
  Serial.println("--- Cycle complete, restarting... ---\n");
}

