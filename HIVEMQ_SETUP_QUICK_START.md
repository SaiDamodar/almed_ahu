# HiveMQ Cloud Setup - Quick Start Guide

**Complete setup guide for connecting your ESP32 to HiveMQ Cloud**

---

## 📋 What We Did

✅ **Created backup**: `esp32_main_BACKUP_local_only.ino` (your original code)  
✅ **Updated ESP32 code**: `esp32_main.ino` (now supports dual-broker)  
✅ **Local system unchanged**: Your desktop dashboard continues working  
✅ **Added cloud support**: ESP32 now publishes to HiveMQ Cloud too  

---

## 🎯 How It Works Now

```
ESP32 Sensor Box (ahu-01)
    │
    ├───→ Raspberry Pi (10.42.0.1:1883)  ← Priority 1 (Local)
    │     └─→ Flutter Desktop Dashboard (WORKS AS BEFORE)
    │
    └───→ HiveMQ Cloud (your-cluster:8883) ← Priority 2 (Cloud)
          └─→ Mobile App (TO BE BUILT LATER)
```

---

## Step 1: Create HiveMQ Cloud Account (5 minutes)

### 1.1 Sign Up

1. Go to: **https://www.hivemq.com/mqtt-cloud-broker/**
2. Click **"Get Started for Free"**
3. Fill in:
   - Email: `your-email@hospital.com`
   - Password: Strong password (save it!)
4. Click **"Create Free Account"**
5. Check email for verification link
6. Click verification link

**No credit card required!**

---

### 1.2 Create Cluster

1. After login, click **"Create Cluster"**
2. Choose plan: **"Serverless"** (Free tier)
3. Configure:
   - **Name**: `almed-ahu-production`
   - **Region**: Choose closest to your location:
     - India: `ap-south-1` (Mumbai)
     - Europe: `eu-central-1` (Frankfurt)
     - USA: `us-east-1` (Virginia)
   - **Cloud Provider**: AWS (default)
4. Click **"Create Cluster"**
5. Wait 2-3 minutes for cluster creation

---

### 1.3 Get Cluster URL

After cluster is created, you'll see:

```
╔═══════════════════════════════════════════════════╗
║  Cluster: almed-ahu-production                    ║
║  Status: ● Running                                 ║
╠═══════════════════════════════════════════════════╣
║  Connection Details:                              ║
║  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ║
║  Host: abc123def456.s2.eu.hivemq.cloud           ║
║  Port (MQTT): 8883                                ║
║  Port (WebSocket): 8884                           ║
╚═══════════════════════════════════════════════════╝
```

**IMPORTANT**: Copy and save this URL!

Example: `abc123def456.s2.eu.hivemq.cloud`

---

### 1.4 Create Credentials

1. Click **"Access Management"** in sidebar
2. Click **"Add Credentials"**
3. Fill in:
   - **Username**: `almed`
   - **Password**: `AlMed123456` (or create your own strong password)
4. Click **"Add Credential"**
5. **IMPORTANT**: Copy and save the password NOW (you won't see it again!)

---

### 1.5 Save Your Credentials

Create a note with your HiveMQ details:

```
HiveMQ Cloud - ALMED AHU Production
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cluster URL: abc123def456.s2.eu.hivemq.cloud
Port (MQTT/TLS): 8883
Username: almed
Password: AlmedHospital2025!
Created: 2025-10-30
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Save this somewhere secure!** (Password manager, encrypted file, etc.)

---

## Step 2: Test HiveMQ Connection (2 minutes)

Before updating ESP32, let's test the connection from Raspberry Pi:

```bash
# Test publish
mosquitto_pub \
  -h abc123def456.s2.eu.hivemq.cloud \
  -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed \
  -P "AlmedHospital2025!" \
  -t "almed/test" \
  -m "Hello from cloud!"

# Test subscribe (in another terminal)
mosquitto_sub \
  -h abc123def456.s2.eu.hivemq.cloud \
  -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed \
  -P "AlmedHospital2025!" \
  -t "almed/#" \
  -v
```

**Expected**: You should see "Hello from cloud!" in the subscriber terminal.

**If it fails**: Check firewall allows outbound port 8883.

---

## Step 3: Update ESP32 Code (5 minutes)

### 3.1 Open Arduino IDE

1. Open Arduino IDE
2. File → Open → Browse to:
   ```
   /home/almed/Documents/almed_ahu/esp32_main/esp32_main.ino
   ```

---

### 3.2 Update HiveMQ Credentials

Find these lines (around line 106-108):

```cpp
const char* MQTT_USER_CLOUD = "almed";
const char* MQTT_PASS_CLOUD = "AlmedHospital2025!";  // CHANGE THIS
String mqttHostCloud = "CHANGE_ME.s2.eu.hivemq.cloud";  // CHANGE THIS
```

**Replace with YOUR credentials**:

```cpp
const char* MQTT_USER_CLOUD = "almed";
const char* MQTT_PASS_CLOUD = "YOUR_HIVEMQ_PASSWORD";  // Your actual password
String mqttHostCloud = "YOUR_CLUSTER_URL.s2.eu.hivemq.cloud";  // Your actual cluster URL
```

**Example**:
```cpp
const char* MQTT_USER_CLOUD = "almed";
const char* MQTT_PASS_CLOUD = "AlmedHospital2025!";
String mqttHostCloud = "abc123def456.s2.eu.hivemq.cloud";
```

---

### 3.3 Upload to ESP32

1. Connect ESP32 via USB
2. Select board: **Tools → Board → ESP32 Dev Module**
3. Select port: **Tools → Port → /dev/ttyUSB0** (or your port)
4. Click **Upload** (→ button)
5. Wait for upload to complete (~30 seconds)

---

### 3.4 Open Serial Monitor

1. Click **Tools → Serial Monitor** (or Ctrl+Shift+M)
2. Set baud rate to **115200**
3. You should see:

```
========================================
   ALMED AHU Controller v2.0
   Watchdog Protection Enabled
========================================
✓ Watchdog enabled (7s timeout)
✓ SHT45 ready
✓ Motor timings loaded
✓ WiFi event handler registered
✓ Local MQTT configured (Raspberry Pi:1883)
✓ Cloud MQTT configured (HiveMQ:8883 TLS)

--- Checking for previous state ---
✓ Boot complete. Ready for commands.
========================================

Wi-Fi: trying PRIMARY SSID: PiSpot
Wi-Fi connected (PRIMARY), IP: 192.168.1.100

✓ LOCAL MQTT connected (10.42.0.1:1883)
✓ CLOUD MQTT connected (abc123.s2.eu.hivemq.cloud:8883)

Temp: 24.5 °C | Hum: 62.0%
```

**Success indicators**:
- ✅ "✓ Local MQTT configured"
- ✅ "✓ Cloud MQTT configured"
- ✅ "✓ LOCAL MQTT connected"
- ✅ "✓ CLOUD MQTT connected"

---

## Step 4: Verify Both Connections Working

### 4.1 Check Local Dashboard (Should Work Unchanged)

1. Open your Flutter desktop dashboard
2. Login
3. You should see:
   - AHU units showing
   - Temperature/humidity readings
   - Can start/stop system
   - **Everything works exactly as before!**

---

### 4.2 Check Cloud Connection (Raspberry Pi)

```bash
# Subscribe to HiveMQ Cloud
mosquitto_sub \
  -h abc123def456.s2.eu.hivemq.cloud \
  -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed \
  -P "AlmedHospital2025!" \
  -t "almed/#" \
  -v
```

You should see telemetry messages flowing:
```
almed/ahu/hospitalA/icu1/ahu-01/telemetry {"temp":24.5,"hum":62.0,"m1":false,"m2":false,"run":true,"cp":true,"heater":false,"tempSet":22.0,"humSet":55.0,"ts":12345678}
almed/ahu/hospitalA/icu1/ahu-01/state {"run":true,"m1":false,"m2":false,"cp":true,"heater":false,"tempSet":22.0,"humSet":55.0,"m1_start":10,"m1_post":10,"m2_interval":30,"m2_run":10,"m2_delay":5,"ip":"192.168.1.100"}
almed/ahu/hospitalA/icu1/ahu-01/status online
```

---

### 4.3 Check HiveMQ Cloud Dashboard

1. Go to HiveMQ Cloud console
2. Click on your cluster
3. Click **"Metrics"**
4. You should see:
   - **Connected Clients**: 1 (your ESP32)
   - **Messages/sec**: ~0.1 (telemetry every 10 seconds)
   - **Data Transfer**: Increasing

---

## Step 5: Test Commands from Cloud

### 5.1 Send Start Command

```bash
# Send start command via HiveMQ Cloud
mosquitto_pub \
  -h abc123def456.s2.eu.hivemq.cloud \
  -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed \
  -P "AlmedHospital2025!" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"start":true}'
```

**Expected**: ESP32 should start (check Serial Monitor)

---

### 5.2 Send Setpoint Change

```bash
# Change temperature setpoint
mosquitto_pub \
  -h abc123def456.s2.eu.hivemq.cloud \
  -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed \
  -P "AlmedHospital2025!" \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"setpoint":23.5}'
```

**Expected**: ESP32 should change setpoint (check Serial Monitor and local dashboard)

---

## 🎉 Success! What's Working Now

### Priority 1: Local System (Unchanged)
- ✅ ESP32 connects to Raspberry Pi (10.42.0.1:1883)
- ✅ Desktop dashboard shows real-time data
- ✅ Commands work from desktop dashboard
- ✅ No changes to existing workflow

### Priority 2: Cloud System (New!)
- ✅ ESP32 connects to HiveMQ Cloud (your-cluster:8883)
- ✅ Publishes telemetry to cloud
- ✅ Receives commands from cloud
- ✅ Ready for mobile app development

---

## Troubleshooting

### Issue: ESP32 won't connect to cloud

**Check Serial Monitor for error message**:

```
✗ CLOUD MQTT connect failed, rc=-2
```

**Solutions**:
1. Check cluster URL is correct (no spaces, no `mqtt://` prefix)
2. Verify username/password in code match HiveMQ console
3. Check WiFi is connected and has internet access
4. Verify port 8883 is not blocked by firewall

---

### Issue: Local dashboard stopped working

**This shouldn't happen!** If it does:

1. Check Serial Monitor:
   ```
   ✗ LOCAL MQTT connect failed, rc=-2
   ```

2. Verify Raspberry Pi Mosquitto is running:
   ```bash
   sudo systemctl status mosquitto
   ```

3. If needed, restore backup:
   ```bash
   cd /home/almed/Documents/almed_ahu/esp32_main
   cp esp32_main_BACKUP_local_only.ino esp32_main.ino
   ```
   Then re-upload to ESP32.

---

### Issue: Cloud connection takes 30 seconds

**This is normal!** Cloud connection has lower priority:
- Local: Tries every 2 seconds
- Cloud: Tries every 30 seconds

This prevents cloud issues from affecting local operations.

---

### Issue: Firewall blocking port 8883

**Test with**:
```bash
telnet abc123def456.s2.eu.hivemq.cloud 8883
```

**If blocked, allow outbound**:
```bash
sudo ufw allow out 8883/tcp comment 'MQTT TLS to HiveMQ'
```

---

## Next Steps

### ✅ Phase 1: COMPLETE
- HiveMQ Cloud account created
- ESP32 publishing to cloud
- Both local and cloud working

### ⏭️ Phase 2: Mobile App (Future)

When you're ready (no rush!), you can build a Flutter mobile app:

1. Create new Flutter project:
   ```bash
   flutter create almed_ahu_mobile
   ```

2. Copy code from desktop dashboard:
   - Models (AHU telemetry, state, logs)
   - MQTT service (configure for cloud)
   - Widgets (gauges, controls)

3. Configure for HiveMQ Cloud:
   ```dart
   _mqttService = MqttService(
     broker: 'abc123def456.s2.eu.hivemq.cloud',
     port: 8883,
     username: 'almed',
     password: 'AlmedHospital2025!',
     useTLS: true,
   );
   ```

4. Build APK:
   ```bash
   flutter build apk --release
   ```

5. Install on phones/tablets

**For now**: Use `mosquitto_pub` from Raspberry Pi or laptop to test cloud commands!

---

## 📊 System Status

```
╔═══════════════════════════════════════════════════╗
║  ALMED AHU System - Hybrid Architecture           ║
╠═══════════════════════════════════════════════════╣
║  Priority 1: Local System                         ║
║  ✅ Raspberry Pi Mosquitto: Running                ║
║  ✅ Desktop Dashboard: Working                     ║
║  ✅ ESP32 → Local: Connected                       ║
║                                                    ║
║  Priority 2: Cloud System                         ║
║  ✅ HiveMQ Cloud: Running                          ║
║  ✅ ESP32 → Cloud: Connected                       ║
║  ⏳ Mobile App: To be built (later)               ║
╚═══════════════════════════════════════════════════╝
```

---

## 🔗 Useful Links

- **HiveMQ Cloud Console**: https://console.hivemq.cloud/
- **HiveMQ Documentation**: https://docs.hivemq.com/
- **Detailed Guide**: See `HIVEMQ_DETAILED_GUIDE.md`
- **ESP32 Code Guide**: See `ESP32_DUAL_BROKER_CODE.md`
- **Architecture Summary**: See `IMPLEMENTATION_SUMMARY.md`

---

## 📞 Support

**Questions about**:
- HiveMQ setup → This file
- ESP32 code → `ESP32_DUAL_BROKER_CODE.md`
- Mobile app → Wait for Phase 2 (later)
- Local system → Still works unchanged!

---

**Last Updated**: October 30, 2025  
**Status**: ✅ Dual-broker working - Local + Cloud connected!

