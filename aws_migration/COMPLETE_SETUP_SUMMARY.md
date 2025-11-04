# Complete AWS Setup Summary - Everything You Need

## ✅ What Has Been Done

### 1. AWS Infrastructure Created

#### ✅ Cognito User Pool
- **User Pool ID:** `ap-south-1_LSTShtM9R`
- **User Pool Name:** `almed-ahu-users`
- **Region:** `ap-south-1` (Mumbai)
- **Status:** ✅ Created and Active

#### ✅ Cognito App Client
- **Client ID:** `5iegqp1lv7umgmk609b03kjqhp`
- **Client Name:** `ahu-dashboard-client`
- **Authentication Flows:**
  - ✅ ALLOW_USER_PASSWORD_AUTH
  - ✅ ALLOW_REFRESH_TOKEN_AUTH
  - ✅ ALLOW_USER_SRP_AUTH
- **Status:** ✅ Created

#### ✅ Cognito User Account
- **Email:** `shaikhzaidzaki@gmail.com`
- **Password:** `AlMed@123456`
- **Status:** ✅ Created and Active
- **Email Verified:** ✅ Yes
- **Custom Attributes:**
  - `custom:custom:role` = `admin`
  - `custom:custom:assigned_devs` = `ahu-01,ahu-02`
- **Status:** ✅ Ready to use

#### ✅ IoT Core Resources
- **IoT Endpoint:** `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
- **Thing Type:** `AHUDevice` ✅ Created
- **Bridge Certificate:** ✅ Created (in `aws_migration/device_certs/bridge-pi/`)

#### ✅ DynamoDB Tables
- **Table:** `ahu-device-state` ✅ Created
- **Table:** `ahu-user-assignments` ✅ Created

---

### 2. Configuration Files Updated

#### ✅ Flutter App Configuration
**File:** `ahu_dashboard/lib/services/aws_cognito_service.dart`
- ✅ User Pool ID: `ap-south-1_LSTShtM9R`
- ✅ Client ID: `5iegqp1lv7umgmk609b03kjqhp`
- ✅ Custom attribute handling updated

#### ✅ Python Bridge Configuration
**File:** `aws_migration/mqtt_bridge_aws.py`
- ✅ IoT Endpoint: `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`

---

## 📋 Important Configuration Values

### Save These Values:

```
User Pool ID: ap-south-1_LSTShtM9R
Client ID: 5iegqp1lv7umgmk609b03kjqhp
Region: ap-south-1
IoT Endpoint: al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com

Test User:
  Email: shaikhzaidzaki@gmail.com
  Password: AlMed@123456
  Role: admin
  Assigned Devices: ahu-01, ahu-02
```

---

## 🚀 How to Run/Test Everything

### Step 1: Test Cognito Login in Flutter App

#### 1.1 Install Dependencies
```bash
cd ahu_dashboard
flutter pub get
```

**Note:** If you see compilation errors related to `web` package (like `typeofEquals` or `hasProperty` not defined), this has been fixed by:
- Adding `web: ^0.4.2` to `dependency_overrides` in `pubspec.yaml`
- Running `flutter clean` and `flutter pub get`

The `web` package has been upgraded from 0.3.0 to 0.4.2 to fix compatibility issues.

#### 1.2 Update Auth Provider
Replace Firebase auth with Cognito in your login screen:

**File:** `ahu_dashboard/lib/providers/app_provider.dart` or your auth provider

```dart
import 'package:ahu_dashboard/services/aws_cognito_service.dart';

// Replace Firebase auth with:
final cognitoService = CognitoService();

// In your login function:
final session = await cognitoService.signIn(
  email: 'shaikhzaidzaki@gmail.com',
  password: 'AlMed@123456',
);

if (session != null) {
  // Login successful!
  // Get user role and assigned devices
  final role = await cognitoService.getUserRole(); // Should return 'admin'
  final devices = await cognitoService.getAssignedDevices(); // Should return ['ahu-01', 'ahu-02']
  
  // Navigate to dashboard
}
```

#### 1.3 Run Flutter App
```bash
# For Android
flutter run

# For Web
flutter run -d chrome

# For Windows
flutter run -d windows
```

#### 1.4 Test Login
1. Enter email: `shaikhzaidzaki@gmail.com`
2. Enter password: `AlMed@123456`
3. Click "Sign In"
4. Should successfully authenticate ✅

---

### Step 2: Test AWS IoT Bridge (Raspberry Pi)

#### 2.1 Copy Certificates to Raspberry Pi
```bash
# On your Windows machine:
scp aws_migration/device_certs/bridge-pi/* pi@your-raspberry-pi:/home/almed/aws-certs/
```

#### 2.2 Update Bridge Configuration
On Raspberry Pi, edit `mqtt_bridge_aws.py`:
```python
AWS_IOT_ROOT_CA = "/home/almed/aws-certs/AmazonRootCA1.pem"
AWS_IOT_CERT = "/home/almed/aws-certs/certificate.pem"
AWS_IOT_KEY = "/home/almed/aws-certs/private-key.pem"
```

#### 2.3 Install Dependencies
```bash
pip3 install paho-mqtt boto3
```

#### 2.4 Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key and Secret Key
```

#### 2.5 Run Bridge
```bash
python3 mqtt_bridge_aws.py
```

**Expected Output:**
```
✓ Connected to LOCAL broker (Raspberry Pi)
✓ Connected to AWS IoT Core
Bridge running...
```

#### 2.6 Test Message Flow
1. ESP32 publishes to local broker: `almed/ahu/hospitalA/icu1/ahu-01/telemetry`
2. Bridge forwards to AWS IoT Core ✅
3. Check AWS IoT Console → Test → MQTT Test client
4. Subscribe to: `almed/ahu/+/+/+/telemetry`
5. Should see messages arriving ✅

---

### Step 3: Test ESP32 Connection (Optional)

#### 3.1 Create ESP32 Device Certificate
```bash
cd aws_migration
# For Windows, use Git Bash or WSL
./create_device_certificates.sh ahu-01
```

#### 3.2 Update ESP32 Code
1. Copy `esp32_aws_integration.h` to your ESP32 project
2. Update certificates in the header file
3. Update endpoint: `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
4. Include in main `.ino`:
```cpp
#include "esp32_aws_integration.h"

void setup() {
  // ... WiFi setup ...
  
  if (WiFi.status() == WL_CONNECTED) {
    initAWSIoT();
    connectToAWS();
  }
}

void loop() {
  maintainAWSConnection();
  
  // Publish telemetry
  if (millis() - lastTelemetryPublish > 10000) {
    String telemetry = createTelemetryJSON();
    publishTelemetryToAWS(telemetry);
    lastTelemetryPublish = millis();
  }
}
```

#### 3.3 Upload and Test
1. Upload firmware to ESP32
2. Monitor Serial output
3. Should see: `✓ Connected to AWS IoT Core`

---

### Step 4: Test Timestream (After Creating Database)

#### 4.1 Create Timestream Database
1. Go to: https://console.aws.amazon.com/timestream/home?region=ap-south-1
2. Click "Create database"
3. Database name: `ahu_telemetry`
4. Click "Create"
5. Create table: `sensor_data`
6. Retention: 730 hours (memory), 36500 days (magnetic)

#### 4.2 Create IoT Rule
1. Go to: https://console.aws.amazon.com/iot/home?region=ap-south-1#/act/rules
2. Create rule: `ahu-telemetry-to-timestream`
3. SQL query:
```sql
SELECT 
  topic(4) as device_id,
  topic(2) as site,
  topic(3) as room,
  temp as measure_value::double,
  'temperature' as measure_name,
  timestamp() as time
FROM 'almed/ahu/+/+/+/telemetry'
```
4. Action: Timestream → Write to single measure
5. Database: `ahu_telemetry`
6. Table: `sensor_data`

#### 4.3 Test Data Flow
1. ESP32 publishes telemetry
2. Bridge forwards to AWS IoT Core
3. IoT Rule routes to Timestream ✅
4. Query Timestream:
```bash
aws timestream-query query \
  --query-string "SELECT * FROM ahu_telemetry.sensor_data WHERE time > ago(1h) LIMIT 10" \
  --region ap-south-1
```

---

## 🔧 Configuration Summary

### Files Modified/Created:

1. ✅ `ahu_dashboard/lib/services/aws_cognito_service.dart` - Updated with User Pool ID and Client ID
2. ✅ `aws_migration/mqtt_bridge_aws.py` - Updated with IoT endpoint
3. ✅ `aws_migration/device_certs/bridge-pi/` - Certificates created
4. ✅ `aws_migration/cognito-user-pool-config.json` - User pool config
5. ✅ `aws_migration/user-attributes.json` - User attributes config

---

## 📊 Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Cognito User Pool | ✅ Created | `ap-south-1_LSTShtM9R` |
| Cognito App Client | ✅ Created | `5iegqp1lv7umgmk609b03kjqhp` |
| Cognito User | ✅ Created | `shaikhzaidzaki@gmail.com` |
| IoT Core Endpoint | ✅ Ready | `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com` |
| IoT Thing Type | ✅ Created | `AHUDevice` |
| Bridge Certificate | ✅ Created | Ready to use |
| DynamoDB Tables | ✅ Created | Both tables active |
| IoT Policy | ⚠️ Manual | Need to create |
| Timestream Database | ⚠️ Manual | Need to create |
| IoT Rules | ⚠️ Manual | Need to create after Timestream |

---

## ⚠️ Remaining Manual Steps

### 1. Create IoT Policy (5 minutes)
**Why:** Required for devices to connect to AWS IoT Core

**Steps:**
1. Go to: https://console.aws.amazon.com/iot/home?region=ap-south-1#/policy
2. Click "Create policy"
3. Policy name: `AHUDevicePolicy`
4. Policy document:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["iot:Connect"],
      "Resource": "arn:aws:iot:ap-south-1:*:client/${iot:ClientId}"
    },
    {
      "Effect": "Allow",
      "Action": ["iot:Publish", "iot:Subscribe", "iot:Receive"],
      "Resource": "arn:aws:iot:ap-south-1:*:topic/almed/ahu/*"
    }
  ]
}
```
5. Click "Create"
6. Attach to bridge certificate:
```bash
aws iot attach-policy --policy-name AHUDevicePolicy \
  --target arn:aws:iot:ap-south-1:502360276622:cert/258f8c17aa38a6474121603339a6b645c095030ff7b1a623344e1bf483b7e070 \
  --region ap-south-1
```

### 2. Create Timestream Database (5 minutes)
**Why:** Store time-series telemetry data

**Steps:**
1. Go to: https://console.aws.amazon.com/timestream/home?region=ap-south-1
2. Activate Timestream (if prompted)
3. Create database: `ahu_telemetry`
4. Create table: `sensor_data`
5. Retention: 730 hours (memory), 36500 days (magnetic)

### 3. Create IoT Rules (10 minutes)
**Why:** Route data from IoT Core to Timestream and DynamoDB

**Steps:**
1. Go to: https://console.aws.amazon.com/iot/home?region=ap-south-1#/act/rules
2. Create 3 rules (see `SETUP_COMPLETE.md` for SQL queries)

---

## 🧪 Testing Checklist

- [ ] Cognito login works in Flutter app
- [ ] User can get role and assigned devices
- [ ] Bridge connects to AWS IoT Core
- [ ] Bridge forwards messages successfully
- [ ] ESP32 connects to AWS IoT Core (if using)
- [ ] Messages appear in AWS IoT Console Test client
- [ ] Timestream receives data (after setup)
- [ ] DynamoDB receives state updates (after setup)

---

## 📱 Quick Test Commands

### Test Cognito Login
```bash
# Test user login via CLI
aws cognito-idp admin-get-user \
  --user-pool-id ap-south-1_LSTShtM9R \
  --username shaikhzaidzaki@gmail.com \
  --region ap-south-1
```

### Test IoT Connection
```bash
# List things
aws iot list-things --region ap-south-1

# Check endpoint
aws iot describe-endpoint --endpoint-type iot:Data-ATS --region ap-south-1
```

### Test DynamoDB
```bash
# List tables
aws dynamodb list-tables --region ap-south-1

# Get table status
aws dynamodb describe-table \
  --table-name ahu-device-state \
  --region ap-south-1
```

---

## 🎯 Next Steps

1. ✅ **Test Cognito login** in Flutter app
2. ⚠️ **Create IoT Policy** (manual step)
3. ⚠️ **Create Timestream Database** (manual step)
4. ⚠️ **Create IoT Rules** (manual step)
5. ✅ **Test bridge connection** (after policy created)
6. ✅ **Test ESP32 connection** (optional)
7. ✅ **Migrate users** from Firebase (if needed)

---

## 🆘 Troubleshooting

### Cognito Login Fails
- Check User Pool ID and Client ID are correct
- Verify user exists and password is correct
- Check network connectivity
- Review Flutter console logs

### Bridge Can't Connect
- Verify IoT Policy is created and attached
- Check certificate paths are correct
- Verify AWS credentials are configured
- Check bridge logs: `journalctl -u mqtt-bridge-aws.service`

### ESP32 Can't Connect
- Verify endpoint is correct
- Check certificates are valid
- Verify WiFi connection
- Check Serial output for errors

---

## 📚 Documentation Files

- `COMPLETE_SETUP_SUMMARY.md` - This file (complete overview)
- `SETUP_COMPLETE.md` - Detailed setup instructions
- `AWS_MIGRATION_GUIDE.md` - Complete migration guide
- `DEPLOYMENT_STATUS.md` - Resource status
- `HOW_TO_VIEW_IN_CONSOLE.md` - Console navigation guide

---

## ✅ Summary

**Everything is ready!** You can now:

1. ✅ **Login to Flutter app** with `shaikhzaidzaki@gmail.com` / `AlMed@123456`
2. ✅ **Use AWS IoT Core** for MQTT messages
3. ✅ **Use Cognito** for authentication
4. ⚠️ **Complete manual steps** (Policy, Timestream, Rules)
5. ✅ **Test everything** using the commands above

**Start with testing Cognito login in your Flutter app!** 🚀

---

**Last Updated:** 2025-11-04 15:00 IST
**Setup by:** AWS CLI Automation
**Status:** ✅ Ready for Testing

