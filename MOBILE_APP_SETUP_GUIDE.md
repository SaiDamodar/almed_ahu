# Mobile App Setup Guide - Next Steps

## Current Situation

You have a complete Flutter dashboard (`ahu_dashboard/`) that works on Linux/Raspberry Pi. Now you need to build the mobile version for iOS and Android.

## Option 1: Use Existing ahu_dashboard (Recommended for Quick Start)

### Convert Current Dashboard to Mobile

Your `ahu_dashboard` can be made mobile-compatible by adding platform-specific code. Since you have the Flutter SDK on Raspberry Pi, you can:

1. **On Raspberry Pi (where Flutter is installed):**
   ```bash
   cd /home/almed/Documents/almed_ahu/ahu_dashboard
   
   # Enable mobile platforms
   flutter create --platforms=android,ios .
   
   # Build for mobile
   flutter build apk --release  # Android
   flutter build ios --release  # iOS (if you have macOS)
   ```

### Required Changes

You'll need to update these files:

**1. Update `pubspec.yaml`:**
```yaml
# Add mobile-specific dependencies
dependencies:
  # ... existing dependencies ...
  firebase_auth: ^4.15.0      # Add Firebase Auth
  firebase_core: ^2.24.0       # Add Firebase Core
  firebase_messaging: ^14.7.0  # Add Firebase Messaging
  firebase_storage: ^11.5.0    # Add Firebase Storage
  cloud_firestore: ^4.13.0     # Add Firestore
  mqtt_client: ^10.2.0         # Already have this
  fl_chart: ^0.70.1            # Already have this
```

**2. Update MQTT Service for TLS (Cloud):**

File: `lib/services/mqtt_service.dart`

```dart
import 'dart:io';

class MqttService {
  // Add TLS support
  Future<bool> connect({bool useTLS = false}) async {
    try {
      _client = MqttServerClient(broker, 'mobile_${DateTime.now().millisecondsSinceEpoch}');
      _client!.port = port;
      
      // Enable TLS for cloud connection
      if (useTLS) {
        _client!.secure = true;
        _client!.securityContext = SecurityContext.defaultContext;
      }
      
      // ... rest of connection code
    } catch (e) {
      print('MQTT: Connection error - $e');
      return false;
    }
  }
}
```

**3. Add Firebase Integration:**

Create `lib/services/firebase_service.dart`:
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signInWithGoogle() async {
    // Implement Google Sign-In
  }

  Future<List<String>> getAssignedDevices(String userId) async {
    // Query Firestore for user's assigned devices
  }
}
```

**4. Update App Provider for Cloud MQTT:**

File: `lib/providers/app_provider.dart`:
```dart
Future<bool> initializeMqtt({String? brokerUrl, bool isMobile = false}) async {
  // Mobile uses cloud broker
  if (isMobile) {
    _mqttService = MqttService(
      broker: brokerUrl ?? 'ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud',
      port: 8883,
      username: 'almed',
      password: 'AlMed123456',
    );
    return await _mqttService!.connect(useTLS: true);
  } else {
    // Desktop uses local broker
    _mqttService = MqttService(
      broker: '127.0.0.1',
      port: 1883,
      username: 'almed',
      password: 'Almed1234\$',
    );
    return await _mqttService!.connect(useTLS: false);
  }
}
```

---

## Option 2: Create Separate Mobile Project

### On Raspberry Pi (Recommended)

If you prefer a separate mobile project:

```bash
cd /home/almed/Documents/almed_ahu

# Create new mobile project
flutter create almed_mobile

# Copy shared code from ahu_dashboard
cp -r ahu_dashboard/lib/models almed_mobile/lib/
cp -r ahu_dashboard/lib/widgets almed_mobile/lib/
cp ahu_dashboard/lib/services/mqtt_service.dart almed_mobile/lib/services/
cp ahu_dashboard/lib/theme/app_theme.dart almed_mobile/lib/theme/

# Navigate to mobile project
cd almed_mobile

# Add dependencies
flutter pub add firebase_auth firebase_core firebase_messaging cloud_firestore
flutter pub add mqtt_client:^10.2.0 provider shared_preferences fl_chart intl

# Build
flutter build apk --release
```

---

## Required Mobile-Specific Updates

### 1. Firebase Setup

**Download Firebase Config Files:**
- `google-services.json` (Android) - from Firebase Console
- `GoogleService-Info.plist` (iOS) - from Firebase Console

**Place files in:**
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 2. Update Android Configuration

**File: `android/app/build.gradle`:**
```gradle
dependencies {
    // ... existing dependencies ...
    implementation platform('com.google.firebase:firebase-bom:32.6.0')
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-firestore'
    implementation 'com.google.firebase:firebase-messaging'
}
```

**File: `android/build.gradle`:**
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

### 3. Update iOS Configuration

**File: `ios/Podfile`:**
```ruby
platform :ios, '13.0'

target 'Runner' do
  # ... existing pods ...
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Messaging'
end
```

### 4. Add Permissions

**Android: `android/app/src/main/AndroidManifest.xml`**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

**iOS: `ios/Runner/Info.plist`**
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs network access to control AHU devices</string>
```

---

## Cloud MQTT Connection Details

### HiveMQ Cloud (Already Configured)

From your documentation:
```
Broker: ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud
Port: 8883 (TLS)
Username: almed
Password: AlMed123456
```

### Update MQTT Service

```dart
// lib/services/mqtt_service.dart
class MqttService {
  Future<bool> connect() async {
    _client = MqttServerClient.withPort(
      'ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud',
      'mobile_${DateTime.now().millisecondsSinceEpoch}',
      8883,
    );
    
    // Enable TLS
    _client!.secure = true;
    _client!.securityContext = SecurityContext.defaultContext;
    
    // ... rest of connection code
  }
}
```

---

## Firebase Database Structure

Create these Firestore collections:

### `users` Collection
```json
{
  "userId": "user123",
  "email": "doctor@hospital.com",
  "name": "Dr. John Doe",
  "role": "hospital_staff",
  "assignedDevices": ["ahu-01", "ahu-02"],
  "createdAt": "2025-01-01T00:00:00Z"
}
```

### `tickets` Collection
```json
{
  "ticketId": "TKT-2025-001",
  "deviceId": "ahu-01",
  "createdBy": "user123",
  "category": "Hardware",
  "priority": "High",
  "status": "Open",
  "description": "Device making noise",
  "createdAt": "2025-01-01T00:00:00Z"
}
```

---

## Next Steps

### Immediate (You Can Do on Raspberry Pi)

1. **Enable Mobile Platforms:**
   ```bash
   cd /home/almed/Documents/almed_ahu/ahu_dashboard
   flutter create --platforms=android,ios .
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub add firebase_auth firebase_core firebase_messaging cloud_firestore
   ```

3. **Build Android APK:**
   ```bash
   flutter build apk --release
   ```

### For iOS Build (Requires macOS)

- You'll need a Mac with Xcode installed
- Or use cloud build services like Codemagic

### Cloud Services Setup

1. **Firebase Console:**
   - Create project: https://console.firebase.google.com/
   - Enable Authentication (Email, Google)
   - Create Firestore database
   - Download config files

2. **HiveMQ Cloud:**
   - Already configured! ✅

3. **InfluxDB Cloud:**
   - Already configured in mqtt_bridge.py ✅

---

## Testing Checklist

- [ ] Build Android APK successfully
- [ ] Install on Android device
- [ ] Firebase authentication works
- [ ] MQTT connects to HiveMQ Cloud
- [ ] Can see real-time telemetry
- [ ] Can send commands (start/stop)
- [ ] Push notifications work
- [ ] Historical graphs load from InfluxDB
- [ ] Ticket system functional

---

## Development Workflow

### Option A: Develop on Raspberry Pi
- Use existing Flutter installation
- SSH into Pi for development
- Build and test on connected Android device

### Option B: Use VS Code Remote SSH
- Connect to Pi from Windows
- Edit code directly on Pi
- Use Flutter plugins in VS Code

### Option C: Copy Project to Windows
- Git clone on Windows
- Install Flutter SDK on Windows
- Use Android Studio

---

## Quick Start Commands

```bash
# Navigate to project
cd /home/almed/Documents/almed_ahu/ahu_dashboard

# Install dependencies
flutter pub get

# Enable mobile
flutter create --platforms=android,ios .

# Run on connected device
flutter run

# Build APK
flutter build apk --release

# Build iOS (requires macOS)
flutter build ios --release
```

---

## Need Help?

Check these documentation files:
- `MOBILE_APP_COMPLETE_PLAN.md` - Full implementation details
- `MOBILE_APP_QUICK_REFERENCE.md` - Quick commands
- `Firebase_quick_setup_guide.md` - Firebase setup
- `HIVEMQ_SETUP_QUICK_START.md` - MQTT configuration

---

**Ready to build? Start with enabling mobile platforms on your Raspberry Pi!** 🚀

