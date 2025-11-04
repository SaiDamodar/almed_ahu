# AWS Infrastructure Setup - What's Been Done

## ✅ Successfully Completed

### 1. AWS IoT Core Setup
- ✅ **IoT Endpoint:** `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
- ✅ **Thing Type:** `AHUDevice` created
- ✅ **Bridge Certificate:** Created and saved
  - Certificate ARN: `arn:aws:iot:ap-south-1:502360276622:cert/258f8c17aa38a6474121603339a6b645c095030ff7b1a623344e1bf483b7e070`
  - Location: `aws_migration/device_certs/bridge-pi/`
  - Files created:
    - `certificate.pem`
    - `private-key.pem`
    - `public-key.pem`
    - `AmazonRootCA1.pem`

### 2. DynamoDB Tables
- ✅ **ahu-device-state** - Created (for device real-time state)
- ✅ **ahu-user-assignments** - Created (for user device assignments)

### 3. Configuration Files Updated
- ✅ `mqtt_bridge_aws.py` - Updated with IoT endpoint: `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`

---

## ⚠️ Manual Steps Required

### 1. Create IoT Policy (5 minutes)

**Option A: Via AWS Console**
1. Go to: https://console.aws.amazon.com/iot/home?region=ap-south-1#/policy
2. Click "Create policy"
3. Policy name: `AHUDevicePolicy`
4. Copy and paste this policy document:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iot:Connect"
      ],
      "Resource": "arn:aws:iot:ap-south-1:*:client/${iot:ClientId}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iot:Publish",
        "iot:Subscribe",
        "iot:Receive"
      ],
      "Resource": "arn:aws:iot:ap-south-1:*:topic/almed/ahu/*"
    }
  ]
}
```
5. Click "Create"

**Option B: Via CLI** (after creating policy file)
```bash
aws iot create-policy --policy-name AHUDevicePolicy --policy-document file://aws_migration/device-policy.json --region ap-south-1
```

**Then attach policy to bridge certificate:**
```bash
aws iot attach-policy --policy-name AHUDevicePolicy --target arn:aws:iot:ap-south-1:502360276622:cert/258f8c17aa38a6474121603339a6b645c095030ff7b1a623344e1bf483b7e070 --region ap-south-1
```

### 2. Create Cognito User Pool (5 minutes)

1. Go to: https://console.aws.amazon.com/cognito/home?region=ap-south-1
2. Click "Create user pool"
3. Pool name: `almed-ahu-users`
4. Password policy:
   - Minimum length: 8
   - ✅ Require uppercase
   - ✅ Require lowercase
   - ✅ Require numbers
   - ✅ Require symbols
5. Auto-verified attributes: ✅ Email
6. Click "Create pool"

**After creating pool:**
1. Click "Add an app client"
2. Client name: `ahu-dashboard-client`
3. Authentication flows:
   - ✅ ALLOW_USER_PASSWORD_AUTH
   - ✅ ALLOW_REFRESH_TOKEN_AUTH
4. Click "Create app client"

**Save these values:**
- User Pool ID: `ap-south-1_XXXXXXXXX` (copy from pool details)
- Client ID: `your-client-id` (copy from app client)

### 3. Create Timestream Database (5 minutes)

**Note:** Timestream may need activation first

1. Go to: https://console.aws.amazon.com/timestream/home?region=ap-south-1
2. If you see activation prompt, click "Activate" first
3. Click "Create database"
4. Database name: `ahu_telemetry`
5. Click "Create"
6. After database is created, click "Create table"
7. Table name: `sensor_data`
8. Retention:
   - Memory store: 730 hours (30 days)
   - Magnetic store: 36500 days (100 years)
9. Click "Create"

### 4. Create IoT Rules (10 minutes)

**After Timestream is ready:**

1. Go to: https://console.aws.amazon.com/iot/home?region=ap-south-1#/act/rules
2. Click "Create rule"

**Rule 1: Temperature to Timestream**
- Rule name: `ahu-telemetry-temp-to-timestream`
- SQL query:
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
- Action: Timestream → Write to single measure
  - Database: `ahu_telemetry`
  - Table: `sensor_data`
  - Dimensions: device_id, site, room
  - Measure name: `temperature`
  - Timestamp: `time`

**Rule 2: Humidity to Timestream**
- Rule name: `ahu-telemetry-hum-to-timestream`
- SQL query:
```sql
SELECT 
  topic(4) as device_id,
  topic(2) as site,
  topic(3) as room,
  hum as measure_value::double,
  'humidity' as measure_name,
  timestamp() as time
FROM 'almed/ahu/+/+/+/telemetry'
```
- Action: Timestream (same as above, measure name: `humidity`)

**Rule 3: State to DynamoDB**
- Rule name: `ahu-state-to-dynamodb`
- SQL query:
```sql
SELECT 
  topic(4) as device_id,
  topic(2) as site,
  topic(3) as room,
  * as state
FROM 'almed/ahu/+/+/+/state'
```
- Action: DynamoDBv2 → Put item
  - Table: `ahu-device-state`
  - Partition key: `device_id` (String: ${device_id})
  - Attributes: site, room, state, timestamp

---

## 📋 Configuration Values to Save

After completing manual steps, save these values:

### Already Have:
- ✅ **IoT Endpoint:** `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
- ✅ **Bridge Certificate:** `aws_migration/device_certs/bridge-pi/`

### Need to Get:
- ⚠️ **User Pool ID:** `ap-south-1_XXXXXXXXX` (from Cognito)
- ⚠️ **Client ID:** `your-client-id` (from Cognito)

---

## 🚀 Next Steps After Manual Setup

### 1. Update Flutter Configuration
Edit `ahu_dashboard/lib/services/aws_cognito_service.dart`:
```dart
static const String userPoolId = 'ap-south-1_XXXXXXXXX'; // Your User Pool ID
static const String clientId = 'your-client-id'; // Your Client ID
```

### 2. Copy Bridge Certificates to Raspberry Pi
```bash
scp aws_migration/device_certs/bridge-pi/* pi@your-raspberry-pi:/home/almed/aws-certs/
```

### 3. Update Bridge Configuration
On Raspberry Pi, edit `mqtt_bridge_aws.py`:
```python
AWS_IOT_ROOT_CA = "/home/almed/aws-certs/AmazonRootCA1.pem"
AWS_IOT_CERT = "/home/almed/aws-certs/certificate.pem"
AWS_IOT_KEY = "/home/almed/aws-certs/private-key.pem"
```

### 4. Create Device Certificates
```bash
cd aws_migration
# For Windows PowerShell, use Git Bash or WSL
# Or use the AWS Console to create certificates for each device
```

### 5. Test Bridge Connection
On Raspberry Pi:
```bash
python3 mqtt_bridge_aws.py
```

---

## 📊 Summary

**What's Done:**
- ✅ IoT Core endpoint ready
- ✅ Thing Type created
- ✅ DynamoDB tables created
- ✅ Bridge certificate created
- ✅ Configuration files updated

**What's Left (Manual):**
- ⚠️ IoT Policy (5 min)
- ⚠️ Cognito User Pool (5 min)
- ⚠️ Timestream Database (5 min)
- ⚠️ IoT Rules (10 min)

**Total Time:** ~25 minutes to complete

---

**Last Updated:** 2025-11-04 14:30 IST

