# Prompt for Cursor Agent: iOS App Setup

## Context

You are helping set up an iOS Flutter app called "ALMED AHU" on an EC2 Mac instance. The Android version is already working, and now we need to configure and build the iOS version.

## Project Overview

- **Project Name**: ALMED AHU (Air Handling Unit monitoring app)
- **Framework**: Flutter
- **Platform**: iOS
- **Environment**: EC2 Mac instance (remote macOS)
- **Bundle ID**: `com.almed.ahu`
- **Firebase Project**: `alemdahu-0107`

## Current State

The project has:
- ✅ Flutter app code (working on Android)
- ✅ iOS project structure created
- ✅ Firebase configured for Android
- ⚠️ iOS needs Firebase configuration
- ⚠️ iOS needs code signing setup
- ⚠️ CocoaPods dependencies need installation
- ⚠️ Permission issues may exist on EC2 Mac

## Your Task

Set up the iOS app so it can build and run on iOS Simulator or device. Follow these steps:

### Step 1: Understand the Project Structure

```
android_app/
├── ios/
│   ├── Podfile                    # CocoaPods configuration
│   ├── Runner.xcworkspace         # Open THIS in Xcode (not .xcodeproj)
│   └── Runner/
│       ├── AppDelegate.swift      # Firebase imports here
│       ├── Info.plist             # Needs REVERSED_CLIENT_ID
│       └── GoogleService-Info.plist # Needs real Firebase file
├── lib/                           # Flutter app code
└── pubspec.yaml                   # Flutter dependencies
```

### Step 2: Fix Permissions (EC2 Mac Specific)

EC2 Mac instances often have permission issues. Fix them first:

```bash
# Get current user
CURRENT_USER=$(whoami)

# Find project path (check common locations)
if [ -d "$HOME/Desktop/Almed App/almed_ahu" ]; then
    PROJECT_PATH="$HOME/Desktop/Almed App/almed_ahu"
elif [ -d "$HOME/almed_ahu" ]; then
    PROJECT_PATH="$HOME/almed_ahu"
else
    # Search for it
    PROJECT_PATH=$(find $HOME -type d -name "almed_ahu" 2>/dev/null | head -1)
fi

# Fix ownership and permissions
sudo chown -R $CURRENT_USER:staff "$PROJECT_PATH"
chmod -R 755 "$PROJECT_PATH"
sudo chmod -R 755 /tmp
sudo chown -R $CURRENT_USER /tmp
mkdir -p ~/Library/Developer/Xcode/DerivedData
chmod -R 755 ~/Library/Developer/Xcode/DerivedData
```

### Step 3: Verify/Install CocoaPods

```bash
# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
    pod setup
fi

# Verify it works
pod --version
```

### Step 4: Get Flutter Dependencies

```bash
cd "$PROJECT_PATH/android_app"
flutter clean
flutter pub get
```

### Step 5: Configure Firebase for iOS

**Critical**: The app uses Firebase for authentication and push notifications.

1. **Check if GoogleService-Info.plist exists and is valid:**
   ```bash
   if grep -qi "YOUR_CLIENT_ID\|your-project-id" ios/Runner/GoogleService-Info.plist; then
       echo "ERROR: GoogleService-Info.plist is still a placeholder!"
       echo "You need to:"
       echo "1. Go to https://console.firebase.google.com"
       echo "2. Select project: alemdahu-0107"
       echo "3. Add iOS app with bundle ID: com.almed.ahu"
       echo "4. Download GoogleService-Info.plist"
       echo "5. Replace ios/Runner/GoogleService-Info.plist"
   fi
   ```

2. **Update Info.plist with REVERSED_CLIENT_ID:**
   ```bash
   # Extract REVERSED_CLIENT_ID from GoogleService-Info.plist
   REVERSED_CLIENT_ID=$(grep -A 1 "REVERSED_CLIENT_ID" ios/Runner/GoogleService-Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
   
   # Update Info.plist if it has placeholder
   if grep -q "YOUR_CLIENT_ID" ios/Runner/Info.plist; then
       sed -i '' "s/com.googleusercontent.apps.YOUR_CLIENT_ID/$REVERSED_CLIENT_ID/g" ios/Runner/Info.plist
   fi
   ```

### Step 6: Verify Podfile Configuration

The Podfile MUST have:
- Swift version 5.9 (Firebase 11.x requires this)
- Experimental features enabled for AccessLevelOnImport
- No explicit Firebase pod declarations (Flutter plugins handle this)

Check the Podfile:
```bash
cd ios
cat Podfile
```

If Swift version is not 5.9, update the post_install block:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['SWIFT_VERSION'] = '5.9'
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

### Step 7: Install iOS Pods

```bash
cd ios
rm -rf Pods Podfile.lock .symlinks
pod deintegrate
pod install --repo-update
cd ..
```

### Step 8: Clean Xcode Derived Data

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### Step 9: Verify Setup

```bash
# Check Flutter setup
flutter doctor

# Try building for simulator (no device needed)
flutter build ios --simulator
```

## Common Issues and Solutions

### Issue: "No such module 'Flutter'"
**Cause**: Opened .xcodeproj instead of .xcworkspace
**Fix**: Always use `open ios/Runner.xcworkspace`

### Issue: "No such module 'Firebase'"
**Cause**: Pods not installed or Xcode can't find them
**Fix**: 
```bash
cd ios
pod install
cd ..
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### Issue: Swift Compilation Errors
**Cause**: Swift version mismatch (Firebase 11.x needs Swift 5.7+)
**Fix**: Ensure Podfile has Swift 5.9 configured

### Issue: Permission Errors
**Cause**: EC2 Mac file ownership issues
**Fix**: Run permission fix commands from Step 2

### Issue: CocoaPods Broken
**Cause**: Ruby version mismatch
**Fix**: 
```bash
sudo gem uninstall cocoapods
sudo gem install cocoapods
pod setup
```

## Success Criteria

The setup is successful when:
1. ✅ `flutter build ios --simulator` completes without errors
2. ✅ Xcode opens `Runner.xcworkspace` without module errors
3. ✅ App builds successfully in Xcode
4. ✅ App runs on iOS Simulator

## Important Notes

1. **ALWAYS open `.xcworkspace`, NEVER `.xcodeproj`**
2. **GoogleService-Info.plist must be real file from Firebase** (not placeholder)
3. **Swift version must be 5.9** for Firebase 11.x compatibility
4. **Permissions must be fixed** on EC2 Mac instances
5. **Use simulator for testing** if device registration is not possible

## Files to Reference

- `IOS_SETUP_README.md` - Detailed setup guide
- `IOS_QUICK_SETUP.md` - Quick reference
- `setup_ios.sh` - Automated setup script
- `ios/Podfile` - CocoaPods configuration
- `ios/Runner/Info.plist` - iOS app configuration
- `ios/Runner/GoogleService-Info.plist` - Firebase configuration

## Workflow Summary

1. Fix permissions → 2. Install CocoaPods → 3. Get Flutter deps → 4. Configure Firebase → 5. Install pods → 6. Build

## Testing

After setup, test with:
```bash
# Build for simulator
flutter build ios --simulator

# Or run directly
flutter run

# Or open in Xcode
open ios/Runner.xcworkspace
```

## Next Steps After Setup

1. Configure code signing in Xcode (if building for device)
2. Register device in Apple Developer Portal (if needed)
3. Test app functionality
4. Build for release (if needed)

---

**Remember**: This is a Flutter app, so most of the app logic is in Dart. The iOS setup is mainly about:
- Configuring Firebase
- Setting up CocoaPods dependencies
- Fixing permissions
- Ensuring proper Swift/Xcode configuration

Good luck! 🚀

