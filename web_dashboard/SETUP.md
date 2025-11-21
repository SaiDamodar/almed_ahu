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

### Railway.com Deployment (Recommended)

Railway.com provides easy deployment with automatic HTTPS, custom domains, and environment variable management.

#### Prerequisites

1. **Railway Account**: Sign up at [railway.com](https://railway.com)
2. **GitHub Repository**: Push your web dashboard code to GitHub
3. **Domain Name** (Optional): Purchase domain (e.g., `almed.org.in`) from a registrar

#### Step 1: Prepare Your Repository

1. Ensure `Dockerfile` exists in the `web_dashboard` directory
2. Ensure `config.py` uses environment variables (already configured)
3. Commit and push to GitHub

#### Step 2: Deploy to Railway

1. **Create New Project**:
   - Go to [railway.app](https://railway.app)
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository
   - Select the `web_dashboard` directory as the root

2. **Configure Environment Variables**:
   In Railway dashboard, go to your service → Variables tab, add:
   
   ```
   # AWS Configuration
   AWS_REGION=ap-south-1
   AWS_ACCESS_KEY_ID=your_aws_access_key
   AWS_SECRET_ACCESS_KEY=your_aws_secret_key
   
   # AWS IoT Core
   AWS_IOT_ENDPOINT=your-iot-endpoint.iot.region.amazonaws.com
   AWS_IOT_TOPIC_PUBLISH=esp32/pub
   AWS_IOT_TOPIC_SUBSCRIBE=esp32/sub
   
   # MongoDB
   MONGO_URI=your_mongodb_connection_string
   MONGO_DB_NAME=almed_ahu
   MONGO_COLLECTION=telemetry
   
   # Flask Configuration
   SECRET_KEY=generate_a_secure_random_key_here
   FLASK_DEBUG=False
   HOST=0.0.0.0
   # PORT is set automatically by Railway
   
   # Admin Configuration
   ADMIN_USERNAME=admin
   ADMIN_PASSWORD=your_secure_password
   ADMIN_PASSCODE=your_secure_passcode
   
   # CORS (for custom domain)
   CORS_ORIGINS=https://almed.org.in,https://www.almed.org.in
   
   # GitHub OTA (if using)
   GITHUB_TOKEN=your_github_token
   GITHUB_REPO_OWNER=your_username
   GITHUB_REPO_NAME=your_repo_name
   GITHUB_REPO_BRANCH=main
   ```

3. **Generate Secure SECRET_KEY**:
   ```bash
   python -c "import secrets; print(secrets.token_hex(32))"
   ```

4. **Deploy**:
   - Railway will automatically detect the Dockerfile
   - Build and deploy will start automatically
   - Check the "Deployments" tab for build logs

#### Step 3: Configure Custom Domain (Optional)

1. **In Railway Dashboard**:
   - Go to your service → Settings → Domains
   - Click "Generate Domain" to get a Railway domain (e.g., `your-app.railway.app`)
   - Or click "Custom Domain" to add `almed.org.in`

2. **Configure DNS** (if using custom domain):
   - Go to your domain registrar (GoDaddy, Namecheap, etc.)
   - Add a CNAME record:
     - Type: `CNAME`
     - Name: `@` (or `www` for www.almed.org.in)
     - Value: Railway will provide this (e.g., `your-app.up.railway.app`)
   - Wait for DNS propagation (5-30 minutes)

3. **Update Android App**:
   In `android_app/lib/config/app_config.dart`:
   ```dart
   static const String baseUrl = 'https://almed.org.in';  // or your Railway domain
   ```

#### Step 4: Verify Deployment

1. Check Railway logs for any errors
2. Visit your domain/URL
3. Test login with admin credentials
4. Verify WebSocket connections work
5. Test API endpoints from Android app

#### Railway Pricing

- **Hobby Plan ($5/month)**: 
  - 512 MB RAM
  - 100 GB bandwidth
  - Good for testing/small deployments
  
- **Pro Plan ($20/month)**:
  - 8 GB RAM
  - 1 TB bandwidth
  - Recommended for production with WebSocket connections

**Recommendation**: Start with Hobby, upgrade if you experience memory issues.

#### Troubleshooting Railway Deployment

1. **Build Fails**:
   - Check Dockerfile syntax
   - Verify all dependencies in `requirements.txt`
   - Check Railway build logs

2. **App Crashes**:
   - Check environment variables are set correctly
   - Verify AWS credentials are valid
   - Check Railway logs for error messages

3. **WebSocket Issues**:
   - Railway supports WebSockets, but may need configuration
   - Ensure `eventlet` is in requirements.txt
   - Check SocketIO configuration in `app.py`

4. **Port Issues**:
   - Railway sets `PORT` automatically
   - Ensure `config.py` reads `PORT` from environment: `PORT = int(os.getenv('PORT', 5000))`

### Using Gunicorn (Alternative)

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

### Using Docker Locally

Build and run:
```bash
docker build -t almed-dashboard .
docker run -p 5000:5000 --env-file .env almed-dashboard
```

### Security Notes

1. **Change admin credentials** - Use strong passwords in production
2. **Use environment variables** - Never commit secrets to Git
3. **Enable HTTPS** - Railway provides automatic SSL certificates
4. **Restrict CORS** - Set `CORS_ORIGINS` to your specific domains in production
5. **Use AWS IAM roles** - Prefer IAM roles over access keys when possible
6. **Generate secure SECRET_KEY** - Use `secrets.token_hex(32)` for Flask sessions
7. **Keep dependencies updated** - Regularly update `requirements.txt` packages

## Next Steps

1. Set up DynamoDB (see DYNAMODB_SETUP.md)
2. Configure AWS IoT Core rule
3. Test with your ESP32 device
4. Customize UI colors/themes if needed

