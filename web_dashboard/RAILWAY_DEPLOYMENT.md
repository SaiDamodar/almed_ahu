# Railway.com Deployment Guide

Quick reference guide for deploying ALMED AHU Web Dashboard to Railway.com

## Quick Start

1. **Push to GitHub**: Ensure your `web_dashboard` folder is in a GitHub repository
2. **Connect Railway**: Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub
3. **Set Environment Variables**: Add all required variables (see below)
4. **Deploy**: Railway will automatically build and deploy

## Required Environment Variables

Set these in Railway Dashboard → Your Service → Variables:

### AWS Configuration
```
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
```

### AWS IoT Core
```
AWS_IOT_ENDPOINT=your-endpoint.iot.region.amazonaws.com
AWS_IOT_TOPIC_PUBLISH=esp32/pub
AWS_IOT_TOPIC_SUBSCRIBE=esp32/sub
```

### MongoDB
```
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/?retryWrites=true&w=majority
MONGO_DB_NAME=almed_ahu
MONGO_COLLECTION=telemetry
```

### Flask Configuration
```
SECRET_KEY=generate_with: python -c "import secrets; print(secrets.token_hex(32))"
FLASK_DEBUG=False
HOST=0.0.0.0
# PORT is automatically set by Railway
```

### Admin Credentials
```
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your_secure_password
ADMIN_PASSCODE=your_secure_passcode
```

### CORS (for custom domain)
```
CORS_ORIGINS=https://almed.org.in,https://www.almed.org.in
```

### GitHub OTA (optional)
```
GITHUB_TOKEN=your_github_token
GITHUB_REPO_OWNER=your_username
GITHUB_REPO_NAME=almed-esp32-firmware
GITHUB_REPO_BRANCH=main
```

## Custom Domain Setup

1. In Railway: Service → Settings → Domains → Add Custom Domain
2. Enter your domain: `almed.org.in`
3. Railway will provide DNS instructions
4. Add CNAME record at your domain registrar:
   - Type: `CNAME`
   - Name: `@` (or `www`)
   - Value: Railway-provided domain (e.g., `your-app.up.railway.app`)
5. Wait 5-30 minutes for DNS propagation

## Update Android App

After deployment, update `android_app/lib/config/app_config.dart`:

```dart
static const String baseUrl = 'https://almed.org.in';  // Your Railway domain
```

## Monitoring

- **Logs**: Railway Dashboard → Your Service → Deployments → View Logs
- **Health Check**: Visit `https://your-domain.com/api/health`
- **Metrics**: Railway Dashboard shows CPU, Memory, Network usage

## Troubleshooting

### Build Fails
- Check Dockerfile exists in `web_dashboard/` directory
- Verify all dependencies in `requirements.txt`
- Check Railway build logs for specific errors

### App Crashes
- Verify all environment variables are set
- Check Railway logs for error messages
- Ensure AWS credentials are valid
- Verify MongoDB connection string is correct

### WebSocket Not Working
- Railway supports WebSockets natively
- Ensure `eventlet` is in `requirements.txt`
- Check SocketIO configuration in `app.py`

### Port Issues
- Railway sets `PORT` automatically
- Don't hardcode port numbers
- Use `PORT = int(os.getenv('PORT', 5000))` in config

## Pricing

- **Hobby ($5/month)**: 512 MB RAM, 100 GB bandwidth - Good for testing
- **Pro ($20/month)**: 8 GB RAM, 1 TB bandwidth - Recommended for production

Start with Hobby, upgrade if needed.

## Support

For detailed setup instructions, see [SETUP.md](./SETUP.md)

