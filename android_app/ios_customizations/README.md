# iOS Customizations

This folder contains custom files that need to be applied after Flutter generates a fresh iOS folder.

## Files

### 1. **Podfile**
- Custom Podfile with Swift 5.9 configuration
- Firebase 11.x compatibility settings
- Experimental features enabled for AccessLevelOnImport

**Usage**: Copy to `ios/Podfile` after generating iOS folder

### 2. **AppDelegate.swift**
- Custom AppDelegate with Firebase imports
- Firebase configuration
- Push notification setup
- Firebase Messaging delegate

**Usage**: Copy to `ios/Runner/AppDelegate.swift` after generating iOS folder

### 3. **Info.plist.additions**
- Firebase Cloud Messaging settings
- Google Sign-In URL scheme configuration
- Network security settings

**Usage**: Add these entries to `ios/Runner/Info.plist` before the closing `</dict>` tag. Replace `REVERSED_CLIENT_ID_PLACEHOLDER` with actual REVERSED_CLIENT_ID from GoogleService-Info.plist

## When to Use

These files are used when:
1. Setting up iOS on a fresh EC2 Mac instance
2. Regenerating the iOS folder with `flutter create --platforms=ios .`
3. Starting from scratch

## Application Order

1. Generate iOS folder: `flutter create --platforms=ios .`
2. Copy Podfile: `cp ios_customizations/Podfile ios/Podfile`
3. Copy AppDelegate: `cp ios_customizations/AppDelegate.swift ios/Runner/AppDelegate.swift`
4. Add Info.plist additions manually (or use script)
5. Copy GoogleService-Info.plist from Firebase
6. Update REVERSED_CLIENT_ID in Info.plist
7. Run `pod install`

