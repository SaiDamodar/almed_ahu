# AWS IoT Migration Guide - Complete Step-by-Step

This guide walks you through migrating from HiveMQ + InfluxDB + Firebase to AWS IoT Core.

---

## 📋 Prerequisites

1. **AWS Account** (with billing enabled)
2. **AWS CLI installed and configured**
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, Region (ap-south-1), Output format (json)
   ```
3. **Python 3.7+** (for bridge script)
4. **ESP32 development environment** (Arduino IDE or PlatformIO)
5. **Flutter SDK** (for dashboard updates)

---

## 🚀 Phase 1: AWS Infrastructure Setup (Day 1)

### Step 1.1: Deploy CloudFormation Stack

```bash
cd aws_migration
chmod +x setup_aws_infrastructure.sh
./setup_aws_infrastructure.sh
```

This will create:
- ✅ IoT Core endpoint
- ✅ Timestream database and table
- ✅ DynamoDB tables
- ✅ Cognito User Pool
- ✅ IoT Rules (Timestream, DynamoDB)
- ✅ IAM roles

**Save the outputs:**
- IoT Endpoint
- User Pool ID
- User Pool Client ID

### Step 1.2: Verify Infrastructure

```bash
# Check IoT endpoint
aws iot describe-endpoint --endpoint-type iot:Data-ATS --region ap-south-1

# List Timestream databases
aws timestream-write list-databases --region ap-south-1

# List DynamoDB tables
aws dynamodb list-tables --region ap-south-1

# List Cognito User Pools
aws cognito-idp list-user-pools --max-results 10 --region ap-south-1
```

---

## 🔐 Phase 2: Create Device Certificates (Day 2)

### Step 2.1: Create Certificate for Bridge (Raspberry Pi)

```bash
cd aws_migration
chmod +x create_device_certificates.sh
./create_device_certificates.sh bridge-pi
```

This creates:
- `device_certs/bridge-pi/certificate.pem`
- `device_certs/bridge-pi/private-key.pem`
- `device_certs/bridge-pi/AmazonRootCA1.pem`

**Copy these to your Raspberry Pi:**
```bash
scp device_certs/bridge-pi/* pi@your-raspberry-pi:/home/almed/aws-certs/
```

### Step 2.2: Create Certificates for Each ESP32 Device

```bash
./create_device_certificates.sh ahu-01
./create_device_certificates.sh ahu-02
# ... repeat for all devices
```

**For each device:**
1. Copy certificate files to ESP32 project
2. Update ESP32 code with endpoint and certificates
3. Flash firmware to device

---

## 🐍 Phase 3: Update Python Bridge (Day 3)

### Step 3.1: Install Dependencies

On your Raspberry Pi:
```bash
pip3 install paho-mqtt boto3
```

### Step 3.2: Update Bridge Configuration

Edit `mqtt_bridge_aws.py`:
```python
# Update these values:
AWS_IOT_ENDPOINT = "YOUR_ENDPOINT.iot.ap-south-1.amazonaws.com"
AWS_IOT_ROOT_CA = "/home/almed/aws-certs/AmazonRootCA1.pem"
AWS_IOT_CERT = "/home/almed/aws-certs/bridge-cert.pem"
AWS_IOT_KEY = "/home/almed/aws-certs/bridge-private-key.pem"
```

### Step 3.3: Configure AWS Credentials

```bash
aws configure
# Or use IAM role if running on EC2
```

### Step 3.4: Test Bridge

```bash
python3 mqtt_bridge_aws.py
```

You should see:
```
✓ Connected to LOCAL broker (Raspberry Pi)
✓ Connected to AWS IoT Core
Bridge running...
```

### Step 3.5: Create Systemd Service

```bash
sudo nano /etc/systemd/system/mqtt-bridge-aws.service
```

Add:
```ini
[Unit]
Description=MQTT Bridge to AWS IoT Core
After=network.target mosquitto.service

[Service]
Type=simple
User=almed
WorkingDirectory=/home/almed/Documents/almed_ahu
ExecStart=/usr/bin/python3 /home/almed/Documents/almed_ahu/aws_migration/mqtt_bridge_aws.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable mqtt-bridge-aws.service
sudo systemctl start mqtt-bridge-aws.service
sudo systemctl status mqtt-bridge-aws.service
```

---

## 📱 Phase 4: Update ESP32 Code (Day 4)

### Step 4.1: Add AWS IoT Integration

1. Copy `esp32_aws_integration.h` to your ESP32 project
2. Include in your main `.ino` file:
   ```cpp
   #include "esp32_aws_integration.h"
   ```

### Step 4.2: Update Certificates

In `esp32_aws_integration.h`:
1. Replace `AWS_IOT_ENDPOINT` with your endpoint
2. Replace `DEVICE_CERT` with your device certificate
3. Replace `DEVICE_KEY` with your device private key
4. Keep `AWS_ROOT_CA` as is (or download from Amazon)

### Step 4.3: Integrate in Main Code

In `setup()`:
```cpp
void setup() {
  // ... existing WiFi setup ...
  
  // After WiFi connects:
  if (WiFi.status() == WL_CONNECTED) {
    initAWSIoT();
    delay(1000);
    connectToAWS();
  }
}
```

In `loop()`:
```cpp
void loop() {
  // Maintain AWS connection
  maintainAWSConnection();
  
  // Replace mqttCloud.publish() with:
  if (millis() - lastTelemetryPublish > 10000) {
    String telemetry = createTelemetryJSON();
    publishTelemetryToAWS(telemetry);
    lastTelemetryPublish = millis();
  }
}
```

### Step 4.4: Upload and Test

1. Upload firmware to ESP32
2. Monitor Serial output
3. Verify connection to AWS IoT Core
4. Check AWS IoT Console → Monitor → MQTT Test client

---

## 📱 Phase 5: Update Flutter Dashboard (Days 5-6)

### Step 5.1: Add Dependencies

Edit `ahu_dashboard/pubspec.yaml`:
```yaml
dependencies:
  # AWS Services
  amazon_cognito_identity_dart_2: ^2.0.0
  http: ^1.0.0
  
  # Keep existing dependencies
  mqtt_client: ^10.0.0
  # ... others
```

Install:
```bash
cd ahu_dashboard
flutter pub get
```

### Step 5.2: Update Cognito Service

Edit `lib/services/aws_cognito_service.dart`:
```dart
static const String userPoolId = 'YOUR_USER_POOL_ID'; // From Phase 1
static const String clientId = 'YOUR_CLIENT_ID'; // From Phase 1
```

### Step 5.3: Replace Firebase Auth with Cognito

In your auth provider:
```dart
// OLD:
final firebaseService = FirebaseService();

// NEW:
final cognitoService = CognitoService();

// Sign in:
final session = await cognitoService.signIn(
  email: email,
  password: password,
);
```

### Step 5.4: Update MQTT Service for AWS IoT

For native platforms (Android/iOS):
- Use `AwsMqttService` with certificates
- Load certificates from assets or secure storage

For web:
- Consider using API Gateway WebSocket API
- Or use HTTP polling via API Gateway

### Step 5.5: Replace InfluxDB with Timestream

In your analytics/graph code:
```dart
// OLD:
final influxData = await influxService.getHistoricalData(...);

// NEW:
final timestreamService = TimestreamService(
  accessKeyId: 'YOUR_ACCESS_KEY',
  secretAccessKey: 'YOUR_SECRET_KEY',
);

final data = await timestreamService.getHistoricalData(
  deviceId: 'ahu-01',
  hoursBack: 24,
  measureName: 'temperature',
);
```

### Step 5.6: Replace Firestore with DynamoDB

For device state:
```dart
final dynamodbService = DynamoDBService(
  accessKeyId: 'YOUR_ACCESS_KEY',
  secretAccessKey: 'YOUR_SECRET_KEY',
);

final state = await dynamodbService.getDeviceState('ahu-01');
```

---

## 🧪 Phase 6: Testing (Day 7)

### Step 6.1: Test ESP32 → AWS IoT

1. Monitor ESP32 Serial output
2. Check AWS IoT Console → Test → MQTT Test client
3. Subscribe to: `almed/ahu/+/+/+/telemetry`
4. Verify messages are received

### Step 6.2: Test IoT Rules

1. Check Timestream:
   ```bash
   aws timestream-query query \
     --query-string "SELECT * FROM ahu_telemetry.sensor_data WHERE time > ago(1h) LIMIT 10" \
     --region ap-south-1
   ```

2. Check DynamoDB:
   ```bash
   aws dynamodb get-item \
     --table-name ahu-device-state \
     --key '{"device_id": {"S": "ahu-01"}}' \
     --region ap-south-1
   ```

### Step 6.3: Test Flutter App

1. Sign in with Cognito
2. Verify MQTT connection
3. Check real-time data display
4. Verify historical data from Timestream

---

## 🔄 Phase 7: Parallel Run (Week 2)

### Step 7.1: Keep Both Systems Running

- Keep HiveMQ + InfluxDB + Firebase running
- Start AWS IoT Core
- Migrate one device at a time

### Step 7.2: Migrate Devices Gradually

1. Update ESP32 firmware (one device)
2. Test for 24 hours
3. Verify data in both systems
4. Move to next device

### Step 7.3: Migrate Users

1. Export users from Firebase
2. Import to Cognito:
   ```bash
   # Create users in Cognito
   aws cognito-idp admin-create-user \
     --user-pool-id YOUR_POOL_ID \
     --username user@example.com \
     --user-attributes Name=email,Value=user@example.com \
     --temporary-password TempPass123! \
     --region ap-south-1
   ```

---

## 🗑️ Phase 8: Decommission Old Services (Week 3)

### Step 8.1: Verify All Devices Migrated

```bash
# List all Things in AWS IoT
aws iot list-things --region ap-south-1
```

### Step 8.2: Stop Old Services

1. Stop HiveMQ bridge
2. Stop InfluxDB writes
3. Keep Firebase for backup (optional)

### Step 8.3: Cancel Subscriptions

- HiveMQ Cloud
- InfluxDB Cloud
- Firebase (if not keeping)

---

## 📊 Monitoring & Cost Management

### Monitor AWS Costs

```bash
# Check IoT Core message count
aws cloudwatch get-metric-statistics \
  --namespace AWS/IoT \
  --metric-name NumberOfMessagesPublished \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum \
  --region ap-south-1
```

### Set Up Billing Alerts

1. AWS Console → Billing → Budgets
2. Create budget with alerts
3. Set threshold (e.g., $200/month)

---

## 🔧 Troubleshooting

### ESP32 Can't Connect to AWS IoT

1. Check endpoint is correct
2. Verify certificates are valid
3. Check WiFi connection
4. Check Serial output for errors

### Bridge Not Forwarding Messages

1. Check bridge logs: `journalctl -u mqtt-bridge-aws.service`
2. Verify AWS IoT connection
3. Check local broker connection
4. Verify certificates are correct

### Flutter App Can't Connect

1. Check Cognito User Pool ID
2. Verify client ID
3. Check AWS credentials
4. Review app logs

---

## 📝 Quick Reference

### AWS IoT Endpoint
```bash
aws iot describe-endpoint --endpoint-type iot:Data-ATS --region ap-south-1
```

### List All Devices
```bash
aws iot list-things --region ap-south-1
```

### Query Timestream
```bash
aws timestream-query query \
  --query-string "SELECT * FROM ahu_telemetry.sensor_data WHERE time > ago(1h)" \
  --region ap-south-1
```

### Get Device State
```bash
aws dynamodb get-item \
  --table-name ahu-device-state \
  --key '{"device_id": {"S": "ahu-01"}}' \
  --region ap-south-1
```

---

## ✅ Migration Checklist

- [ ] CloudFormation stack deployed
- [ ] IoT endpoint obtained
- [ ] Bridge certificate created
- [ ] ESP32 certificates created (all devices)
- [ ] Python bridge updated and running
- [ ] ESP32 code updated (all devices)
- [ ] Flutter app updated with Cognito
- [ ] Flutter app updated with Timestream
- [ ] Flutter app updated with DynamoDB
- [ ] Testing completed
- [ ] All devices migrated
- [ ] Users migrated to Cognito
- [ ] Old services decommissioned

---

## 🎉 Success!

You've successfully migrated to AWS IoT Core! Your platform is now:
- ✅ Simpler (one cloud provider)
- ✅ Cheaper (savings of $400+/month)
- ✅ More scalable
- ✅ More secure
- ✅ Better integrated

**Next steps:**
- Monitor costs in AWS Console
- Set up CloudWatch alarms
- Optimize Timestream retention policies
- Consider adding more AWS services (Lambda, API Gateway, etc.)

