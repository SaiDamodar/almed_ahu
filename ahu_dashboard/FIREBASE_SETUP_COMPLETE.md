# Firebase Setup Complete Guide

## 📋 Overview

This guide will walk you through setting up Firebase for the ALMED AHU Control System with Google Sign-In authentication and Firestore user management.

---

## 🚀 Step 1: Create Firebase Project

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Sign in with your Google account

2. **Create New Project**
   - Click "Add project" or "Create a project"
   - **Project name:** `almed-ahu-control` (or your preferred name)
   - Click "Continue"

3. **Enable Google Analytics** (Optional but recommended)
   - Choose whether to enable Analytics
   - Select or create Analytics account
   - Click "Create project"

4. **Wait for Project Creation**
   - This takes about 30 seconds
   - Click "Continue" when done

---

## 📱 Step 2: Add Android App to Firebase

1. **In Firebase Console, click "Add app"**
   - Select Android icon (🤖)

2. **Register App**
   - **Android package name:** `com.almed.ahu_dashboard`
     - This must match your `android/app/build.gradle` file (line 48: `applicationId`)
   - **App nickname:** (Optional) `AHU Dashboard Android`
   - **Debug signing certificate SHA-1:** (We'll get this later - can skip for now)
   - Click "Register app"

3. **Download Configuration File**
   - Download `google-services.json`
   - **Important:** Place this file in: `ahu_dashboard/android/app/google-services.json`
   - ✅ You MUST overwrite if it exists

4. **Click "Next" → "Next" → "Continue to console"**

---

## 🔐 Step 3: Enable Google Sign-In Authentication

1. **Go to Authentication**
   - In Firebase Console sidebar, click "Authentication"
   - Click "Get started"

2. **Enable Google Sign-In**
   - Click "Sign-in method" tab
   - Find "Google" in the list
   - Click "Google"
   - **Toggle "Enable"** to ON
   - Enter **Support email** (your email address)
   - Click "Save"

3. **Verify Google Sign-In is Enabled**
   - You should see "Google" listed with "Enabled" status

---

## 💾 Step 4: Create Firestore Database

1. **Go to Firestore Database**
   - In Firebase Console sidebar, click "Firestore Database"
   - Click "Create database"

2. **Choose Start Mode**
   - Select **"Start in test mode"** (we'll add security rules later)
   - Click "Next"

3. **Choose Location**
   - Select the closest location to your users
   - **Recommendation:** Choose the same region as your cloud MQTT broker
   - Click "Enable"

4. **Wait for Database Creation**
   - This takes 1-2 minutes
   - You'll see "Cloud Firestore API" initializing

---

## 📝 Step 5: Create Users Collection Structure

### Users Collection Structure

**Collection Name:** `users`  
**Document ID:** User's email address (e.g., `admin@almed.com`)

### Document Fields:

```javascript
{
  email: string,              // User's email address
  role: string,               // "client" or "admin"
  accessKey: string,          // For clients only - unique key shared by admin
  assignedDevices: array,     // For clients - list of AHU device IDs they can access
  isActive: boolean,          // Account status
  createdAt: timestamp,       // When account was created
  lastLogin: timestamp,       // Last login time (or null)
  displayName: string,        // Optional - user's display name
  fcmToken: string           // Optional - for push notifications
}
```

---

## 👤 Step 6: Create Sample Users in Firestore

### Create Admin User:

1. **In Firestore Console:**
   - Click "Start collection" (if collection doesn't exist)
   - **Collection ID:** `users`
   - Click "Next"

2. **Create First Document (Admin):**
   - **Document ID:** `admin@almed.com` (use your admin email)
   - Click "Add field" for each field:

   | Field | Type | Value |
   |-------|------|-------|
   | `email` | string | `admin@almed.com` |
   | `role` | string | `admin` |
   | `isActive` | boolean | `true` |
   | `createdAt` | timestamp | (Click and select "timestamp") |
   | `lastLogin` | null | (Leave empty/null) |

   - Click "Save"

### Create Client User:

1. **Add Another Document:**
   - Click "Add document" in the `users` collection
   - **Document ID:** `nurse@hospital.com` (example email)

   | Field | Type | Value |
   |-------|------|-------|
   | `email` | string | `nurse@hospital.com` |
   | `role` | string | `client` |
   | `accessKey` | string | `HOSP2024KEY` (choose a secure key) |
   | `assignedDevices` | array | Add item: `icu-1` (your AHU device ID) |
   | `isActive` | boolean | `true` |
   | `createdAt` | timestamp | (Click and select "timestamp") |
   | `lastLogin` | null | (Leave empty/null) |

   - Click "Save"

---

## 🔒 Step 7: Configure Firestore Security Rules

1. **Go to Firestore Rules**
   - Click "Firestore Database" → "Rules" tab

2. **Replace Default Rules with:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user is admin
    function isAdmin() {
      return isAuthenticated() && 
             exists(/databases/$(database)/documents/users/$(request.auth.token.email)) &&
             get(/databases/$(database)/documents/users/$(request.auth.token.email)).data.role == 'admin';
    }
    
    // Helper function to get user's assigned devices
    function getUserAssignedDevices() {
      return get(/databases/$(database)/documents/users/$(request.auth.token.email)).data.assignedDevices;
    }
    
    // Users collection
    match /users/{userId} {
      // Users can read their own document or admins can read any
      allow read: if isAuthenticated() && 
                     (request.auth.token.email == userId || isAdmin());
      
      // Only admins can create/update users
      allow write: if isAdmin();
      
      // Users can create their own document (for initial setup)
      allow create: if isAuthenticated() && request.auth.token.email == userId;
    }
    
    // AHU telemetry data - clients can read their assigned devices
    match /ahu_telemetry/{deviceId} {
      allow read: if isAuthenticated() && 
                     (isAdmin() || 
                      deviceId in getUserAssignedDevices());
      allow write: if false;  // Only backend can write
    }
    
    // AHU state data - similar to telemetry
    match /ahu_state/{deviceId} {
      allow read: if isAuthenticated() && 
                     (isAdmin() || 
                      deviceId in getUserAssignedDevices());
      allow write: if false;  // Only backend can write
    }
    
    // Admin-only collections
    match /admin_config/{document=**} {
      allow read, write: if isAdmin();
    }
    
    // User sessions/logs
    match /user_logs/{document=**} {
      allow read: if isAdmin();
      allow write: if isAuthenticated();
    }
    
    // Deny everything else by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

3. **Click "Publish"** to save rules

⚠️ **Note:** Start with test mode for initial setup, then apply these rules once you verify everything works.

---

## 🔑 Step 8: Get SHA-1 Fingerprint (Android)

This is required for Google Sign-In on Android.

### Method 1: Using Gradle (Recommended)

```powershell
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard\android"
.\gradlew signingReport
```

Look for output like:
```
Variant: debug
Config: debug
Store: C:\Users\YourName\.android\debug.keystore
Alias: AndroidDebugKey
MD5: ...
SHA1: A1:B2:C3:D4:E5:F6:...
SHA-256: ...
```

**Copy the SHA1 value** (it's a long string with colons)

### Method 2: Using keytool

```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for "SHA1:" in the output and copy that value.

### Add SHA-1 to Firebase:

1. Go to Firebase Console → Project Settings
2. Scroll down to "Your apps" section
3. Find your Android app
4. Click "Add fingerprint"
5. Paste your SHA-1 value
6. Click "Save"

---

## ✅ Step 9: Verify Setup

### Checklist:

- [ ] Firebase project created
- [ ] Android app registered with package name `com.almed.ahu_dashboard`
- [ ] `google-services.json` downloaded and placed in `android/app/`
- [ ] Google Sign-In enabled in Authentication
- [ ] Firestore database created
- [ ] Sample admin user created in Firestore
- [ ] Sample client user created in Firestore
- [ ] Security rules updated (or started in test mode)
- [ ] SHA-1 fingerprint added to Firebase Console

---

## 🧪 Step 10: Test Setup

### Test Google Sign-In:

1. **Run your Flutter app:**
   ```powershell
   cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
   flutter pub get
   flutter run
   ```

2. **Test in your login screen:**
   - Try signing in with Google using your admin email
   - Verify it authenticates successfully

3. **Check Firestore:**
   - Go to Firestore Console
   - Check that `lastLogin` field was updated in the user document

---

## 🔧 Troubleshooting

### Issue: "google-services.json not found"
- **Solution:** Make sure the file is in `android/app/google-services.json`
- Check file name (should be lowercase with hyphen)

### Issue: "SHA-1 fingerprint mismatch"
- **Solution:** Add SHA-1 to Firebase Console → Project Settings → Your Android app

### Issue: "Google Sign-In fails"
- **Solution:** 
  - Verify Google Sign-In is enabled in Authentication
  - Check SHA-1 fingerprint is correct
  - Wait 10-15 minutes after adding SHA-1 for propagation

### Issue: "User not found in Firestore"
- **Solution:** Create the user document in Firestore with correct email as Document ID

### Issue: "Access Denied" errors
- **Solution:** 
  - Check Firestore security rules
  - Verify user has correct `role` field (`admin` or `client`)
  - Verify `isActive` is `true`

---

## 📚 Next Steps

After Firebase setup is complete:

1. **Create Entry Screen** - Panel selection (Client/Admin)
2. **Create Login Screens** - Google Auth with access key verification
3. **Create Home Screens** - Role-based dashboards
4. **Update App Navigation** - Use new authentication flow

---

## 📞 Support

If you encounter issues:
1. Check Firebase Console for error messages
2. Check Flutter console output
3. Verify all configuration files are in correct locations
4. Review this guide step by step

---

**Setup Complete!** 🎉

Your Firebase backend is now ready for authentication and user management.

