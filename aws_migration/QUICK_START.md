# AWS Migration Quick Start

## ⚡ 30-Minute Quick Start

### Step 1: Deploy Infrastructure (5 minutes)

```bash
cd aws_migration
chmod +x setup_aws_infrastructure.sh
./setup_aws_infrastructure.sh
```

**Save the outputs:**
- IoT Endpoint
- User Pool ID  
- User Pool Client ID

### Step 2: Create Bridge Certificate (2 minutes)

```bash
chmod +x create_device_certificates.sh
./create_device_certificates.sh bridge-pi
```

**Copy certificates to Raspberry Pi:**
```bash
scp device_certs/bridge-pi/* pi@your-raspberry-pi:/home/almed/aws-certs/
```

### Step 3: Create ESP32 Certificates (5 minutes)

```bash
./create_device_certificates.sh ahu-01
./create_device_certificates.sh ahu-02
# ... repeat for all devices
```

### Step 4: Update Bridge (5 minutes)

On Raspberry Pi:
```bash
# Install dependencies
pip3 install paho-mqtt boto3

# Edit mqtt_bridge_aws.py
nano mqtt_bridge_aws.py
# Update: AWS_IOT_ENDPOINT, certificate paths

# Test
python3 mqtt_bridge_aws.py
```

### Step 5: Update ESP32 (10 minutes)

1. Copy `esp32_aws_integration.h` to ESP32 project
2. Update certificates in header file
3. Include in main `.ino`:
   ```cpp
   #include "esp32_aws_integration.h"
   ```
4. In `setup()`:
   ```cpp
   initAWSIoT();
   connectToAWS();
   ```
5. Upload and test

### Step 6: Update Flutter (3 minutes)

1. Add dependencies to `pubspec.yaml`:
   ```yaml
   amazon_cognito_identity_dart_2: ^2.0.0
   http: ^1.0.0
   ```

2. Update `aws_cognito_service.dart` with User Pool ID and Client ID

3. Replace Firebase with Cognito in your auth provider

## 🎯 What You Get

✅ **AWS IoT Core** - MQTT broker (replaces HiveMQ)  
✅ **Amazon Timestream** - Time-series database (replaces InfluxDB)  
✅ **DynamoDB** - NoSQL database (replaces Firestore)  
✅ **Amazon Cognito** - Authentication (replaces Firebase Auth)  
✅ **IoT Rules** - Automatic data routing  
✅ **Cost Savings** - ~$400/month

## 📝 Next Steps

1. **Test with one device first**
2. **Gradually migrate all devices**
3. **Migrate users to Cognito**
4. **Decommission old services**

## 📚 Full Guide

See `AWS_MIGRATION_GUIDE.md` for detailed steps.

## 🔧 Troubleshooting

**ESP32 can't connect?**
- Check endpoint is correct
- Verify certificates are valid
- Check Serial output

**Bridge not working?**
- Check logs: `journalctl -u mqtt-bridge-aws.service`
- Verify AWS credentials
- Check certificate paths

**Flutter app issues?**
- Verify User Pool ID and Client ID
- Check AWS credentials
- Review app logs

## 💰 Cost Estimate

For 50 devices, 1 msg/min/device:
- **IoT Core**: ~$11/month
- **Timestream**: ~$50/month
- **DynamoDB**: ~$5/month
- **Cognito**: Free (first 50K users)
- **Total**: ~$120/month

**Savings**: ~$410/month vs. current stack

