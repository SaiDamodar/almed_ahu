# Complete Installation Steps for ALMED AHU Android App

## Prerequisites

### 1. Install Flutter SDK
- Download from: https://flutter.dev/docs/get-started/install
- Extract and add to PATH
- Verify: `flutter doctor`
- Install Android Studio and Android SDK if prompted

### 2. Install Android Studio
- Download from: https://developer.android.com/studio
- Install Android SDK (API level 21 or higher)
- Install Flutter and Dart plugins:
  - File → Settings → Plugins → Search "Flutter" → Install
  - This will also install Dart plugin

### 3. Set up Android Device/Emulator
**Option A: Physical Device**
- Enable Developer Options on Android phone
- Enable USB Debugging
- Connect via USB

**Option B: Android Emulator**
- Open Android Studio
- Tools → Device Manager → Create Virtual Device
- Select a device (e.g., Pixel 5)
- Download and select a system image (API 30+)
- Click Finish

## Installation Steps

### Step 1: Navigate to Project
```bash
cd android_app
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Configure API Endpoint
Edit `lib/config/app_config.dart`:

```dart
// For Android Emulator (accesses host machine's localhost)
static const String baseUrl = 'http://10.0.2.2:5000';

// For Physical Device (use your server's IP address)
// static const String baseUrl = 'http://192.168.1.100:5000';
```

**Important:**
- Emulator: Use `10.0.2.2` to access host machine
- Physical device: Use actual server IP (e.g., `192.168.1.100`)
- Ensure web dashboard is running on port 5000
- Check firewall allows port 5000

### Step 4: Generate Code (Required)
Run build_runner to generate JSON serialization code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates:
- `lib/models/ahu_state.g.dart`
- `lib/models/ahu_telemetry.g.dart`

### Step 5: Copy Assets (Optional)
If you have logo images:
```bash
# Create assets folder
mkdir -p assets/images

# Copy logo files (if available)
# cp ../ahu_dashboard/assets/images/logo_*.png assets/images/
```

### Step 6: Run the App
```bash
# List available devices
flutter devices

# Run on connected device/emulator
flutter run
```

## Building APK

### Debug APK (for testing)
```bash
flutter build apk --debug
```
Location: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for distribution)
```bash
flutter build apk --release
```
Location: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Location: `build/app/outputs/bundle/release/app-release.aab`

## First Run

1. **Launch the app** on your device/emulator
2. **Login** with:
   - Username: `admin`
   - Password: `1234`
3. **View Hospitals** - You should see all hospitals from MongoDB
4. **Select Hospital** - Tap to see AHUs
5. **Control AHU** - Tap AHU to open control screen

## Troubleshooting

### "Connection refused" or "Failed to connect"
- ✅ Check web dashboard is running: `http://YOUR_SERVER_IP:5000`
- ✅ Verify `baseUrl` in `app_config.dart`
- ✅ Check firewall allows port 5000
- ✅ For emulator, use `10.0.2.2:5000`
- ✅ For physical device, use actual server IP

### "No hospitals found"
- ✅ Check MongoDB connection in web dashboard
- ✅ Verify devices are registered in MongoDB
- ✅ Check web dashboard logs for errors

### Build errors with models
- ✅ Run: `flutter pub run build_runner build --delete-conflicting-outputs`
- ✅ Clean build: `flutter clean && flutter pub get`

### App crashes on startup
- ✅ Check Flutter version: `flutter --version` (need 3.0.0+)
- ✅ Run: `flutter doctor` to check setup
- ✅ Check logs: `flutter logs`

## Features Checklist

✅ Admin login (admin/1234)
✅ Hospitals list view
✅ AHUs list per hospital  
✅ Real-time status polling (every 5 seconds)
✅ AHU control (start/stop, temperature, humidity, fan speed)
✅ Admin features (WiFi provisioning, broker settings, motor timings)
✅ Dark/Light theme toggle
✅ Responsive design

## Next Steps

1. Test all features
2. Customize theme colors if needed
3. Add hospital user registration (placeholder ready)
4. Implement WebSocket for real-time updates
5. Add charts for historical data
6. Configure for production deployment

## Support

For issues:
1. Check `SETUP.md` for detailed troubleshooting
2. Review web dashboard logs
3. Check Flutter logs: `flutter logs`
4. Verify API responses in network inspector

