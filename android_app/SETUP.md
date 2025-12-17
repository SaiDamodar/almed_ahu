# Android App Setup Guide

## Quick Start

1. **Install Flutter** (if not already installed)
   ```bash
   # Download from https://flutter.dev/docs/get-started/install
   # Add to PATH
   flutter doctor
   ```

2. **Navigate to project**
   ```bash
   cd android_app
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Configure API endpoint**
   - Edit `lib/config/app_config.dart`
   - Set `baseUrl` to your web dashboard URL:
     - For Android emulator: `http://10.0.2.2:5000`
     - For physical device: `http://YOUR_SERVER_IP:5000`
     - Example: `http://192.168.1.100:5000`

5. **Generate code** (for JSON serialization)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

## Building APK

### Debug APK
```bash
flutter build apk --debug
```

### Release APK
```bash
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

## Configuration

### API Configuration (`lib/config/app_config.dart`)

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5000';
```

**Important Notes:**
- Android emulator uses `10.0.2.2` to access host machine's localhost
- Physical devices need the actual server IP address
- Ensure web dashboard is running and accessible
- Check firewall settings if connection fails

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
│   ├── ahu_state.dart       # Requires build_runner
│   └── ahu_telemetry.dart   # Requires build_runner
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
│   ├── admin_screen.dart
│   └── user_auth_screen.dart
└── theme/
    └── app_theme.dart        # Light/Dark theme
```

## Troubleshooting

### Connection Issues
1. **Check API endpoint**: Verify `baseUrl` in `app_config.dart`
2. **Test web dashboard**: Open `http://YOUR_SERVER_IP:5000` in browser
3. **Check network**: Ensure device/emulator can reach server
4. **Firewall**: Allow port 5000 on server
5. **CORS**: Web dashboard should allow all origins (already configured)

### Build Errors
1. **Clean build**: `flutter clean && flutter pub get`
2. **Code generation**: Run `build_runner` if models fail
3. **Flutter version**: Ensure Flutter 3.0.0+

### Runtime Errors
1. **Check logs**: `flutter logs`
2. **API response**: Verify web dashboard returns expected JSON
3. **MongoDB**: Ensure web dashboard can connect to MongoDB

## Features

✅ Admin login (admin/1234)
✅ Hospitals list view
✅ AHUs list per hospital
✅ Real-time AHU control (start/stop, setpoints, fan speed)
✅ Admin features (WiFi provisioning, broker settings, motor timings)
✅ Dark/Light theme toggle
✅ Responsive design

## Next Steps

- [ ] Add hospital user registration (placeholder ready)
- [ ] Implement WebSocket for real-time updates (currently polling)
- [ ] Add charts/graphs for historical data
- [ ] Add OTA update functionality
- [ ] Add push notifications

