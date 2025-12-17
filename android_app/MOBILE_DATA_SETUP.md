# Android App - Mobile Data Configuration Guide

This document explains what changes have been made and what needs to be verified for the Android app to work on mobile data or any network (not just local WiFi).

## ✅ Changes Made

### 1. **API Base URL Updated**
- **File**: `lib/config/app_config.dart`
- **Change**: Base URL now points to Railway.com deployment
- **URL**: `https://almedahuwebapp-production.up.railway.app`
- **Status**: ✅ Already configured

### 2. **Network Permissions**
- **File**: `android/app/src/main/AndroidManifest.xml`
- **Permissions**: 
  - `INTERNET` ✅ Already present
  - `ACCESS_NETWORK_STATE` ✅ Already present
- **Status**: ✅ No changes needed

### 3. **HTTPS Configuration**
- Railway deployment uses HTTPS automatically
- Android supports HTTPS by default (no configuration needed)
- **Status**: ✅ Works out of the box

## ⚠️ Railway Configuration Required

### 1. **CORS Settings** (CRITICAL)
The web dashboard needs to allow requests from mobile apps.

**In Railway.com Dashboard:**
1. Go to your project → Variables tab
2. Set environment variable:
   ```
   CORS_ORIGINS=*
   ```
   Or for production (more secure), set specific origins if needed.

**Note**: The default in `config.py` is `'*'` which allows all origins, so this should work. But verify it's set correctly in Railway.

**Verify**: Check Railway logs after deployment - you should see CORS headers in API responses.

### 2. **Environment Variables in Railway**
Make sure all required environment variables are set in Railway:

**Required Variables:**
- `AWS_REGION` (e.g., `ap-south-1`)
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_IOT_ENDPOINT` (e.g., `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`)
- `AWS_IOT_TOPIC_PUBLISH` (default: `esp32/pub`)
- `AWS_IOT_TOPIC_SUBSCRIBE` (default: `esp32/sub`)
- `MONGO_URI`
- `MONGO_DB_NAME`
- `SECRET_KEY`
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`
- `PORT` (Railway sets this automatically, but can override)
- `CORS_ORIGINS` (set to `*` or specific origins)

See `web_dashboard/config.py` for all available environment variables.

## ✅ What Already Works

1. **API Calls**: All API endpoints use `AppConfig.baseUrl`, so they automatically use Railway URL
2. **AWS IoT Direct Connection**: Doesn't depend on local network - connects directly to AWS IoT Core
3. **Fallback Mechanism**: App tries AWS IoT first, falls back to Flask API if needed
4. **HTTPS**: Railway provides SSL certificates automatically

## 🔍 Testing Checklist

### Test 1: Verify Railway Deployment
- [ ] Open https://almedahuwebapp-production.up.railway.app in browser
- [ ] Login page loads correctly
- [ ] Can login with admin credentials

### Test 2: Test API Endpoints
Using a REST client (Postman, curl, etc.):
- [ ] `POST https://almedahuwebapp-production.up.railway.app/api/login`
- [ ] `GET https://almedahuwebapp-production.up.railway.app/api/devices` (with session cookie)

### Test 3: Test Android App
On a device with mobile data (WiFi disabled):
- [ ] App launches without errors
- [ ] Can login successfully
- [ ] Can see list of hospitals/devices
- [ ] Can view device status
- [ ] Can send commands (start/stop, set temperature, etc.)

### Test 4: Verify CORS Headers
In browser DevTools (Network tab) or using curl:
```bash
curl -H "Origin: https://almedahuwebapp-production.up.railway.app" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     https://almedahuwebapp-production.up.railway.app/api/login \
     -v
```

Should see headers like:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

## 🚨 Common Issues & Solutions

### Issue 1: "Network request failed" or "Connection refused"
**Cause**: Railway deployment might not be running or URL is incorrect
**Solution**: 
- Verify Railway deployment is active
- Check Railway logs for errors
- Ensure `PORT` environment variable is set correctly

### Issue 2: "CORS policy error" in browser/requests
**Cause**: CORS not configured correctly
**Solution**:
- Set `CORS_ORIGINS=*` in Railway environment variables
- Redeploy if needed
- Check Flask logs for CORS-related errors

### Issue 3: "401 Unauthorized" or login fails
**Cause**: Session cookies not working or credentials incorrect
**Solution**:
- Verify `ADMIN_USERNAME` and `ADMIN_PASSWORD` are set in Railway
- Check if `SECRET_KEY` is set (required for sessions)
- Test login directly via browser first

### Issue 4: Device status shows "offline" even when online
**Cause**: This is a device/ESP32 issue, not network issue
**Solution**: 
- Verify ESP32 is connected to AWS IoT Core
- Check AWS IoT Core logs
- Verify device is publishing to `esp32/pub` topic

### Issue 5: Commands not working
**Cause**: API endpoint issue or command format incorrect
**Solution**:
- Check Railway logs for API errors
- Verify `/api/device/{deviceId}/command` endpoint is working
- Test command endpoint directly via REST client

## 📱 Mobile Data vs WiFi

The app now works identically on:
- ✅ Mobile Data (4G/5G)
- ✅ WiFi (any network)
- ✅ Local WiFi (if Railway is accessible)

**No special configuration needed** - the Railway URL is accessible from anywhere on the internet.

## 🔐 Security Notes

1. **HTTPS**: Railway provides automatic SSL certificates, so all traffic is encrypted
2. **AWS Credentials**: Currently stored in `aws_config.dart` - consider moving to secure storage (Android Keystore) for production
3. **CORS**: In production, consider restricting `CORS_ORIGINS` to specific domains instead of `*`
4. **Session Cookies**: Ensure `SECRET_KEY` is a strong random value in production

## 📝 Summary

**The app is ready to work on mobile data!** The only thing you need to verify is that Railway deployment has the correct environment variables set, especially `CORS_ORIGINS=*` to allow mobile app requests.

All API calls automatically use the Railway URL, and there are no hardcoded local IPs or localhost references in the app anymore.

