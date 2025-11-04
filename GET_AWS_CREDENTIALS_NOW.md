# 🔑 Get Your AWS Credentials - Quick Guide

## Follow These Steps to Get Credentials:

### 1. Open AWS IAM Console
Click this link (opens in new tab):
```
https://console.aws.amazon.com/iam/home?region=ap-south-1#/users
```

### 2. Create IAM User
1. Click **"Create user"** button
2. Username: `ahu-dashboard-admin`
3. Click **Next**

### 3. Set Permissions
1. Select: **"Attach policies directly"**
2. In search box, type: `CognitoPower`
3. Check: ☑️ **AmazonCognitoPowerUser**
4. Click **Next**

### 4. Review and Create
1. Click **"Create user"**
2. Click on the user name: `ahu-dashboard-admin`

### 5. Create Access Key
1. Click **"Security credentials"** tab
2. Scroll down to **"Access keys"**
3. Click **"Create access key"**
4. Select: **"Application running outside AWS"**
5. Click **Next**
6. Click **"Create access key"**

### 6. ⚠️ SAVE YOUR CREDENTIALS
You'll see:
- **Access key ID**: `AKIA...` (20 characters)
- **Secret access key**: `wJalr...` (40 characters)

**⚠️ COPY BOTH NOW! You won't see the secret key again!**

---

## Once You Have Credentials:

**Send me:**
1. Access Key ID: `AKIA...`
2. Secret Access Key: `wJalr...`

**I'll update the code automatically!**

---

## Or Do It Yourself:

**Edit this file:**
`ahu_dashboard/lib/services/aws_admin_service.dart`

**Lines 13-14:**
```dart
static const String accessKeyId = 'PASTE_YOUR_ACCESS_KEY_ID_HERE';
static const String secretAccessKey = 'PASTE_YOUR_SECRET_ACCESS_KEY_HERE';
```

**Save and restart the app!**

