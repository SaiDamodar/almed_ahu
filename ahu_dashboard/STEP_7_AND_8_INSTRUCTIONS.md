# Step 7 & 8: Firestore Security Rules & SHA-1 Fingerprint

## ✅ Step 7: Configure Firestore Security Rules

### Instructions:

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/
   - Select your project: `almed-ahu-cloud`

2. **Navigate to Firestore Rules:**
   - Click **"Firestore Database"** in left sidebar
   - Click **"Rules"** tab at the top

3. **Copy the Rules:**
   - Open file: `ahu_dashboard/firestore_security_rules.txt`
   - Copy ALL the content (Ctrl+A, Ctrl+C)

4. **Paste and Publish:**
   - In Firebase Console, **DELETE** all existing rules
   - **PASTE** the copied rules
   - Click **"Publish"** button
   - Wait for confirmation: "Rules published successfully"

### What the Rules Do:

✅ **Users Collection:**
- Users can read their own document
- Admins can read/write any user
- Users can create their own document

✅ **AHU Data (telemetry/state):**
- Clients can only read their assigned devices
- Admins can read all devices
- No one can write (only backend)

✅ **Security:**
- All other collections denied by default
- Only authenticated users can access data
- Role-based access control (client vs admin)

---

## 🔑 Step 8: Add SHA-1 Fingerprint to Firebase

### Your SHA-1 Fingerprint:

```
9C:B6:53:AE:98:EB:BA:6C:7D:6B:E5:DB:98:16:89:53:C7:29:10:65
```

### Instructions:

1. **Go to Firebase Console:**
   - Project Settings (gear icon ⚙️ next to "Project Overview")
   - Or: Click your project name → Project settings

2. **Scroll Down:**
   - Find **"Your apps"** section
   - Look for your Android app

3. **Add SHA-1:**
   - Click **"Add fingerprint"** button
   - **Paste your SHA-1:** `9C:B6:53:AE:98:EB:BA:6C:7D:6B:E5:DB:98:16:89:53:C7:29:10:65`
   - Click **"Save"**

4. **Wait for Propagation:**
   - Changes can take 10-15 minutes to propagate
   - You may need to wait before testing Google Sign-In

---

## ⚠️ Important Notes:

### Package Name Check:

Your current `google-services.json` has package: `Al_med.equipment`
Your app uses package: `com.almed.ahu_dashboard`

**You need to:**
1. Add a new Android app in Firebase Console with package `com.almed.ahu_dashboard`
2. Download the new `google-services.json`
3. Replace the file in `android/app/` folder

Or update the existing app's package name in Firebase Console.

---

## ✅ Checklist:

- [ ] Firestore security rules copied and pasted
- [ ] Rules published successfully
- [ ] SHA-1 fingerprint added to Firebase Console
- [ ] Package name matches (`com.almed.ahu_dashboard`)
- [ ] Wait 10-15 minutes for SHA-1 propagation

---

**Next:** After completing these steps, you can test Google Sign-In in your app!

