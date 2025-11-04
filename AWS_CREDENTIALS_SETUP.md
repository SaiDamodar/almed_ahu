# 🔑 AWS Credentials Setup for Automated User Creation

## ⚠️ Important: Required for Automated User Creation

To enable **automated user creation** directly from the dashboard, you need to configure AWS credentials.

---

## 🔧 Step 1: Get Your AWS Credentials

### Option A: Create IAM User (Recommended)

1. **Go to AWS IAM Console:**
   ```
   https://console.aws.amazon.com/iam/home?region=ap-south-1#/users
   ```

2. **Create New User:**
   - Click "Add users"
   - Username: `ahu-dashboard-admin`
   - Select: "Programmatic access" ✅

3. **Attach Permissions:**
   - Click "Attach existing policies directly"
   - Search and select: `AmazonCognitoPowerUser`
   - Or create custom policy (see below)

4. **Review and Create:**
   - Click "Create user"
   - **IMPORTANT:** Save the credentials:
     - Access Key ID: `AKIA...`
     - Secret Access Key: `wJalr...`

### Option B: Use Existing User

If you already have an IAM user with Cognito permissions:
1. Go to IAM → Users → Your User → Security credentials
2. Create new Access Key
3. Save Access Key ID and Secret Access Key

---

## 🔐 Step 2: Configure Credentials in Code

### Update the File:
Open: `ahu_dashboard/lib/services/aws_admin_service.dart`

Find these lines (around line 13-14):
```dart
static const String accessKeyId = 'YOUR_AWS_ACCESS_KEY_ID'; // TODO: Replace
static const String secretAccessKey = 'YOUR_AWS_SECRET_ACCESS_KEY'; // TODO: Replace
```

Replace with your actual credentials:
```dart
static const String accessKeyId = 'AKIAIOSFODNN7EXAMPLE'; // Your Access Key ID
static const String secretAccessKey = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'; // Your Secret Key
```

**Save the file.**

---

## 🚀 Step 3: Test Automated User Creation

1. **Restart the Flutter app:**
   ```bash
   flutter run -d chrome
   ```

2. **Go to Users page**

3. **Click "+ Create User"**

4. **Fill in the form:**
   - Email: `test@example.com`
   - Display Name: `Test User`
   - Temporary Password: `TempPass123!`
   - Role: `admin` or `client`
   - (For client) Assign devices

5. **Click "Create"**

**Expected Result:**
- ✅ "User created successfully!" message
- ✅ User appears in the list
- ✅ No need to run AWS CLI commands manually

---

## 📋 Required IAM Policy

If creating a custom IAM policy, use this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:AdminCreateUser",
        "cognito-idp:AdminSetUserPassword",
        "cognito-idp:AdminDeleteUser",
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminGetUser",
        "cognito-idp:ListUsers"
      ],
      "Resource": "arn:aws:cognito-idp:ap-south-1:*:userpool/ap-south-1_LSTShtM9R"
    }
  ]
}
```

---

## 🔒 Security Best Practices

### ⚠️ **DO NOT** commit credentials to Git!

**For Production:**

1. **Use Environment Variables:**
   ```dart
   static const String accessKeyId = String.fromEnvironment('AWS_ACCESS_KEY_ID');
   static const String secretAccessKey = String.fromEnvironment('AWS_SECRET_ACCESS_KEY');
   ```

2. **Or Use Backend API:**
   - Create a Lambda function that handles user creation
   - Call Lambda from Flutter app
   - Store credentials only in Lambda

3. **Rotate Keys Regularly:**
   - Create new keys every 90 days
   - Delete old keys

4. **Use IAM Roles (for backend):**
   - If running on EC2 or Lambda, use IAM roles instead of keys

---

## 🧪 Testing Without Credentials

If you don't want to set up credentials yet:

1. **Leave credentials as default**
2. **Click "Create User"**
3. **You'll see:** AWS CLI instructions dialog (fallback mode)
4. **Copy and run** the AWS CLI command manually

**With credentials configured:**
- ✅ Automated creation (no manual commands)
- ✅ One-click user creation
- ✅ Instant feedback

---

## 🐛 Troubleshooting

### Error: "AWS credentials not configured"
**Solution:** Update `accessKeyId` and `secretAccessKey` in `aws_admin_service.dart`

### Error: "AccessDeniedException"
**Solution:** Attach `AmazonCognitoPowerUser` policy to your IAM user

### Error: "SignatureDoesNotMatch"
**Solution:** Check that Secret Access Key is correct (no extra spaces)

### Error: "InvalidParameterException"
**Solution:** Check User Pool ID is correct: `ap-south-1_LSTShtM9R`

---

## 📊 Summary

**Before (Manual):**
1. Fill form → Click Create
2. Copy AWS CLI command
3. Open terminal
4. Paste and run command
5. User created

**After (Automated):**
1. Fill form → Click Create
2. ✅ User created instantly!

---

## 🔗 Useful Links

- **IAM Console:** https://console.aws.amazon.com/iam/home?region=ap-south-1
- **Cognito Console:** https://console.aws.amazon.com/cognito/v2/idp/user-pools?region=ap-south-1
- **AWS Documentation:** https://docs.aws.amazon.com/cognito/

---

**File to Update:** `ahu_dashboard/lib/services/aws_admin_service.dart`  
**Lines to Change:** 13-14  
**Status:** ⚠️ Credentials Required for Automation  
**Fallback:** Manual AWS CLI commands (if not configured)

