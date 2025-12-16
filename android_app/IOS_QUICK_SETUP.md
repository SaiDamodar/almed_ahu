# iOS Quick Setup Guide for Cursor Agents

Quick reference for setting up iOS app. See `IOS_SETUP_README.md` for detailed instructions.

## Automated Setup

Run the setup script:
```bash
cd android_app
chmod +x setup_ios.sh
./setup_ios.sh
```

## Manual Setup (5 Steps)

```bash
# 1. Fix permissions
sudo chown -R $(whoami):staff ~/path/to/almed_ahu
chmod -R 755 ~/path/to/almed_ahu

# 2. Get Flutter dependencies
cd android_app
flutter clean
flutter pub get

# 3. Install iOS pods
cd ios
pod install --repo-update
cd ..

# 4. Clean Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 5. Build
flutter build ios --simulator
```

## Critical Files to Verify

1. **GoogleService-Info.plist** - Must be real file from Firebase (not placeholder)
2. **Info.plist** - Must have REVERSED_CLIENT_ID (not YOUR_CLIENT_ID)
3. **Podfile** - Must have Swift 5.9 configured
4. **Always open Runner.xcworkspace** (NOT .xcodeproj)

## Common Commands

```bash
# Build for simulator
flutter build ios --simulator

# Run on simulator
flutter run

# Open in Xcode
open ios/Runner.xcworkspace

# Clean everything
flutter clean
cd ios && pod deintegrate && pod install && cd ..
```

## Troubleshooting Quick Fixes

| Error | Fix |
|-------|-----|
| "No such module 'Flutter'" | Open .xcworkspace, not .xcodeproj |
| "No such module 'Firebase'" | Run `pod install` in ios directory |
| Permission errors | Run permission fix commands |
| CocoaPods broken | `sudo gem install cocoapods` |
| Swift errors | Verify Podfile has Swift 5.9 |

## File Locations

- Project: `android_app/`
- iOS Config: `android_app/ios/`
- Podfile: `android_app/ios/Podfile`
- GoogleService: `android_app/ios/Runner/GoogleService-Info.plist`
- Info.plist: `android_app/ios/Runner/Info.plist`

## Success Criteria

✅ `flutter build ios --simulator` completes without errors
✅ Xcode opens without module errors
✅ App builds successfully
✅ App runs on iOS Simulator

