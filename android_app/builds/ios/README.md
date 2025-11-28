# iOS Builds

iOS builds (`.ipa` files) will be placed here after building on macOS.

## Build Command

```bash
cd android_app
flutter build ipa --release
```

The `.ipa` file will be in: `build/ios/ipa/`

## Quick Start on Mac

```bash
# 1. Clone the repo
git clone <repo-url>
cd almed_ahu/android_app

# 2. Get dependencies
flutter pub get

# 3. Install pods
cd ios
pod install
cd ..

# 4. Build
flutter build ios --release
```

## Important

Before building, replace `ios/Runner/GoogleService-Info.plist` with the real file from Firebase Console.

See `ios/IOS_BUILD_GUIDE.md` for detailed instructions.


