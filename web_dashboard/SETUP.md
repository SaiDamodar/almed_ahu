# Web Dashboard Setup Guide

## Prerequisites

1. Python 3.8 or higher
2. AWS Account with:
   - DynamoDB table created (see DYNAMODB_SETUP.md)
   - AWS IoT Core configured
   - IAM credentials with access

## Installation

### 1. Install Dependencies

```bash
cd web_dashboard
pip install -r requirements.txt
```

### 2. Configure AWS Credentials

1. Copy `config.example.py` to `config.py`:
   ```bash
   cp config.example.py config.py
   ```

2. Edit `config.py` and update:
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
   - `AWS_REGION` - Your AWS region (e.g., `ap-south-1`)
   - `AWS_IOT_ENDPOINT` - Your IoT Core endpoint
   - `DYNAMODB_TABLE_NAME` - Your DynamoDB table name

### 3. Set Environment Variables (Optional)

Instead of editing `config.py`, you can set environment variables:

```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export FLASK_DEBUG=True
```

### 4. Run the Server

```bash
python app.py
```

The server will start on `http://localhost:5000`

## Access the Dashboard

1. Open browser: http://localhost:5000
2. Default admin passcode: `1234` (change in `config.py`)

## Features

- **Dashboard**: View all AHU devices
- **Hospitals View**: Hierarchical view of hospitals → rooms → devices
- **AHU Control**: Control individual AHU units
- **Graphs**: Temperature, humidity, motor cycles visualization
- **Settings**: Admin configuration (WiFi, broker, motor timings)
- **OTA Updates**: Placeholder for firmware updates

## Troubleshooting

### Connection Issues

1. **Check AWS credentials**:
   - Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correct
   - Check IAM permissions for DynamoDB and IoT Core

2. **Check DynamoDB table**:
   - Verify table name matches `config.py`
   - Check table exists and is accessible

3. **Check IoT Core**:
   - Verify endpoint is correct
   - Check IoT Core rule is active
   - Verify ESP32 is publishing data

### Local MQTT (Optional)

If you want to use local MQTT broker (Raspberry Pi) as fallback:

1. Update `config.py`:
   ```python
   LOCAL_MQTT_BROKER = '10.42.0.1'
   LOCAL_MQTT_PORT = 1883
   LOCAL_MQTT_USERNAME = 'almed'
   LOCAL_MQTT_PASSWORD = 'Almed1234$'
   ```

2. The app will automatically use local MQTT if AWS IoT Core is unavailable

## Production Deployment

### Using Gunicorn

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

### Using Docker

Create `Dockerfile`:
```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
```

Build and run:
```bash
docker build -t almed-dashboard .
docker run -p 5000:5000 --env-file .env almed-dashboard
```

### Security Notes

1. **Change admin passcode** in `config.py`
2. **Use environment variables** for sensitive data
3. **Enable HTTPS** in production
4. **Restrict CORS** origins in `config.py`
5. **Use AWS IAM roles** instead of access keys when possible

## Next Steps

1. Set up DynamoDB (see DYNAMODB_SETUP.md)
2. Configure AWS IoT Core rule
3. Test with your ESP32 device
4. Customize UI colors/themes if needed

