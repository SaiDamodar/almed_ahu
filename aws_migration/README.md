# AWS IoT Migration Package

This directory contains all files needed to migrate from HiveMQ + InfluxDB + Firebase to AWS IoT Core.

## 📁 Files Overview

### Infrastructure
- **cloudformation-template.yaml** - AWS infrastructure setup (IoT Core, Timestream, DynamoDB, Cognito)

### Bridge (Raspberry Pi)
- **mqtt_bridge_aws.py** - Python bridge that forwards MQTT messages from local broker to AWS IoT Core

### ESP32
- **esp32_aws_integration.h** - Header file for AWS IoT Core integration
- **esp32_aws_integration_example.ino** - Example showing how to integrate

### Flutter Services
- **aws_cognito_service.dart** - Cognito authentication (replaces Firebase Auth)
- **aws_timestream_service.dart** - Timestream queries (replaces InfluxDB)
- **aws_dynamodb_service.dart** - DynamoDB operations (replaces Firestore)
- **aws_mqtt_service.dart** - AWS IoT Core MQTT client

### Scripts
- **setup_aws_infrastructure.sh** - Automated CloudFormation deployment
- **create_device_certificates.sh** - Automated certificate generation for devices

### Documentation
- **AWS_MIGRATION_GUIDE.md** - Complete step-by-step migration guide
- **README.md** - This file

## 🚀 Quick Start

1. **Deploy Infrastructure:**
   ```bash
   cd aws_migration
   chmod +x setup_aws_infrastructure.sh
   ./setup_aws_infrastructure.sh
   ```

2. **Create Device Certificates:**
   ```bash
   chmod +x create_device_certificates.sh
   ./create_device_certificates.sh bridge-pi
   ./create_device_certificates.sh ahu-01
   ```

3. **Follow Migration Guide:**
   See `AWS_MIGRATION_GUIDE.md` for detailed steps

## 📋 Prerequisites

- AWS Account with billing enabled
- AWS CLI installed and configured
- Python 3.7+ (for bridge)
- ESP32 development environment
- Flutter SDK (for dashboard)

## 🔧 Configuration

After deployment, update these files with your AWS values:

1. **mqtt_bridge_aws.py:**
   - `AWS_IOT_ENDPOINT`
   - Certificate paths

2. **esp32_aws_integration.h:**
   - `AWS_IOT_ENDPOINT`
   - Device certificates

3. **Flutter services:**
   - `aws_cognito_service.dart` - User Pool ID and Client ID
   - `aws_timestream_service.dart` - AWS credentials
   - `aws_dynamodb_service.dart` - AWS credentials

## 📚 Documentation

- **AWS_MIGRATION_GUIDE.md** - Complete migration guide
- AWS IoT Core: https://docs.aws.amazon.com/iot/
- Amazon Timestream: https://docs.aws.amazon.com/timestream/
- Amazon Cognito: https://docs.aws.amazon.com/cognito/

## 🆘 Support

If you encounter issues:
1. Check AWS_MIGRATION_GUIDE.md troubleshooting section
2. Review AWS CloudWatch logs
3. Check device Serial output
4. Review bridge logs: `journalctl -u mqtt-bridge-aws.service`

## ✅ Migration Checklist

See AWS_MIGRATION_GUIDE.md for complete checklist.

