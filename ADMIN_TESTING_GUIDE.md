# 🎯 Complete Admin Testing Guide - AWS Setup

## ✅ Quick Fixes Applied

### 1. **MQTT Connection Fixed**
- ✅ Changed from HiveMQ Cloud to **Local MQTT (Raspberry Pi)**
- ✅ App now connects to: `192.168.1.100:1883`
- ✅ Raspberry Pi bridge forwards to AWS IoT Core

### 2. **AWS Cognito Integration**
- ✅ Cognito service configured with User Pool: `ap-south-1_LSTShtM9R`
- ✅ Client ID: `5iegqp1lv7umgmk609b03kjqhp`
- ⚠️  User creation requires AWS Console or CLI (explained below)

---

## 🔧 STEP 1: Fix MQTT Connection

### Problem
**Error:** "Connection Failed - Could not connect to MQTT broker"

### Solution
Update your **Raspberry Pi IP address** in the code:

#### Option A: Quick Fix (if Pi IP is different)
1. Open: `ahu_dashboard/lib/providers/app_provider.dart`
2. Line 60: Change `192.168.1.100` to your Pi's actual IP
3. Save and restart the app

#### Option B: Find Your Pi's IP
```bash
# On Raspberry Pi:
hostname -I

# Or on Windows (if Pi is on network):
ping raspberrypi.local
```

#### Option C: Use Custom IP When Initializing
In your app code, call:
```dart
await appProvider.initializeMqtt(
  broker: '192.168.1.50', // Your Pi's actual IP
  port: 1883,
  username: 'almed',
  password: 'Almed1234\$',
);
```

### Verify MQTT Broker is Running
On Raspberry Pi:
```bash
# Check if Mosquitto is running
sudo systemctl status mosquitto

# If not running, start it:
sudo systemctl start mosquitto

# Check if AWS bridge is running
python3 ~/mqtt_bridge_aws.py
```

---

## 👥 STEP 2: Create Users (AWS Cognito)

### Problem
**"Can't create users"** - Admin dashboard user creation doesn't work

### Why?
AWS Cognito's Dart package doesn't support admin operations. You must use:
1. **AWS Console** (easiest)
2. **AWS CLI** (for automation)
3. **Backend Lambda API** (for production)

### ✅ Solution A: Use AWS Console (Recommended)

#### Step-by-Step:
1. **Go to Cognito Console:**
   ```
   https://console.aws.amazon.com/cognito/v2/idp/user-pools?region=ap-south-1
   ```

2. **Select Your User Pool:**
   - Click on: `almed-ahu-users` or `ap-south-1_LSTShtM9R`

3. **Go to Users Tab:**
   - Click "Users" in left sidebar

4. **Create User:**
   - Click **"Create user"** button
   - Fill in details:
     - ✅ **Email:** user@example.com
     - ✅ **Temporary Password:** TempPass123!
     - ✅ **Mark email as verified:** ☑️ YES

5. **Add Custom Attributes:**
   Click "Add attribute":
   - **Attribute:** `custom:role`
   - **Value:** `admin` or `client`
   
   Click "Add attribute" again:
   - **Attribute:** `custom:assigned_devices`
   - **Value:** `ahu-01,ahu-02` (comma-separated)

6. **Click "Create user"**

### ✅ Solution B: Use AWS CLI (Faster for Multiple Users)

#### Create Admin User:
```bash
aws cognito-idp admin-create-user \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username admin@hospital.com \
  --user-attributes \
    Name=email,Value=admin@hospital.com \
    Name=email_verified,Value=true \
    Name=custom:role,Value=admin \
  --temporary-password Admin@123456 \
  --message-action SUPPRESS \
  --region ap-south-1
```

#### Create Client User (with Device Assignment):
```bash
aws cognito-idp admin-create-user \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username client@example.com \
  --user-attributes \
    Name=email,Value=client@example.com \
    Name=email_verified,Value=true \
    Name=custom:role,Value=client \
    Name=custom:assigned_devices,Value="ahu-01,ahu-02,ahu-03" \
  --temporary-password Client@123456 \
  --message-action SUPPRESS \
  --region ap-south-1
```

#### Set Permanent Password:
```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username client@example.com \
  --password "ClientPass123!" \
  --permanent \
  --region ap-south-1
```

---

## 🧪 STEP 3: Test Everything as Admin

### Test Plan Checklist

#### ✅ **A. Login Test**
1. **Start the web app** (should already be running)
2. **Login with test account:**
   - Email: `shaikhzaidzaki@gmail.com`
   - Password: `AlMed@123456`
3. **Expected:** Successfully logged in, dashboard appears

#### ✅ **B. MQTT Connection Test**
1. **Check connection indicator** (top right corner)
2. **Expected:** 
   - 🟢 Green = Connected to MQTT
   - 🔴 Red = Connection failed (fix Pi IP address)

#### ✅ **C. Devices Page Test**
1. **Navigate to:** "Devices" page (sidebar)
2. **Check device list:**
   - Should show: `ahu-01`, `ahu-02`, etc.
   - Status: Online/Offline
   - Telemetry: Temperature, Humidity, Fan Speed

3. **Test Device Control:**
   - Click **"Start"** button
   - Expected: Command sent via MQTT
   - Check ESP32 serial monitor for command received

4. **Verify Real-Time Data:**
   - Temperature updates every ~10 seconds
   - Humidity updates
   - Fan speed changes

#### ✅ **D. Overview Page Test**
1. **Navigate to:** "Overview" page
2. **Check Stats Cards:**
   - Total Devices: Should show count
   - Connected Devices: Should show online count
   - Total Users: Should show user count
   - System Status: Operational/Warning/Error

3. **Check Device Grid:**
   - All devices displayed
   - Real-time telemetry visible
   - Status badges (Online/Offline)

#### ✅ **E. Users Page Test (View Only)**
1. **Navigate to:** "Users" page
2. **Check user list:**
   - Shows all Cognito users
   - Displays: Email, Role, Status, Last Login
   - Search functionality works

3. **Try Create User:**
   - Click **"Create User"** button
   - ⚠️  Will show error or info message
   - **Use AWS Console** to create users (see Step 2)

#### ✅ **F. Settings & Permissions Test**
1. **Check Role-Based Access:**
   - Admin: Can see all pages
   - Client: Limited to assigned devices only

2. **Test Device Assignment:**
   - Users only see devices in their `assigned_devices` list
   - Check custom attribute: `custom:assigned_devices`

---

## 📊 STEP 4: Monitor & Debug

### A. Check Browser Console
1. **Press F12** (open Developer Tools)
2. **Go to Console tab**
3. **Look for errors:**
   - MQTT connection errors?
   - Firebase/Cognito errors?
   - Network errors?

### B. Check MQTT Messages
1. **On Raspberry Pi:**
   ```bash
   # Subscribe to all AHU topics
   mosquitto_sub -h localhost -t "almed/ahu/#" -u almed -P 'Almed1234$' -v
   ```

2. **Expected Output:**
   ```
   almed/ahu/hospitalA/icu1/ahu-01/telemetry {"temp":24.5,"hum":55.2,...}
   almed/ahu/hospitalA/icu1/ahu-01/state {"run":true,"fanSpeed":2,...}
   ```

### C. Check AWS IoT Core Messages
1. **Go to AWS IoT Console:**
   ```
   https://console.aws.amazon.com/iot/home?region=ap-south-1#/test
   ```

2. **Subscribe to topic:**
   ```
   almed/ahu/+/+/+/telemetry
   ```

3. **Expected:** Messages appearing in real-time (forwarded by Pi bridge)

### D. Check Cognito Users
```bash
# List all users
aws cognito-idp list-users \
  --user-pool-id ap-south-1_LSTShtM9R \
  --region ap-south-1

# Get specific user details
aws cognito-idp admin-get-user \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username shaikhzaidzaki@gmail.com \
  --region ap-south-1
```

---

## 🐛 STEP 5: Troubleshooting

### Issue 1: "MQTT Connection Failed"

**Possible Causes:**
1. ❌ Wrong Pi IP address
2. ❌ Mosquitto not running
3. ❌ Wrong username/password
4. ❌ Firewall blocking port 1883

**Solutions:**
```bash
# 1. Check Pi IP
hostname -I

# 2. Start Mosquitto
sudo systemctl start mosquitto
sudo systemctl enable mosquitto

# 3. Test MQTT broker
mosquitto_sub -h localhost -t "test" -u almed -P 'Almed1234$'

# 4. Check firewall
sudo ufw status
sudo ufw allow 1883/tcp
```

### Issue 2: "Can't See Devices"

**Possible Causes:**
1. ❌ No devices publishing data
2. ❌ MQTT connection failed
3. ❌ Wrong MQTT topics

**Solutions:**
```bash
# 1. Check if ESP32 is publishing
# On ESP32, check Serial Monitor for:
# "Published telemetry to almed/ahu/..."

# 2. Test manual publish
mosquitto_pub -h localhost -t "almed/ahu/hospitalA/icu1/ahu-01/telemetry" \
  -m '{"temp":25,"hum":60,"fanSpeed":2}' -u almed -P 'Almed1234$'

# 3. Check if dashboard receives it
# Open browser console, should see: "Telemetry received for ahu-01"
```

### Issue 3: "Login Works But Can't See Data"

**Possible Causes:**
1. ❌ User has no assigned devices
2. ❌ Custom attributes not set

**Solutions:**
```bash
# Update user attributes
aws cognito-idp admin-update-user-attributes \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username user@example.com \
  --user-attributes \
    Name=custom:assigned_devices,Value="ahu-01,ahu-02" \
  --region ap-south-1
```

### Issue 4: "Devices Show But No Real-Time Updates"

**Possible Causes:**
1. ❌ ESP32 not publishing
2. ❌ Bridge not forwarding
3. ❌ WebSocket issues

**Solutions:**
```bash
# Check bridge status on Pi
ps aux | grep mqtt_bridge

# Restart bridge
pkill -f mqtt_bridge_aws.py
python3 ~/mqtt_bridge_aws.py &

# Check ESP32 publishing rate
# Should publish every 10 seconds
```

---

## 📋 STEP 6: What to Check Daily

### Morning Checklist:
- [ ] All devices online?
- [ ] MQTT broker running on Pi?
- [ ] AWS IoT Core receiving messages?
- [ ] No errors in browser console?
- [ ] Real-time data updating?

### Weekly Checklist:
- [ ] Review user access logs
- [ ] Check AWS Cognito for unauthorized users
- [ ] Verify device assignments are correct
- [ ] Test backup MQTT broker (if configured)
- [ ] Review AWS IoT Core message logs

---

## 🎯 STEP 7: Key Files & Configuration

### Important Files:
```
ahu_dashboard/
├── lib/
│   ├── services/
│   │   ├── aws_cognito_service.dart     ← Cognito auth
│   │   ├── mqtt_service.dart            ← MQTT client
│   │   └── firebase_service.dart        ← Legacy (not used)
│   ├── providers/
│   │   └── app_provider.dart            ← MQTT init (line 60)
│   └── screens/
│       ├── admin_dashboard_screen.dart  ← Main admin UI
│       └── admin_pages/
│           ├── overview_page.dart       ← Dashboard stats
│           ├── users_page.dart          ← User management
│           └── devices_page.dart        ← Device control

aws_migration/
├── mqtt_bridge_aws.py                   ← Pi bridge script
├── device_certs/                        ← AWS IoT certs
└── COMPLETE_SETUP_SUMMARY.md           ← AWS setup guide
```

### Configuration Values:
```dart
// AWS Cognito
User Pool ID: ap-south-1_LSTShtM9R
Client ID: 5iegqp1lv7umgmk609b03kjqhp
Region: ap-south-1

// MQTT Broker (Raspberry Pi)
Broker: 192.168.1.100  ← UPDATE THIS!
Port: 1883
Username: almed
Password: Almed1234$

// AWS IoT Core
Endpoint: al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com

// Test User
Email: shaikhzaidzaki@gmail.com
Password: AlMed@123456
Role: admin
```

---

## 🚀 Quick Start Commands

### Start Everything:
```bash
# 1. On Raspberry Pi (start MQTT broker and bridge)
sudo systemctl start mosquitto
python3 ~/mqtt_bridge_aws.py &

# 2. On Windows (start Flutter web app)
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
flutter run -d chrome

# 3. On ESP32 (verify publishing)
# Upload firmware and check Serial Monitor
```

### Create a Test User:
```bash
# Quick test user
aws cognito-idp admin-create-user \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username test@example.com \
  --user-attributes \
    Name=email,Value=test@example.com \
    Name=email_verified,Value=true \
    Name=custom:role,Value=client \
    Name=custom:assigned_devices,Value="ahu-01" \
  --temporary-password Test@123456 \
  --message-action SUPPRESS \
  --region ap-south-1

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username test@example.com \
  --password "TestUser123!" \
  --permanent \
  --region ap-south-1
```

---

## ✅ Success Criteria

Your system is working properly when:

1. ✅ **Login** - Can login with Cognito credentials
2. ✅ **MQTT** - Green indicator showing "Connected"
3. ✅ **Devices** - All devices visible with status
4. ✅ **Real-Time** - Temperature/humidity updating every ~10s
5. ✅ **Control** - Start/Stop commands work
6. ✅ **AWS IoT** - Messages visible in AWS IoT Console
7. ✅ **Users** - Can view users (create via Console/CLI)
8. ✅ **Roles** - Admin sees all, clients see assigned devices only

---

## 📞 Support & Next Steps

### If Everything Works:
1. ✅ Document your Pi's IP address
2. ✅ Create production users in Cognito
3. ✅ Configure AWS IoT Rules for Timestream
4. ✅ Set up monitoring and alerts
5. ✅ Deploy to production environment

### If Issues Persist:
1. Check all configuration values
2. Verify network connectivity
3. Review error logs
4. Test each component individually
5. Contact support with specific error messages

---

## 🔗 Useful Links

- **AWS Cognito Console:** https://console.aws.amazon.com/cognito/v2/idp/user-pools?region=ap-south-1
- **AWS IoT Console:** https://console.aws.amazon.com/iot/home?region=ap-south-1
- **AWS IoT Test Client:** https://console.aws.amazon.com/iot/home?region=ap-south-1#/test
- **DynamoDB Tables:** https://console.aws.amazon.com/dynamodbv2/home?region=ap-south-1#tables

---

**Last Updated:** 2025-11-04  
**Status:** ✅ Ready for Testing  
**Next:** Follow testing steps above to verify everything works!

