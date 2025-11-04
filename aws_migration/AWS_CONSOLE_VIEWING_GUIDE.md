# AWS Console - Where to Find Your Resources

## ✅ Resources That Exist (Created Successfully)

### 1. IoT Core Resources
### 2. DynamoDB Tables
### 3. IoT Endpoint

---

## 🔍 How to View in AWS Console

### Step 1: Check Your Region

**IMPORTANT:** Make sure you're in **ap-south-1 (Mumbai)** region!

Look at the top-right corner of AWS Console:
- Current region should show: **Asia Pacific (Mumbai) ap-south-1**
- If not, click the region dropdown and select **ap-south-1**

---

## 📍 Direct Links to View Resources

### 1. IoT Core - Thing Types

**Direct Link:**
https://console.aws.amazon.com/iot/home?region=ap-south-1#/thingtype

**What you should see:**
- Thing Type Name: **AHUDevice**
- Description: "AHU Control Unit Device"
- Created: 2025-11-04

**If you don't see it:**
1. Make sure region is **ap-south-1**
2. Check the left menu: **Manage** → **Thing types**
3. Refresh the page (F5)

---

### 2. IoT Core - Endpoint

**Direct Link:**
https://console.aws.amazon.com/iot/home?region=ap-south-1#/settings

**What you should see:**
- Device data endpoint: **al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com**
- Account-specific endpoint endpoint: (same as above)

**How to view:**
1. Go to: **Settings** (left menu)
2. Scroll to **Device data endpoint**
3. Copy the endpoint address

---

### 3. DynamoDB Tables

**Direct Link:**
https://console.aws.amazon.com/dynamodbv2/home?region=ap-south-1#tables

**What you should see:**
- Table: **ahu-device-state**
- Table: **ahu-user-assignments**

**If you don't see them:**
1. Make sure region is **ap-south-1**
2. Check the **Tables** tab (left menu)
3. Refresh the page (F5)
4. They might still be in "CREATING" status (wait a minute and refresh)

**To check table status:**
- Click on a table name
- Check the **Overview** tab
- Status should be **ACTIVE** (not CREATING)

---

### 4. IoT Core - Certificates

**Direct Link:**
https://console.aws.amazon.com/iot/home?region=ap-south-1#/certificates

**What you should see:**
- Certificate ID: **258f8c17aa38a6474121603339a6b645c095030ff7b1a623344e1bf483b7e070**
- Status: **Active**

**How to view:**
1. Go to: **Security** → **Certificates** (left menu)
2. You should see the bridge certificate listed

---

## ⚠️ Resources NOT Created Yet (Need Manual Setup)

### 1. IoT Policies

**Direct Link:**
https://console.aws.amazon.com/iot/home?region=ap-south-1#/policy

**Status:** ❌ Not created yet

**To create:**
1. Click **Create policy**
2. Policy name: `AHUDevicePolicy`
3. Copy policy document from below
4. Click **Create**

**Policy Document:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iot:Connect"
      ],
      "Resource": "arn:aws:iot:ap-south-1:*:client/${iot:ClientId}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iot:Publish",
        "iot:Subscribe",
        "iot:Receive"
      ],
      "Resource": "arn:aws:iot:ap-south-1:*:topic/almed/ahu/*"
    }
  ]
}
```

---

### 2. Cognito User Pool

**Direct Link:**
https://console.aws.amazon.com/cognito/home?region=ap-south-1

**Status:** ❌ Not created yet

**To create:**
1. Click **Create user pool**
2. Follow steps in `SETUP_COMPLETE.md`

---

### 3. Timestream Database

**Direct Link:**
https://console.aws.amazon.com/timestream/home?region=ap-south-1

**Status:** ❌ Not created yet (may need activation)

**To create:**
1. If you see activation prompt, click **Activate** first
2. Then click **Create database**
3. Follow steps in `SETUP_COMPLETE.md`

---

## 🔧 Troubleshooting

### "I don't see anything"

**Check these:**
1. ✅ **Region is correct:** ap-south-1 (Mumbai)
2. ✅ **You're logged in:** Check top-right corner
3. ✅ **Refresh the page:** Press F5
4. ✅ **Check correct service:** IoT Core, DynamoDB, etc.

### "DynamoDB tables not showing"

**Possible reasons:**
- Tables might still be creating (wait 1-2 minutes)
- Wrong region selected
- Need to refresh page

**Check status:**
```bash
aws dynamodb describe-table --table-name ahu-device-state --region ap-south-1
```

### "IoT Thing Type not showing"

**Possible reasons:**
- Wrong region
- Need to refresh

**Verify it exists:**
```bash
aws iot list-thing-types --region ap-south-1
```

---

## 📋 Quick Verification Commands

Run these commands to verify resources exist:

```bash
# Check IoT Thing Type
aws iot list-thing-types --region ap-south-1

# Check DynamoDB Tables
aws dynamodb list-tables --region ap-south-1

# Check IoT Endpoint
aws iot describe-endpoint --endpoint-type iot:Data-ATS --region ap-south-1

# Check Certificates
aws iot list-certificates --region ap-south-1

# Check Policies (should be empty)
aws iot list-policies --region ap-south-1

# Check Cognito (should be empty)
aws cognito-idp list-user-pools --max-results 10 --region ap-south-1
```

---

## 🎯 What You Should See Right Now

### ✅ In IoT Core Console:
- **Thing Types:** 1 item (AHUDevice)
- **Certificates:** 1 certificate (bridge certificate)
- **Settings:** Endpoint visible

### ✅ In DynamoDB Console:
- **Tables:** 2 tables (ahu-device-state, ahu-user-assignments)

### ❌ Not Created Yet:
- IoT Policies (need to create)
- Cognito User Pool (need to create)
- Timestream Database (need to create)
- IoT Rules (need to create after Timestream)

---

## 🚀 Next Steps

1. **Verify resources exist** using direct links above
2. **Complete manual steps** in `SETUP_COMPLETE.md`
3. **Create missing resources** (Policy, Cognito, Timestream, Rules)

---

**If you still don't see anything, let me know what region you're in and I'll help troubleshoot!**

