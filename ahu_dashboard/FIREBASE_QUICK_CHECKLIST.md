# Firebase Setup Quick Checklist

## 🚀 Console Setup (Do in Firebase Console)

### ✅ Project Setup
- [ ] Create Firebase project at https://console.firebase.google.com/
- [ ] Project name: `almed-ahu-control` (or your choice)

### ✅ Android App Setup
- [ ] Add Android app with package: `com.almed.ahu_dashboard`
- [ ] Download `google-services.json`
- [ ] Place file in: `ahu_dashboard/android/app/google-services.json`

### ✅ Authentication
- [ ] Go to Authentication → Sign-in method
- [ ] Enable Google Sign-In
- [ ] Add support email

### ✅ Firestore Database
- [ ] Create Firestore database (Test mode initially)
- [ ] Choose closest location

### ✅ Create Sample Users

**Admin User:**
- [ ] Collection: `users`
- [ ] Document ID: `admin@almed.com` (your email)
- [ ] Fields:
  - `email`: string → `admin@almed.com`
  - `role`: string → `admin`
  - `isActive`: boolean → `true`
  - `createdAt`: timestamp → (click now)

**Client User:**
- [ ] Document ID: `nurse@hospital.com` (example)
- [ ] Fields:
  - `email`: string → `nurse@hospital.com`
  - `role`: string → `client`
  - `accessKey`: string → `HOSP2024KEY`
  - `assignedDevices`: array → `["icu-1"]` (your AHU ID)
  - `isActive`: boolean → `true`
  - `createdAt`: timestamp → (click now)

### ✅ Security Rules
- [ ] Go to Firestore → Rules
- [ ] Paste security rules (see FIREBASE_SETUP_COMPLETE.md)
- [ ] Click "Publish"

### ✅ SHA-1 Fingerprint
- [ ] Run: `cd android && .\gradlew signingReport`
- [ ] Copy SHA1 value
- [ ] Firebase Console → Project Settings → Android App → Add fingerprint
- [ ] Paste SHA1 and save

---

## ✅ Code Changes (Already Done)

- [x] `google_sign_in` dependency added to `pubspec.yaml`
- [x] `firebase_service.dart` updated with Google Sign-In
- [x] User verification methods implemented

---

## 🧪 Test

```powershell
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
flutter pub get
flutter run
```

Test Google Sign-In in your app!

---

**Time Required:** ~15-20 minutes for Firebase Console setup

**Difficulty:** Easy - Just follow the steps in order

