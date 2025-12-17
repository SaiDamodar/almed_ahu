# Login Troubleshooting Guide

## Issue: "Invalid username or password" error

If you're getting "Invalid username or password" when trying to login with `admin` / `1234`, here are the steps to diagnose and fix:

## Step 1: Verify Railway Environment Variables

**CRITICAL**: The Railway deployment must have these environment variables set:

1. Go to Railway.com dashboard
2. Select your project → Variables tab
3. Verify these variables are set:

```
ADMIN_USERNAME=admin
ADMIN_PASSWORD=1234
```

**If these are not set**, the app will use defaults from `config.py`, which might be different.

### How to set in Railway:
1. Click "New Variable"
2. Add `ADMIN_USERNAME` = `admin`
3. Add `ADMIN_PASSWORD` = `1234`
4. Click "Deploy" to apply changes

## Step 2: Test Railway API Directly

Test the login endpoint directly to see what's happening:

### Using curl (Command Line):
```bash
curl -X POST https://almedahuwebapp-production.up.railway.app/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"1234"}' \
  -v
```

### Using Postman/Browser:
- **URL**: `https://almedahuwebapp-production.up.railway.app/api/login`
- **Method**: POST
- **Headers**: `Content-Type: application/json`
- **Body**:
  ```json
  {
    "username": "admin",
    "password": "1234"
  }
  ```

### Expected Response (Success):
```json
{
  "success": true,
  "message": "Login successful"
}
```

### Expected Response (Failure):
```json
{
  "success": false,
  "message": "Invalid username or password"
}
```

## Step 3: Check Android App Logs

The app now has detailed logging. Check the logs when you try to login:

### Using Android Studio:
1. Open Android Studio
2. Connect your device or start emulator
3. Go to "Logcat" tab
4. Filter by "Login"
5. Try to login and check the logs

### Using adb (Command Line):
```bash
adb logcat | grep -i login
```

### What to look for:
- `Login: Attempting to login to https://...` - Shows the URL being used
- `Login: Response status: 200` or `401` - Shows the HTTP status
- `Login: Response body: {...}` - Shows the actual response

## Step 4: Verify URL in App

Make sure the app is using the correct URL:

**File**: `lib/config/app_config.dart`

```dart
static const String baseUrl = 'https://almedahuwebapp-production.up.railway.app';
```

**Verify**:
- No trailing slash
- Using HTTPS (not HTTP)
- Correct Railway domain

## Step 5: Check CORS Settings

If CORS is blocking the request, you'll see network errors:

### In Railway:
Set environment variable:
```
CORS_ORIGINS=*
```

### Verify CORS is working:
```bash
curl -X OPTIONS https://almedahuwebapp-production.up.railway.app/api/login \
  -H "Origin: https://almedahuwebapp-production.up.railway.app" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

Should see headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
```

## Step 6: Test with Browser First

Before testing with Android app:

1. Open browser
2. Go to: `https://almedahuwebapp-production.up.railway.app/login`
3. Try to login with `admin` / `1234`
4. If this works, the issue is with the Android app
5. If this doesn't work, the issue is with Railway deployment

## Common Issues & Solutions

### Issue 1: Environment Variables Not Set in Railway
**Symptom**: Login fails even with correct credentials
**Solution**: Set `ADMIN_USERNAME` and `ADMIN_PASSWORD` in Railway Variables tab

### Issue 2: Wrong Environment Variable Values
**Symptom**: Login fails with correct credentials
**Solution**: Check Railway Variables tab - ensure values match:
- `ADMIN_USERNAME` = `admin` (exactly, no extra spaces)
- `ADMIN_PASSWORD` = `1234` (exactly, no extra spaces)

### Issue 3: CORS Blocking Requests
**Symptom**: Network errors, no response from server
**Solution**: Set `CORS_ORIGINS=*` in Railway Variables

### Issue 4: Railway Deployment Not Running
**Symptom**: Connection refused, timeout errors
**Solution**: 
- Check Railway dashboard - service should show "Active"
- Check Railway logs for errors
- Redeploy if needed

### Issue 5: Wrong URL in App
**Symptom**: Connection refused, can't reach server
**Solution**: 
- Verify URL in `lib/config/app_config.dart`
- Ensure no trailing slash
- Ensure using HTTPS

### Issue 6: Session Cookie Issues
**Symptom**: Login succeeds but subsequent requests fail
**Solution**: 
- Check if cookies are being stored correctly
- Check Railway logs for session errors
- Verify `SECRET_KEY` is set in Railway

## Quick Debug Checklist

- [ ] Railway deployment is active (green status)
- [ ] `ADMIN_USERNAME` = `admin` in Railway Variables
- [ ] `ADMIN_PASSWORD` = `1234` in Railway Variables
- [ ] `CORS_ORIGINS=*` in Railway Variables
- [ ] URL in app is correct (no trailing slash)
- [ ] Using HTTPS (not HTTP)
- [ ] Browser login works (tests Railway deployment)
- [ ] Check Android logs for detailed error messages

## Still Having Issues?

1. **Check Railway Logs**:
   - Go to Railway dashboard → Your service → Logs
   - Look for errors related to login

2. **Check Android Logs**:
   - Use Android Studio Logcat
   - Filter by "Login" or "ApiService"
   - Look for error messages

3. **Test API Directly**:
   - Use curl or Postman to test the endpoint
   - This isolates whether the issue is with Railway or the app

4. **Verify Environment Variables**:
   - Railway might need a redeploy after setting variables
   - Check if variables are actually being read (check Railway logs)

## Example: Correct Railway Environment Variables

```
ADMIN_USERNAME=admin
ADMIN_PASSWORD=1234
CORS_ORIGINS=*
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=your_key_here
AWS_SECRET_ACCESS_KEY=your_secret_here
AWS_IOT_ENDPOINT=al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com
SECRET_KEY=your_secret_key_here
MONGO_URI=your_mongo_uri_here
... (other required variables)
```

Make sure all variables are set and the deployment is restarted after adding them.

