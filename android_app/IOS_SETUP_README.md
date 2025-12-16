# iOS App Setup Guide for ALMED AHU

This guide provides complete instructions for setting up and building the iOS app on EC2 Mac instance. Follow these steps in order.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Firebase Configuration](#firebase-configuration)
4. [Project Configuration](#project-configuration)
5. [Build and Run](#build-and-run)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software
- **macOS** (Monterey 12.0 or later) - EC2 Mac instance
- **Xcode** (14.0 or later) - Install from App Store
- **CocoaPods** - Dependency manager for iOS
- **Flutter SDK** - Already installed (verify with `flutter --version`)
- **Apple Developer Account** - Free Apple ID for testing

### Verify Installation
```bash
# Check Flutter
flutter --version
flutter doctor

# Check Xcode
xcode-select --version
xcodebuild -version

# Check CocoaPods
pod --version
```

---

## Initial Setup

### Step 1: Fix Permissions (Important for EC2)

```bash
# Get current user
CURRENT_USER=$(whoami)

# Fix project directory permissions (adjust path as needed)
PROJECT_PATH="$HOME/Desktop/Almed App/almed_ahu"
# OR if in different location:
# PROJECT_PATH="$HOME/almed_ahu"

sudo chown -R $CURRENT_USER:staff "$PROJECT_PATH"
chmod -R 755 "$PROJECT_PATH"

# Fix Flutter SDK permissions
sudo chown -R $CURRENT_USER:staff /usr/local/share/flutter
chmod -R 755 /usr/local/share/flutter

# Fix temporary directories
sudo chmod -R 755 /tmp
sudo chown -R $CURRENT_USER /tmp

# Fix Xcode derived data
mkdir -p ~/Library/Developer/Xcode/DerivedData
chmod -R 755 ~/Library/Developer/Xcode/DerivedData

# Fix CocoaPods directories
mkdir -p ~/.cocoapods
chmod -R 755 ~/.cocoapods
chmod -R 755 ~/Library/Caches/CocoaPods
```

### Step 2: Install/Reinstall CocoaPods (If Needed)

```bash
# Check if CocoaPods is working
pod --version

# If not working, reinstall:
sudo gem uninstall cocoapods
sudo gem install cocoapods
pod setup

# Verify installation
pod --version
```

### Step 3: Navigate to Project

```bash
cd "$PROJECT_PATH/android_app"
# OR
cd ~/almed_ahu/android_app
```

---

## Firebase Configuration

### Step 1: Add iOS App to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **alemdahu-0107**
3. Click **Settings gear** → **Project settings**
4. Scroll to **Your apps** section
5. Click **Add app** → Select **iOS**
6. Enter Bundle ID: `com.almed.ahu`
7. Click **Register app**
8. **Download** `GoogleService-Info.plist`

### Step 2: Replace GoogleService-Info.plist

```bash
# Copy downloaded file to iOS Runner directory
cp ~/Downloads/GoogleService-Info.plist android_app/ios/Runner/GoogleService-Info.plist

# Verify file exists and has real values (not placeholders)
grep -i "YOUR_CLIENT_ID" android_app/ios/Runner/GoogleService-Info.plist
# Should return nothing if file is correct
```

### Step 3: Update Info.plist with REVERSED_CLIENT_ID

```bash
# Get REVERSED_CLIENT_ID from GoogleService-Info.plist
REVERSED_CLIENT_ID=$(grep -A 1 "REVERSED_CLIENT_ID" android_app/ios/Runner/GoogleService-Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

# Update Info.plist (replace placeholder)
sed -i '' "s/com.googleusercontent.apps.YOUR_CLIENT_ID/$REVERSED_CLIENT_ID/g" android_app/ios/Runner/Info.plist

# Verify update
grep "$REVERSED_CLIENT_ID" android_app/ios/Runner/Info.plist
```

---

## Project Configuration

### Step 1: Get Flutter Dependencies

```bash
cd android_app
flutter clean
flutter pub get
```

### Step 2: Verify Podfile Configuration

The Podfile should have:
- Swift version set to 5.9 (for Firebase 11.x compatibility)
- Experimental features enabled for AccessLevelOnImport
- No explicit Firebase pod declarations (Flutter plugins handle this)

**Current Podfile configuration:**
```ruby
platform :ios, '13.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['SWIFT_VERSION'] = '5.9'
      # Enable experimental features
      other_swift_flags = config.build_settings['OTHER_SWIFT_FLAGS'] || ['$(inherited)']
      unless other_swift_flags.any? { |flag| flag.include?('AccessLevelOnImport') }
        other_swift_flags << '-Xfrontend'
        other_swift_flags << '-enable-experimental-feature=AccessLevelOnImport'
      end
      config.build_settings['OTHER_SWIFT_FLAGS'] = other_swift_flags.uniq
    end
  end
end
```

### Step 3: Install iOS Pods

```bash
cd ios

# Clean old pods
rm -rf Pods Podfile.lock .symlinks
pod deintegrate

# Install pods
pod install --repo-update

# Verify installation
ls -la Pods/

# Go back to project root
cd ..
```

### Step 4: Clean Xcode Derived Data

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

---

## Build and Run

### Option 1: Build for iOS Simulator (No Device Needed)

```bash
cd android_app

# Build for simulator
flutter build ios --simulator

# Or run directly on simulator
flutter run
```

### Option 2: Build from Xcode

```bash
# Open workspace (IMPORTANT: Use .xcworkspace, NOT .xcodeproj)
open ios/Runner.xcworkspace
```

In Xcode:
1. Select iOS Simulator from device dropdown (top toolbar)
2. **Product → Clean Build Folder** (`Shift + Cmd + K`)
3. **Product → Build** (`Cmd + B`) or **Product → Run** (`Cmd + R`)

### Option 3: Build for Device (Requires Device Registration)

**First, register device:**
1. Get iPhone UDID (Settings → General → About → Identifier)
2. Register at: https://developer.apple.com/account
   - Certificates, Identifiers & Profiles → Devices → Register
3. In Xcode: **Settings → Accounts → Download Manual Profiles**

**Then build:**
```bash
flutter build ios --debug
```

---

## Troubleshooting

### Issue: "No such module 'Flutter'"

**Solution:**
```bash
# Close Xcode
killall Xcode

# Clean and reinstall
cd android_app
flutter clean
flutter pub get
cd ios
pod install
cd ..

# Reopen workspace (NOT project)
open ios/Runner.xcworkspace
```

### Issue: "No such module 'Firebase'"

**Solution:**
```bash
# Ensure you opened .xcworkspace, not .xcodeproj
open ios/Runner.xcworkspace

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Reinstall pods
cd ios
pod install
cd ..
```

### Issue: Swift Compilation Errors (FirebaseCoreInternal)

**Solution:**
- Verify Podfile has Swift 5.9 set
- Verify experimental features are enabled
- Clean and rebuild:
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --simulator
```

### Issue: CocoaPods Not Working

**Solution:**
```bash
# Reinstall CocoaPods
sudo gem uninstall cocoapods
sudo gem install cocoapods
pod setup

# Verify
pod --version
```

### Issue: Permission Errors

**Solution:**
```bash
# Fix all permissions
CURRENT_USER=$(whoami)
sudo chown -R $CURRENT_USER:staff "$PROJECT_PATH"
chmod -R 755 "$PROJECT_PATH"
sudo chmod -R 755 /tmp
```

### Issue: "No profiles for 'com.almed.ahu' were found"

**Solution:**
- For Simulator: No profile needed, just select simulator
- For Device: Register device in Apple Developer Portal first

### Issue: Build Errors After Pod Install

**Solution:**
```bash
# Complete clean rebuild
cd android_app
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf ~/Library/Developer/Xcode/DerivedData/*
flutter pub get
cd ios
pod deintegrate
pod install --repo-update
cd ..
open ios/Runner.xcworkspace
```

---

## Quick Reference Commands

### Complete Setup (Run Once)
```bash
# Set project path
PROJECT_PATH="$HOME/Desktop/Almed App/almed_ahu"
cd "$PROJECT_PATH/android_app"

# Fix permissions
CURRENT_USER=$(whoami)
sudo chown -R $CURRENT_USER:staff "$PROJECT_PATH"
chmod -R 755 "$PROJECT_PATH"

# Setup Flutter
flutter clean
flutter pub get

# Setup iOS
cd ios
rm -rf Pods Podfile.lock .symlinks
pod deintegrate
pod install --repo-update
cd ..

# Clean Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Open in Xcode
open ios/Runner.xcworkspace
```

### Quick Build
```bash
cd android_app
flutter build ios --simulator
```

### Quick Run
```bash
cd android_app
flutter run
```

---

## File Structure

```
android_app/
├── ios/
│   ├── Podfile                    # CocoaPods configuration (Swift 5.9)
│   ├── Runner.xcworkspace         # Open this in Xcode (NOT .xcodeproj)
│   └── Runner/
│       ├── AppDelegate.swift      # Firebase imports here
│       ├── Info.plist             # REVERSED_CLIENT_ID configured here
│       └── GoogleService-Info.plist # From Firebase Console
└── lib/                           # Flutter app code
```

---

## Important Notes

1. **Always open `Runner.xcworkspace`, NOT `Runner.xcodeproj`**
2. **Swift version must be 5.9** for Firebase 11.x compatibility
3. **GoogleService-Info.plist must be real file** from Firebase, not placeholder
4. **REVERSED_CLIENT_ID must match** in Info.plist and GoogleService-Info.plist
5. **Permissions must be fixed** on EC2 Mac instances
6. **Use simulator for testing** if device registration is not possible

---

## Verification Checklist

Before building, verify:
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] iOS pods installed (`pod install`)
- [ ] GoogleService-Info.plist replaced with real file
- [ ] Info.plist updated with REVERSED_CLIENT_ID
- [ ] Podfile has Swift 5.9 configured
- [ ] Permissions fixed on project directory
- [ ] Xcode derived data cleaned
- [ ] Opening .xcworkspace (not .xcodeproj)

---

## Success Indicators

When setup is complete, you should be able to:
- ✅ Run `flutter build ios --simulator` without errors
- ✅ Open Xcode and see no module errors
- ✅ Build successfully in Xcode
- ✅ Run app on iOS Simulator

---

## Support

If issues persist:
1. Check Xcode console for detailed error messages
2. Review Flutter logs: `flutter doctor -v`
3. Verify all files are properly configured
4. Check Firebase Console for iOS app configuration

---

**Last Updated:** Based on Flutter 3.38.4, Xcode 15.4, Firebase 11.x
**Project:** ALMED AHU iOS App
**Bundle ID:** com.almed.ahu

