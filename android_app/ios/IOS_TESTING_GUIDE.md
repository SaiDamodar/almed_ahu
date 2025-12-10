# iOS Testing Guide - ALMED AHU App

Complete guide for setting up and testing the iOS app on your iPhone using EC2 Mac instance and Xcode.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [EC2 Mac Instance Setup Verification](#ec2-mac-instance-setup-verification)
3. [Xcode Setup](#xcode-setup)
4. [Apple Developer Account Setup](#apple-developer-account-setup)
5. [Firebase Configuration](#firebase-configuration)
6. [Project Configuration](#project-configuration)
7. [Device Registration & Code Signing](#device-registration--code-signing)
8. [Running on iPhone](#running-on-iphone)
9. [Troubleshooting](#troubleshooting)

---

## ⚠️ Pre-Flight Checklist (MUST DO BEFORE TESTING)

Before you can test run the app, complete these **REQUIRED** steps:

### 🔴 Critical: Firebase iOS App Setup

1. **Add iOS App to Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select project: **alemdahu-0107**
   - Click **Settings gear** → **Project settings**
   - Scroll to **Your apps** → Click **Add app** → Select **iOS**
   - Enter Bundle ID: `com.almed.ahu`
   - Click **Register app**
   - **Download** `GoogleService-Info.plist`

2. **Replace Placeholder File**
   - Copy downloaded `GoogleService-Info.plist` to: `android_app/ios/Runner/GoogleService-Info.plist`
   - **Replace** the existing placeholder file

3. **Update Info.plist with REVERSED_CLIENT_ID**
   - Open downloaded `GoogleService-Info.plist` in text editor
   - Find the `REVERSED_CLIENT_ID` key and its value
   - It will look like: `<string>com.googleusercontent.apps.53611520350-xxxxx</string>`
   - Copy the entire string value (without the `<string>` tags)
   - Update `android_app/ios/Runner/Info.plist` line 62:
     - Replace `com.googleusercontent.apps.YOUR_CLIENT_ID` 
     - With your actual `REVERSED_CLIENT_ID` from GoogleService-Info.plist
   
   **Note**: If `REVERSED_CLIENT_ID` is missing from your downloaded file:
   - Check Firebase Console → Project Settings → Your apps → iOS app
   - The REVERSED_CLIENT_ID is automatically generated when you add the iOS app
   - It's always in the format: `com.googleusercontent.apps.{CLIENT_ID_PREFIX}`
   - You can also derive it from CLIENT_ID by reversing: `CLIENT_ID.apps.googleusercontent.com` → `com.googleusercontent.apps.CLIENT_ID`

### ✅ Quick Status Check

Run this to verify current status:
```bash
cd android_app
# Check if GoogleService-Info.plist has real values (not placeholders)
grep -i "YOUR_CLIENT_ID" ios/Runner/GoogleService-Info.plist
# If output shows "YOUR_CLIENT_ID", file is still a placeholder - REPLACE IT!
```

**Current Status**: ❌ **NOT READY** - GoogleService-Info.plist needs to be replaced with real Firebase file

---

## Prerequisites

### Required Software
- **macOS** (Monterey 12.0 or later) - Your EC2 Mac instance
- **Xcode** (14.0 or later) - Install from App Store
- **CocoaPods** - Dependency manager for iOS
- **Flutter SDK** - Already installed (verify with `flutter --version`)
- **Apple Developer Account** - Free account for testing, $99/year for App Store distribution

### Required Accounts
- Apple ID (free) - For device testing
- Apple Developer Account (optional for testing, required for distribution)
- Firebase project access

---

## EC2 Mac Instance Setup Verification

### 1. Verify Flutter Installation
```bash
flutter --version
flutter doctor
```

### 2. Verify Xcode Installation
```bash
xcode-select --version
xcodebuild -version
```

### 3. Accept Xcode License (if needed)
```bash
sudo xcodebuild -license accept
```

### 4. Install CocoaPods
```bash
sudo gem install cocoapods
pod --version
```

### 5. Install Xcode Command Line Tools
```bash
xcode-select --install
```

---

## Xcode Setup

### 1. Open Xcode for First Time
- Launch Xcode from Applications
- Accept license agreements
- Install additional components if prompted

### 2. Sign In to Apple Account
1. Open Xcode
2. Go to **Xcode → Settings (or Preferences) → Accounts**
3. Click **+** button
4. Select **Apple ID**
5. Enter your Apple ID credentials
6. Click **Sign In**

### 3. Download Additional Components (if needed)
- Xcode may prompt to download additional simulators or components
- Allow it to complete

---

## Apple Developer Account Setup

### Option A: Free Apple ID (For Testing Only)
- Use your personal Apple ID
- Limited to 3 devices per year
- Apps expire after 7 days
- **This is sufficient for testing**

### Option B: Paid Developer Account ($99/year)
- Required for App Store distribution
- No device limit
- Apps don't expire
- Required for TestFlight

### Steps:
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Sign in with your Apple ID
3. Accept terms and conditions
4. Your account is now active

---

## Firebase Configuration

### 1. Add iOS App to Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **alemdahu-0107**
3. Click the **Settings gear** → **Project settings**
4. Scroll to **Your apps** section
5. Click **Add app** → Select **iOS**

### 2. Configure iOS App in Firebase

Fill in the details:
- **iOS bundle ID**: `com.almed.ahu` (must match your Xcode project)
- **App nickname**: ALMED AHU iOS (optional)
- **App Store ID**: Leave blank for now

Click **Register app**

### 3. Download GoogleService-Info.plist

1. After registering, download `GoogleService-Info.plist`
2. **Important**: Do NOT add it to Xcode yet (we'll do this in the project)
3. **Find REVERSED_CLIENT_ID**: Open the downloaded file and look for:
   ```xml
   <key>REVERSED_CLIENT_ID</key>
   <string>com.googleusercontent.apps.53611520350-xxxxx</string>
   ```
   - Copy the value inside `<string>` tags
   - This is what you'll use in Info.plist
   - **If REVERSED_CLIENT_ID is missing**: It should always be in the downloaded file. If not, check Firebase Console → Project Settings → Your apps → iOS app configuration

### 4. Enable Required Firebase Services

In Firebase Console:
- **Authentication** → Enable **Email/Password** and **Google** sign-in
- **Cloud Messaging** → Enable (for push notifications)

### 5. Configure Google Sign-In for iOS

1. In Firebase Console → **Authentication → Sign-in method**
2. Enable **Google** sign-in
3. Note the **Web client ID** (you'll need this for Info.plist)

---

## Project Configuration

### 1. Navigate to Project Directory
```bash
cd /path/to/almed_ahu/android_app
```

### 2. Get Flutter Dependencies
```bash
flutter pub get
```

### 3. Install iOS Pods
```bash
cd ios
pod install
cd ..
```

**Note**: If `pod install` fails, try:
```bash
cd ios
pod deintegrate
pod cache clean --all
pod install
cd ..
```

### 4. Replace GoogleService-Info.plist

1. Copy the downloaded `GoogleService-Info.plist` from Firebase
2. Replace the file at: `android_app/ios/Runner/GoogleService-Info.plist`
3. Verify the file contains real values (not placeholders)

### 5. Update Info.plist for Google Sign-In

1. Open `android_app/ios/Runner/Info.plist`
2. Find the `CFBundleURLSchemes` section (around line 55-65)
3. **Get the `REVERSED_CLIENT_ID` from your downloaded `GoogleService-Info.plist`**:
   - Open the downloaded `GoogleService-Info.plist` file in a text editor
   - Search for `<key>REVERSED_CLIENT_ID</key>`
   - The next line will have the value: `<string>com.googleusercontent.apps.53611520350-xxxxx</string>`
   - **Copy the entire string value** (the part between `<string>` and `</string>`)
   - **If you can't find REVERSED_CLIENT_ID**: 
     - Make sure you downloaded the file from Firebase Console (not using the placeholder)
     - Check Firebase Console → Project Settings → Your apps → iOS app → Configuration
     - The REVERSED_CLIENT_ID is automatically included when you add an iOS app to Firebase

4. Update `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID_HERE</string>
        </array>
    </dict>
</array>
```

**Example** (replace with your actual value):
```xml
<string>com.googleusercontent.apps.53611520350-6r6pgjdikm9i0b0sv4r8udh0jg970hh1</string>
```

### 6. Verify Bundle Identifier

1. The bundle ID should be: `com.almed.ahu`
2. This is set in Xcode project settings (we'll verify in next section)

---

## Device Registration & Code Signing

### 1. Connect Your iPhone

1. Connect iPhone to your Mac (via USB or same Wi-Fi network)
2. Unlock your iPhone
3. Trust the computer if prompted (tap "Trust" on iPhone)

### 2. Open Project in Xcode

```bash
cd android_app
open ios/Runner.xcworkspace
```

**Important**: Always open `.xcworkspace`, NOT `.xcodeproj`

### 3. Select Your iPhone as Target

1. In Xcode, look at the top toolbar
2. Click the device selector (next to the Run button)
3. Select your connected iPhone from the list
4. If your iPhone doesn't appear:
   - Make sure it's unlocked
   - Check USB connection
   - Try disconnecting and reconnecting

### 4. Configure Signing & Capabilities

1. In Xcode, click on **Runner** in the left sidebar (blue icon)
2. Select the **Runner** target (under TARGETS)
3. Click on **Signing & Capabilities** tab
4. Check **"Automatically manage signing"**
5. Select your **Team** from the dropdown:
   - If you see "Add an Account...", click it and sign in
   - Select your Apple ID/Developer account
6. Xcode will automatically:
   - Create a provisioning profile
   - Register your device
   - Configure code signing

### 5. Verify Bundle Identifier

1. Still in **Signing & Capabilities**
2. Verify **Bundle Identifier** is: `com.almed.ahu`
3. If different, change it to match Firebase configuration

### 6. Enable Required Capabilities

In **Signing & Capabilities** tab, ensure these are enabled:
- **Push Notifications** (click + Capability if not present)
- **Background Modes** (should already be in Info.plist)

### 7. Trust Developer Certificate on iPhone (First Time Only)

After first build attempt:
1. On your iPhone, go to **Settings → General → VPN & Device Management**
2. Find your developer certificate
3. Tap it and select **Trust**

---

## Running on iPhone

### Method 1: Run from Xcode (Recommended)

1. **Select your iPhone** as the target device (top toolbar)
2. Click the **Play button** (▶) or press `Cmd + R`
3. Xcode will:
   - Build the app
   - Install it on your iPhone
   - Launch it automatically

### Method 2: Run from Terminal (Flutter CLI)

1. List connected devices:
```bash
flutter devices
```

2. Run on your iPhone:
```bash
flutter run -d <device-id>
```

Or if only one device:
```bash
flutter run
```

### Method 3: Build and Install Manually

1. Build the app:
```bash
cd android_app
flutter build ios --debug
```

2. In Xcode:
   - Select your iPhone
   - Click **Product → Run** (or `Cmd + R`)

---

## Troubleshooting

### Issue: "No devices found" or iPhone not appearing

**Solutions:**
1. Unlock your iPhone
2. Trust the computer on iPhone
3. Check USB cable (try different cable/port)
4. Restart Xcode
5. In Xcode: **Window → Devices and Simulators** → Check if iPhone appears
6. Try Wi-Fi connection (Settings → Developer → Enable network connection)

### Issue: "Signing for Runner requires a development team"

**Solutions:**
1. Go to **Signing & Capabilities** in Xcode
2. Select your **Team** from dropdown
3. If no team available:
   - Go to **Xcode → Settings → Accounts**
   - Add your Apple ID
   - Return to project and select team

### Issue: "Failed to register bundle identifier"

**Solutions:**
1. The bundle ID might be taken
2. Change bundle ID in Xcode: **Signing & Capabilities → Bundle Identifier**
3. Update Firebase iOS app with new bundle ID
4. Download new `GoogleService-Info.plist`

### Issue: Pod install fails

**Solutions:**
```bash
cd ios
pod deintegrate
rm -rf Pods Podfile.lock
pod cache clean --all
pod install --repo-update
cd ..
```

### Issue: Build errors related to Firebase

**Solutions:**
1. Verify `GoogleService-Info.plist` is in `ios/Runner/` directory
2. Check that it's added to Xcode project:
   - In Xcode, check if file appears in left sidebar
   - If not, drag and drop it into Runner folder
   - Make sure "Copy items if needed" is checked
3. Clean build:
```bash
cd android_app
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

### Issue: "App installation failed" on iPhone

**Solutions:**
1. Check iPhone storage space
2. Verify iPhone is unlocked
3. Trust developer certificate: **Settings → General → VPN & Device Management**
4. Delete old app if exists and try again
5. Restart iPhone

### Issue: Google Sign-In not working

**Solutions:**
1. Verify `REVERSED_CLIENT_ID` in `Info.plist` matches `GoogleService-Info.plist`
2. Check Firebase Console → Authentication → Sign-in method → Google is enabled
3. Verify bundle ID matches in Firebase and Xcode
4. Check that `GoogleService-Info.plist` is properly added to Xcode project

### Issue: Push notifications not working

**Solutions:**
1. Enable Push Notifications capability in Xcode
2. Verify APNs certificate in Firebase Console
3. Check that device token is being received (check logs)
4. Grant notification permissions on iPhone when prompted

### Issue: Network requests failing

**Solutions:**
1. Check `Info.plist` has `NSAppTransportSecurity` configured
2. Verify API endpoints are accessible
3. Check iPhone's network connection
4. Review app logs in Xcode console

### General Build Issues

**Clean and rebuild:**
```bash
cd android_app
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
cd ios
pod install
cd ..
flutter build ios --debug
```

**Reset Xcode derived data:**
1. In Xcode: **Xcode → Settings → Locations**
2. Click arrow next to **Derived Data** path
3. Delete contents of that folder
4. Rebuild

---

## Testing Checklist

Before testing, verify:

- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] iOS pods installed (`pod install`)
- [ ] `GoogleService-Info.plist` replaced with real file
- [ ] `Info.plist` updated with correct `REVERSED_CLIENT_ID`
- [ ] Bundle ID matches in Xcode and Firebase (`com.almed.ahu`)
- [ ] iPhone connected and trusted
- [ ] Code signing configured in Xcode
- [ ] Team selected in Signing & Capabilities
- [ ] Push Notifications capability enabled
- [ ] App builds successfully
- [ ] App installs on iPhone
- [ ] App launches without crashes
- [ ] Firebase authentication works
- [ ] Google Sign-In works
- [ ] Network requests succeed
- [ ] Push notifications work (if applicable)

---

## Next Steps

### For Development Testing
- Continue using Xcode for debugging
- Use Flutter hot reload: `r` in terminal or `Cmd + R` in Xcode
- Check logs in Xcode console

### For Distribution
1. **TestFlight** (requires paid developer account):
   - Archive app in Xcode
   - Upload to App Store Connect
   - Distribute via TestFlight

2. **App Store** (requires paid developer account):
   - Complete App Store Connect setup
   - Submit for review

---

## Quick Reference Commands

```bash
# Navigate to project
cd android_app

# Get Flutter packages
flutter pub get

# Install iOS dependencies
cd ios && pod install && cd ..

# Check connected devices
flutter devices

# Run on connected iPhone
flutter run

# Build for iOS
flutter build ios --debug

# Clean build
flutter clean
```

---

## Support

If you encounter issues not covered here:
1. Check Xcode console for detailed error messages
2. Review Flutter logs: `flutter doctor -v`
3. Check Firebase Console for configuration issues
4. Verify all files are properly configured

---

**Last Updated**: Based on Flutter 3.0+ and Xcode 14.0+
**Project**: ALMED AHU iOS App
**Bundle ID**: com.almed.ahu

