# ALMED AHU Android App

Flutter-based Android application for monitoring and controlling Air Handling Units (AHUs) in hospital environments.

## Features

- **Admin Authentication**: Secure login with admin credentials
- **Hospital Management**: View all hospitals and their AHU units
- **Real-time Monitoring**: Live telemetry data (temperature, humidity, system status)
- **AHU Control**: Start/stop system, adjust setpoints, control fan speed
- **Admin Features**: WiFi provisioning, broker settings, motor timing configuration
- **User Management**: Admin interface for hospital user registration (future)

## Installation Steps

### Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your PATH
   - Verify installation: `flutter doctor`

2. **Android Studio**
   - Download from: https://developer.android.com/studio
   - Install Android SDK (API level 21 or higher)
   - Install Flutter and Dart plugins

3. **Java Development Kit (JDK)**
   - JDK 11 or higher
   - Set JAVA_HOME environment variable

### Setup Steps

1. **Clone/Navigate to the project**
   ```bash
   cd android_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API endpoint**
   - Edit `lib/config/app_config.dart`
   - Set `baseUrl` to your web dashboard URL (e.g., `http://your-server:5000`)

4. **Run code generation** (for JSON serialization)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Connect Android device or start emulator**
   - Enable Developer Options and USB Debugging on your Android device
   - Or start an Android emulator from Android Studio

6. **Build and run**
   ```bash
   flutter run
   ```

### Building APK

**Debug APK:**
```bash
flutter build apk --debug
```

**Release APK:**
```bash
flutter build apk --release
```

The APK will be in `build/app/outputs/flutter-apk/`

### Building App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

## Configuration

### API Configuration

Edit `lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String baseUrl = 'http://your-server:5000';
  static const String apiBaseUrl = '$baseUrl/api';
}
```

### Login Credentials

- **Username**: `admin`
- **Password**: `1234`

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/
│   └── app_config.dart      # API configuration
├── models/                  # Data models
│   ├── hospital.dart
│   ├── ahu_unit.dart
│   ├── ahu_state.dart
│   └── ahu_telemetry.dart
├── services/
│   └── api_service.dart     # HTTP API client
├── providers/
│   ├── app_provider.dart    # Main state management
│   └── theme_provider.dart  # Theme management
├── screens/
│   ├── login_screen.dart
│   ├── hospitals_screen.dart
│   ├── ahus_screen.dart
│   ├── ahu_control_screen.dart
│   └── admin_screen.dart
└── theme/
    └── app_theme.dart        # Light/Dark theme
```

## Troubleshooting

### Connection Issues
- Verify web dashboard is running and accessible
- Check API endpoint in `app_config.dart`
- Ensure device/emulator can reach the server (check firewall)

### Build Errors
- Run `flutter clean` then `flutter pub get`
- Ensure all dependencies are compatible
- Check Flutter version: `flutter --version`

### Runtime Errors
- Check device logs: `flutter logs`
- Verify API responses in network tab
- Ensure MongoDB is accessible from web dashboard

## License

Proprietary - ALMED Systems

