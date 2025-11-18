# Android Project Configuration

This folder contains the Android-specific configuration for the Flutter app.

## Setup

1. **Update `local.properties`**:
   - Set `flutter.sdk` to your Flutter SDK path
   - Example: `flutter.sdk=C\:\\Users\\YourUsername\\flutter`
   - Or set `sdk.dir` to your Android SDK path if needed

2. **Build the app**:
   ```bash
   cd android_app
   flutter build apk --debug
   ```

## Important Files

- `app/build.gradle` - App-level Gradle configuration
- `app/src/main/AndroidManifest.xml` - Android manifest with permissions
- `app/src/main/kotlin/com/almed/ahu_android/MainActivity.kt` - Main activity
- `settings.gradle` - Project settings
- `build.gradle` - Root-level Gradle configuration

## Permissions

The app requires:
- `INTERNET` - For API calls
- `ACCESS_NETWORK_STATE` - To check network connectivity

These are already configured in `AndroidManifest.xml`.

