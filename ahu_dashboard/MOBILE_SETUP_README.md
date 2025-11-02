# Mobile App Setup - Complete Guide

This guide will help you set up the mobile app for Android and iOS.

## ✅ What's Been Done

1. **Firebase dependencies added** to `pubspec.yaml`
2. **Platform detection** added to `app_provider.dart` - automatically uses cloud MQTT on mobile
3. **Firebase service** created with authentication and messaging support
4. **Android configuration** files created
5. **iOS configuration** files created
6. **Main.dart** updated to initialize Firebase on mobile platforms

## 🚀 Quick Start

### Step 1: Enable Mobile Platforms

On your Raspberry Pi (or system with Flutter installed):

```bash
cd /home/almed/Documents/almed_ahu/ahu_dashboard

# Make setup script executable
chmod +x setup_mobile.sh

# Run setup script
./setup_mobile.sh

# OR manually enable platforms
flutter create --platforms=android,ios .
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Firebase Setup

1. **Create Firebase Project:**
   - Go to https://console.firebase.google.com/
   - Create a new project (e.g., "ALMED AHU Control")
   - Enable Authentication (Email/Password and Google)
   - Create Firestore database

2. **Download Config Files:**
   - Android: Download `google-services.json`
     - Place in: `android/app/google-services.json`
   - iOS: Download `GoogleService-Info.plist`
     - Place in: `ios/Runner/GoogleService-Info.plist`

3. **Update Firestore Security Rules:**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       match /tickets/{ticketId} {
         allow read: if request.auth != null;
         allow create: if request.auth != null;
         allow update: if request.auth != null && 
           (resource.data.createdBy == request.auth.uid || 
            get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
       }
     }
   }
   ```

### Step 4: Build and Test

#### Android

```bash
# Build APK
flutter build apk --release

# Or build for connected device
flutter run
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

#### iOS (requires macOS)

```bash
# Build iOS
flutter build ios --release

# Or run in simulator/device
flutter run
```

## 📱 Mobile Features

### Platform Detection
The app automatically detects if it's running on mobile:
- **Mobile (Android/iOS)**: Uses HiveMQ Cloud MQTT broker (TLS encrypted)
- **Desktop/Linux**: Uses local MQTT broker (127.0.0.1:1883)

### MQTT Configuration
- **Cloud Broker**: `ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud:8883`
- **TLS Enabled**: Secure connection for mobile
- **Auto-connect**: Connects on app startup

### Firebase Features
- **Authentication**: Email/Password and Google Sign-In
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **User Management**: Firestore for user data and device assignments
- **Ticket System**: Support ticket creation and management

## 📂 Project Structure

```
ahu_dashboard/
├── lib/
│   ├── main.dart                    # ✅ Firebase initialization
│   ├── services/
│   │   ├── mqtt_service.dart         # ✅ TLS support for cloud
│   │   └── firebase_service.dart     # ✅ Authentication & messaging
│   └── providers/
│       └── app_provider.dart         # ✅ Platform detection
├── android/
│   ├── app/
│   │   ├── build.gradle             # ✅ Firebase config
│   │   └── src/main/
│   │       └── AndroidManifest.xml   # ✅ Permissions
│   └── build.gradle                  # ✅ Google services plugin
├── ios/
│   ├── Podfile                      # ✅ Firebase pods
│   └── Runner/
│       └── Info.plist               # ✅ Permissions
└── pubspec.yaml                      # ✅ Firebase dependencies
```

## 🔧 Configuration Files

### Android

**android/app/build.gradle:**
- Firebase BOM and dependencies
- Google services plugin

**android/app/src/main/AndroidManifest.xml:**
- Internet permission
- Network state permission
- Boot completed permission (for background tasks)

### iOS

**ios/Podfile:**
- Firebase/Auth pod
- Firebase/Firestore pod
- Firebase/Messaging pod
- Firebase/Storage pod

**ios/Runner/Info.plist:**
- Network usage description
- Location usage description (if needed)

## 📋 Testing Checklist

### Connection Tests
- [ ] MQTT connects to HiveMQ Cloud with TLS
- [ ] Can subscribe to telemetry topics
- [ ] Receives real-time data from ESP32
- [ ] Can publish commands successfully

### Firebase Tests
- [ ] Firebase initializes on app start
- [ ] Email/Password authentication works
- [ ] User data loads from Firestore
- [ ] Device assignment filtering works
- [ ] Push notifications received

### UI Tests
- [ ] Login screen displays
- [ ] Dashboard shows devices
- [ ] Device detail screen works
- [ ] Control buttons functional
- [ ] Graphs render correctly

## 🐛 Troubleshooting

### Firebase Not Initializing

**Error**: `Firebase: Initialization error`
**Solution**: 
- Ensure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location
- Run `flutter clean` and `flutter pub get`

### MQTT Connection Failed

**Error**: `MQTT: Connection failed`
**Solution**:
- Check internet connection
- Verify HiveMQ Cloud credentials
- Check firewall settings for port 8883

### Build Errors

**Android:**
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter build apk
```

**iOS:**
```bash
flutter clean
cd ios
pod deintegrate
pod install
cd ..
flutter pub get
flutter build ios
```

## 📚 Next Steps

1. **Add Google Sign-In:**
   - Configure OAuth in Firebase Console
   - Update `firebase_service.dart` with Google Sign-In implementation

2. **Implement Device Assignment:**
   - Create Firestore collection for device-user assignments
   - Filter devices in dashboard based on user assignments

3. **Add Push Notifications:**
   - Configure FCM in Firebase Console
   - Handle notification taps and background messages

4. **Historical Data:**
   - Add InfluxDB queries for historical graphs
   - Implement date range selection

## 🎉 Summary

Your mobile app is now ready to build! The key changes:

✅ **Automatic platform detection** - Mobile uses cloud MQTT, desktop uses local  
✅ **Firebase integration** - Authentication and messaging ready  
✅ **TLS support** - Secure MQTT connections on mobile  
✅ **Android/iOS configs** - All platform files in place  

**Next**: Run `flutter create --platforms=android,ios .` (if not done), add Firebase config files, and build!

---

For more details, see:
- `MOBILE_APP_SETUP_GUIDE.md` - Full setup instructions
- `MOBILE_APP_STATUS.md` - Current status
- `Firebase_quick_setup_guide.md` - Firebase configuration

