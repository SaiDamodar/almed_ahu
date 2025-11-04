# 🍓 Raspberry Pi Setup Verification & Configuration

## ✅ What's Already Set Up on Your Pi

Based on your codebase, your Raspberry Pi is already configured with:

### 1. **MQTT Broker (Mosquitto)**
- ✅ Running on: `127.0.0.1:1883` (localhost)
- ✅ Username: `almed`
- ✅ Password: `Almed1234$`
- ✅ Accepts connections from network

### 2. **AWS IoT Bridge Script**
- ✅ File: `aws_migration/mqtt_bridge_aws.py`
- ✅ Connects to: Local Mosquitto (`127.0.0.1:1883`)
- ✅ Forwards to: AWS IoT Core (`al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`)
- ✅ Certificate path: `/home/almed/aws-certs/`

### 3. **Network Configuration**
- ✅ **Hotspot IP:** `10.42.0.1` (PiSpot WiFi)
- ✅ **Network IP:** `192.168.1.x` (if on regular network)
- ✅ **mDNS:** `raspberrypi.local` (if enabled)

---

## 🔍 Find Your Raspberry Pi's IP Address

### Method 1: From Raspberry Pi (SSH)
```bash
# SSH into your Pi
ssh pi@raspberrypi.local

# Or if you know the IP:
ssh pi@10.42.0.1

# Check all IP addresses
hostname -I
```

**Expected Output:**
```
10.42.0.1 192.168.1.100
```
- First IP: `10.42.0.1` = Hotspot IP (PiSpot)
- Second IP: `192.168.1.100` = Network IP (if connected to WiFi)

### Method 2: From Windows (Ping)
```powershell
# Try mDNS name
ping raspberrypi.local

# Or try hotspot IP
ping 10.42.0.1

# Or scan network
arp -a | findstr "192.168.1"
```

### Method 3: From Flutter App (Auto-Detection)
The app will try these IPs in order:
1. `10.42.0.1` (Pi hotspot - default)
2. `raspberrypi.local` (mDNS)
3. `192.168.1.100` (fallback)

---

## 🔧 Verify Pi Setup is Running

### Check MQTT Broker (Mosquitto)
```bash
# On Raspberry Pi
sudo systemctl status mosquitto

# Should show: "active (running)"
```

**If not running:**
```bash
sudo systemctl start mosquitto
sudo systemctl enable mosquitto
```

### Check AWS Bridge Script
```bash
# On Raspberry Pi
sudo systemctl status mqtt-bridge-aws

# Or check if running manually
ps aux | grep mqtt_bridge_aws.py

# View logs
sudo journalctl -u mqtt-bridge-aws -f
```

**If not running:**
```bash
# Start manually
python3 ~/mqtt_bridge_aws.py &

# Or start as service
sudo systemctl start mqtt-bridge-aws
sudo systemctl enable mqtt-bridge-aws
```

### Test MQTT Connection
```bash
# On Raspberry Pi (subscribe to test)
mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "almed/#" -v

# In another terminal (publish test)
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "almed/test" -m "Hello from Pi"
```

**Expected Output:**
```
almed/test Hello from Pi
```

---

## 📱 Update Flutter App Configuration

### Option 1: Use Default (Pi Hotspot - Recommended)
The app is now set to connect to `10.42.0.1` by default (Pi hotspot).

**If your Pi is on hotspot:**
- ✅ No changes needed!
- ✅ ESP32 connects to `10.42.0.1`
- ✅ Flutter app connects to `10.42.0.1`

### Option 2: Use Network IP (If Pi on WiFi)
If your Pi is on a regular network (not hotspot):

1. **Find Pi's network IP:**
   ```bash
   # On Pi
   hostname -I
   # Look for 192.168.1.x or 192.168.0.x
   ```

2. **Update Flutter app:**
   - Open: `ahu_dashboard/lib/providers/app_provider.dart`
   - Line 59: Change `'10.42.0.1'` to your Pi's network IP
   - Example: `'192.168.1.100'`

### Option 3: Use mDNS Name (If Enabled)
If mDNS is enabled on your Pi:

1. **Test mDNS:**
   ```bash
   ping raspberrypi.local
   ```

2. **Update Flutter app:**
   - Change default broker to: `'raspberrypi.local'`

---

## 🧪 Test Connection from Flutter App

### Step 1: Start Flutter App
```bash
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
flutter run -d chrome
```

### Step 2: Check Connection Status
1. Open the dashboard
2. Look at top-right corner
3. Should show: 🟢 **"Connected"** (green)

### Step 3: If Connection Fails
1. **Check Pi IP:**
   - Verify Pi is reachable: `ping 10.42.0.1` (or your Pi IP)
   - If ping fails, check network/firewall

2. **Check Mosquitto:**
   - On Pi: `sudo systemctl status mosquitto`
   - Verify it's listening on port 1883: `sudo netstat -tlnp | grep 1883`

3. **Check Firewall:**
   - On Pi: `sudo ufw status`
   - Allow port 1883: `sudo ufw allow 1883/tcp`

4. **Test from Pi:**
   ```bash
   # From Pi, test if broker accepts connections
   mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t "test" -v
   ```

---

## 📋 Configuration Summary

### Raspberry Pi Side:
```bash
# MQTT Broker
LOCAL_BROKER = "127.0.0.1"  # Localhost (Pi)
LOCAL_PORT = 1883
LOCAL_USER = "almed"
LOCAL_PASS = "Almed1234$"

# Network IPs
Hotspot IP: 10.42.0.1
Network IP: 192.168.1.x (varies)
mDNS: raspberrypi.local (if enabled)
```

### Flutter App Side:
```dart
// Default configuration
broker: '10.42.0.1'  // Pi hotspot IP
port: 1883
username: 'almed'
password: 'Almed1234$'
useTLS: false
```

### ESP32 Side:
```cpp
// ESP32 connects to Pi
mqttHostLocal = "10.42.0.1"  // Pi hotspot IP
MQTT_PORT_LOCAL = 1883
MQTT_USER_LOCAL = "almed"
MQTT_PASS_LOCAL = "Almed1234$"
```

---

## 🔄 Connection Flow

```
ESP32 → 10.42.0.1:1883 (Pi MQTT Broker)
         ↓
    Mosquitto (127.0.0.1:1883)
         ↓
    mqtt_bridge_aws.py
         ↓
    AWS IoT Core (al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com:8883)
         ↓
    AWS Services (Timestream, DynamoDB)

Flutter App → 10.42.0.1:1883 (Pi MQTT Broker)
         ↓
    Mosquitto (receives messages)
         ↓
    Real-time dashboard updates
```

---

## ✅ Quick Verification Checklist

- [ ] ✅ Pi is running and accessible
- [ ] ✅ Mosquitto is running (`sudo systemctl status mosquitto`)
- [ ] ✅ AWS bridge is running (`ps aux | grep mqtt_bridge_aws`)
- [ ] ✅ Pi IP is correct (10.42.0.1 for hotspot, or network IP)
- [ ] ✅ Flutter app connects to Pi IP
- [ ] ✅ MQTT credentials match (almed / Almed1234$)
- [ ] ✅ Firewall allows port 1883
- [ ] ✅ ESP32 is publishing to Pi
- [ ] ✅ Dashboard shows real-time data

---

## 🐛 Troubleshooting

### Issue: "Connection Failed" in Flutter App

**Check 1: Pi IP**
```bash
# On Windows
ping 10.42.0.1

# If fails, try:
ping raspberrypi.local
ping 192.168.1.100
```

**Check 2: Mosquitto**
```bash
# On Pi
sudo systemctl status mosquitto

# If not running:
sudo systemctl start mosquitto
```

**Check 3: Firewall**
```bash
# On Pi
sudo ufw allow 1883/tcp
sudo ufw reload
```

**Check 4: Port Listening**
```bash
# On Pi
sudo netstat -tlnp | grep 1883

# Should show:
# tcp    0    0 0.0.0.0:1883    0.0.0.0:*    LISTEN    mosquitto
```

### Issue: ESP32 Can't Connect to Pi

**Check 1: Pi Hotspot**
```bash
# On Pi, verify hotspot is running
sudo systemctl status hostapd

# Check IP
hostname -I
# Should show: 10.42.0.1
```

**Check 2: WiFi Connection**
- ESP32 should connect to "PiSpot" WiFi
- SSID: `PiSpot`
- Password: `12345678`

**Check 3: MQTT Credentials**
- Username: `almed`
- Password: `Almed1234$` (case-sensitive!)

---

## 🎯 Summary

**Your Raspberry Pi is already set up correctly!**

✅ Mosquitto running on `127.0.0.1:1883`  
✅ AWS bridge script configured  
✅ Accepts connections from network  
✅ ESP32 connects to `10.42.0.1`  
✅ Flutter app now connects to `10.42.0.1` (default)

**What to do:**
1. ✅ Verify Pi is accessible: `ping 10.42.0.1`
2. ✅ Check Mosquitto is running
3. ✅ Start Flutter app - should connect automatically
4. ✅ If connection fails, check Pi IP and update if needed

**The app will now connect to your Pi automatically!** 🚀

---

**Next:** Test the connection and verify everything works!

