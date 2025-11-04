# How to View Your Resources in AWS Console

## ⚠️ IMPORTANT: Check Your Region First!

**MOST IMPORTANT STEP:** Make sure you're in **ap-south-1 (Mumbai)** region!

Look at the top-right corner of AWS Console:
- Should show: **Asia Pacific (Mumbai) ap-south-1**
- If not, click and select **ap-south-1**

---

## ✅ Resources That Exist (You Should See These)

### 1. IoT Core - Thing Types

**Direct Link:**
👉 https://console.aws.amazon.com/iot/home?region=ap-south-1#/thingtype

**Steps:**
1. Click the link above (or manually navigate)
2. In AWS Console → **IoT Core** → **Manage** → **Thing types**
3. You should see: **AHUDevice**

**What it looks like:**
- Thing Type Name: `AHUDevice`
- Description: "AHU Control Unit Device"
- Status: Active

---

### 2. IoT Core - Certificates

**Direct Link:**
👉 https://console.aws.amazon.com/iot/home?region=ap-south-1#/certificates

**Steps:**
1. Click the link above
2. In AWS Console → **IoT Core** → **Security** → **Certificates**
3. You should see: 1 certificate (bridge certificate)

**What it looks like:**
- Certificate ID: `258f8c17aa38a6474121603339a6b645c095030ff7b1a623344e1bf483b7e070`
- Status: **ACTIVE**

---

### 3. IoT Core - Endpoint

**Direct Link:**
👉 https://console.aws.amazon.com/iot/home?region=ap-south-1#/settings

**Steps:**
1. Click the link above
2. In AWS Console → **IoT Core** → **Settings**
3. Scroll down to **Device data endpoint**
4. You should see: `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`

**What it looks like:**
- Device data endpoint: `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
- Account-specific endpoint endpoint: (same as above)

---

### 4. DynamoDB - Tables

**Direct Link:**
👉 https://console.aws.amazon.com/dynamodbv2/home?region=ap-south-1#tables

**Steps:**
1. Click the link above
2. In AWS Console → **DynamoDB** → **Tables** (left menu)
3. You should see: 2 tables
   - `ahu-device-state`
   - `ahu-user-assignments`

**What it looks like:**
- Table Name: `ahu-device-state`
- Status: **ACTIVE** (or CREATING - wait a minute)
- Table Name: `ahu-user-assignments`
- Status: **ACTIVE** (or CREATING - wait a minute)

**If tables show "CREATING":**
- Wait 1-2 minutes
- Click refresh (F5)
- Status should change to "ACTIVE"

---

## 🔍 Step-by-Step: How to Navigate Manually

### If Direct Links Don't Work:

**1. IoT Core Resources:**
1. Go to AWS Console: https://console.aws.amazon.com
2. Search for **"IoT Core"** in the search bar
3. Click **"IoT Core"**
4. **Check region:** Top-right should show **ap-south-1**
5. In left menu:
   - **Manage** → **Thing types** (should see AHUDevice)
   - **Security** → **Certificates** (should see 1 certificate)
   - **Settings** (should see endpoint)

**2. DynamoDB Tables:**
1. Search for **"DynamoDB"** in AWS Console
2. Click **"DynamoDB"**
3. **Check region:** Top-right should show **ap-south-1**
4. Click **"Tables"** in left menu
5. Should see 2 tables listed

---

## ❌ Resources NOT Created Yet (You Won't See These)

These need to be created manually:

1. **IoT Policies** - Not created yet
   - Link: https://console.aws.amazon.com/iot/home?region=ap-south-1#/policy
   - Status: Empty (need to create)

2. **Cognito User Pool** - Not created yet
   - Link: https://console.aws.amazon.com/cognito/home?region=ap-south-1
   - Status: Empty (need to create)

3. **Timestream Database** - Not created yet
   - Link: https://console.aws.amazon.com/timestream/home?region=ap-south-1
   - Status: Empty (need to create)

4. **IoT Rules** - Not created yet
   - Link: https://console.aws.amazon.com/iot/home?region=ap-south-1#/act/rules
   - Status: Empty (need to create after Timestream)

---

## 🐛 Troubleshooting: "I Still Don't See Anything"

### Check These:

**1. Wrong Region?**
- ✅ Check top-right corner of AWS Console
- ✅ Should be: **ap-south-1 (Mumbai)**
- ✅ If not, click and select **ap-south-1**

**2. Wrong Account?**
- Check top-right corner
- Should show your account: **502360276622**
- If different, you're logged into wrong account

**3. Need to Refresh?**
- Press **F5** to refresh page
- Or click refresh button in browser

**4. Using Mobile App?**
- AWS Console mobile app might not show everything
- Use desktop browser instead

**5. Permissions Issue?**
- Your user might not have permissions to view certain resources
- Check IAM permissions

---

## ✅ Verification Checklist

Run these commands to verify (or check console):

- [ ] **IoT Thing Type:** AHUDevice exists
- [ ] **IoT Certificate:** 1 certificate exists (bridge)
- [ ] **IoT Endpoint:** `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
- [ ] **DynamoDB Table:** `ahu-device-state` exists
- [ ] **DynamoDB Table:** `ahu-user-assignments` exists
- [ ] **Region:** ap-south-1 (Mumbai)

---

## 📞 Still Not Working?

**Tell me:**
1. What region do you see in the top-right corner?
2. What account ID do you see?
3. What do you see when you click the direct links above?
4. Any error messages?

**I'll help troubleshoot!**

---

## 🎯 Quick Test

**Try this:**
1. Open this link: https://console.aws.amazon.com/iot/home?region=ap-south-1#/thingtype
2. Check top-right corner - should show **ap-south-1**
3. You should see **AHUDevice** in the list

**If you see it:** ✅ Resources exist! Continue with manual setup.

**If you don't see it:** 
- Check region (should be ap-south-1)
- Check account (should be 502360276622)
- Try refreshing (F5)

