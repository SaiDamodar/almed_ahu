# iOS Build Guide for ALMED AHU

## Prerequisites

1. **macOS** (Monterey 12.0 or later recommended)
2. **Xcode** (14.0 or later) - Install from App Store
3. **CocoaPods** - Install via Terminal:
   ```bash
   sudo gem install cocoapods
   ```
4. **Flutter SDK** - [Install Flutter](https://docs.flutter.dev/get-started/install/macos)
5. **Apple Developer Account** ($99/year for App Store distribution)

## Setup Steps

### 1. Firebase Configuration (REQUIRED)

Replace the placeholder `GoogleService-Info.plist`:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (or create one)
3. Add an iOS app with bundle ID: `com.almed.ahu`
4. Download `GoogleService-Info.plist`
5. Replace `ios/Runner/GoogleService-Info.plist` with the downloaded file

### 2. Update Bundle Identifier

If using a different bundle ID, update in:
- `ios/Runner.xcodeproj/project.pbxproj` (search for `PRODUCT_BUNDLE_IDENTIFIER`)
- `ios/Runner/GoogleService-Info.plist`

### 3. Google Sign-In Setup

1. In Firebase Console, enable Google Sign-In
2. Get your `REVERSED_CLIENT_ID` from `GoogleService-Info.plist`
3. Update `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLSchemes</key>
   <array>
       <string>YOUR_REVERSED_CLIENT_ID</string>
   </array>
   ```

### 4. Install Dependencies

```bash
cd android_app

# Get Flutter packages
flutter pub get

# Install iOS pods
cd ios
pod install
cd ..
```

### 5. Build the App

#### For Testing (Debug)
```bash
flutter run -d ios
```

#### For Release
```bash
flutter build ios --release
```

### 6. Archive for App Store

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Distribute App → App Store Connect

## Troubleshooting

### Pod Install Fails
```bash
cd ios
pod deintegrate
pod cache clean --all
pod install
```

### Build Errors
```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios
```

### Signing Issues
1. Open Xcode
2. Select Runner target
3. Signing & Capabilities → Select your Team
4. Enable "Automatically manage signing"

## App Store Submission Checklist

- [ ] App icons (all sizes in `Assets.xcassets/AppIcon.appiconset`)
- [ ] Launch screen configured
- [ ] Privacy policy URL
- [ ] App description and screenshots
- [ ] GoogleService-Info.plist replaced with real one
- [ ] Push notification capability enabled in Apple Developer Portal
- [ ] Provisioning profiles configured

## Version Info

- **Flutter**: Check with `flutter --version`
- **Min iOS**: 13.0
- **Target iOS**: 17.0+

## Contact

For issues, check the main project README or contact the development team.


