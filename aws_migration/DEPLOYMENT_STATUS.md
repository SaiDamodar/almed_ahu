# AWS Infrastructure Deployment Status

## ✅ Successfully Created

### 1. IoT Core Endpoint
- **Endpoint:** `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
- **Region:** ap-south-1
- **Status:** ✅ Ready to use

### 2. IoT Thing Type
- **Name:** AHUDevice
- **ARN:** arn:aws:iot:ap-south-1:502360276622:thingtype/AHUDevice
- **Status:** ✅ Created

### 3. DynamoDB Tables
- **Table:** `ahu-device-state`
  - Status: ✅ Created (CREATING)
  - Key: device_id (String)
  - Billing: PAY_PER_REQUEST
  
- **Table:** `ahu-user-assignments`
  - Status: ✅ Created (CREATING)
  - Key: user_id (String)
  - Billing: PAY_PER_REQUEST

---

## ⚠️ Needs Manual Completion

### 1. IoT Policy
**Issue:** Policy document formatting issue

**Manual Steps:**
1. Go to AWS Console → IoT Core → Security → Policies
2. Click "Create policy"
3. Policy name: `AHUDevicePolicy`
4. Policy document:
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

**Or via CLI:**
```bash
aws iot create-policy --policy-name AHUDevicePolicy --policy-document file://device-policy.json --region ap-south-1
```

### 2. Cognito User Pool
**Issue:** PowerShell parameter parsing

**Manual Steps:**
1. Go to AWS Console → Cognito → User Pools
2. Click "Create user pool"
3. Pool name: `almed-ahu-users`
4. Password policy:
   - Minimum length: 8
   - Require uppercase: Yes
   - Require lowercase: Yes
   - Require numbers: Yes
   - Require symbols: Yes
5. Auto-verified attributes: Email
6. Click "Create pool"

**Or via CLI:**
```bash
aws cognito-idp create-user-pool \
  --pool-name almed-ahu-users \
  --policies file://cognito-password-policy.json \
  --auto-verified-attributes email \
  --region ap-south-1
```

### 3. Cognito User Pool Client
**After creating User Pool:**
1. Go to AWS Console → Cognito → User Pools → Your Pool → App clients
2. Click "Add an app client"
3. Client name: `ahu-dashboard-client`
4. Authentication flows:
   - ✅ ALLOW_USER_PASSWORD_AUTH
   - ✅ ALLOW_REFRESH_TOKEN_AUTH
5. Click "Create app client"

**Save these values:**
- User Pool ID: `ap-south-1_XXXXXXXXX`
- Client ID: `your-client-id`

### 4. Timestream Database
**Issue:** Subscription required (needs activation)

**Manual Steps:**
1. Go to AWS Console → Timestream
2. Click "Create database"
3. Database name: `ahu_telemetry`
4. Click "Create"
5. After database is created, click "Create table"
6. Table name: `sensor_data`
7. Retention:
   - Memory store: 730 hours (30 days)
   - Magnetic store: 36500 days (100 years)
8. Click "Create"

**Note:** Timestream may require account activation. If you see an error, activate it in the AWS Console first.

### 5. IoT Rules
**After Timestream is ready:**
1. Go to AWS Console → IoT Core → Act → Rules
2. Click "Create rule"

**Rule 1: Telemetry to Timestream (Temperature)**
- Rule name: `ahu-telemetry-to-timestream`
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
  - Measure name: temperature
  - Timestamp: time

**Rule 2: Telemetry to Timestream (Humidity)**
- Rule name: `ahu-humidity-to-timestream`
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
- Action: Timestream (same as above, but measure name: humidity)

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
  - Partition key: device_id (String: ${device_id})
  - Attributes: site, room, state, timestamp

---

## 📋 Next Steps

### 1. Complete Manual Steps Above
- Create IoT Policy
- Create Cognito User Pool
- Create Cognito User Pool Client
- Create Timestream Database
- Create IoT Rules

### 2. Get Configuration Values
After completing manual steps, save:
- IoT Endpoint: `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com` ✅
- User Pool ID: `ap-south-1_XXXXXXXXX` (get from Cognito)
- Client ID: `your-client-id` (get from Cognito)

### 3. Create Certificates
```bash
cd aws_migration
chmod +x create_device_certificates.sh
./create_device_certificates.sh bridge-pi
./create_device_certificates.sh ahu-01
```

### 4. Update Configuration Files
- `mqtt_bridge_aws.py` - Update IoT endpoint
- `esp32_aws_integration.h` - Update IoT endpoint
- `aws_cognito_service.dart` - Update User Pool ID and Client ID

---

## 📊 Current Status Summary

| Resource | Status | Notes |
|----------|--------|-------|
| IoT Core Endpoint | ✅ Ready | `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com` |
| IoT Thing Type | ✅ Created | AHUDevice |
| DynamoDB Tables | ✅ Created | Both tables created |
| IoT Policy | ⚠️ Manual | Need to create via Console |
| Cognito User Pool | ⚠️ Manual | Need to create via Console |
| Cognito Client | ⚠️ Manual | After User Pool |
| Timestream DB | ⚠️ Manual | May need activation |
| IoT Rules | ⚠️ Manual | After Timestream ready |

---

## 🎯 Quick Actions

**To complete setup:**
1. Go to AWS Console
2. Complete manual steps above
3. Run certificate creation script
4. Update configuration files

**Estimated time:** 15-20 minutes

---

**Last Updated:** 2025-11-04

