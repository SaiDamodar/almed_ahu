# Mobile App - Quick Start 🚀

## ✅ What's Ready

Your mobile app is now configured! Here's what's been done:

1. ✅ **Firebase dependencies** added to `pubspec.yaml`
2. ✅ **Platform detection** - Mobile automatically uses HiveMQ Cloud with TLS
3. ✅ **Firebase service** - Authentication and messaging ready
4. ✅ **Android config** - All necessary files created
5. ✅ **iOS config** - All necessary files created
6. ✅ **Main.dart** - Firebase initialization on mobile

## 🎯 Next Steps

### 1. Enable Mobile Platforms (On Raspberry Pi)

```bash
cd /home/almed/Documents/almed_ahu/ahu_dashboard

# Make script executable (if needed)
chmod +x setup_mobile.sh

# Run setup OR manually:
flutter create --platforms=android,ios .
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Add Firebase Config Files

**Android:**
- Download `google-services.json` from Firebase Console
- Place in: `android/app/google-services.json`

**iOS:**
- Download `GoogleService-Info.plist` from Firebase Console  
- Place in: `ios/Runner/GoogleService-Info.plist`

### 4. Build!

**Android:**
```bash
flutter build apk --release
```

**iOS (macOS required):**
```bash
flutter build ios --release
```

## 🔑 Key Features

### Automatic Platform Detection
- **Mobile**: Uses HiveMQ Cloud (`ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud:8883`) with TLS
- **Desktop/Linux**: Uses local broker (`127.0.0.1:1883`)

### Firebase Ready
- Email/Password authentication
- Google Sign-In (needs OAuth setup)
- Push notifications (FCM)
- User management (Firestore)

## 📚 Documentation

- `MOBILE_SETUP_README.md` - Complete setup guide
- `MOBILE_APP_SETUP_GUIDE.md` - Detailed instructions
- `MOBILE_APP_STATUS.md` - Current status

## 🐛 Troubleshooting

**Firebase error?** → Add config files (`google-services.json` / `GoogleService-Info.plist`)

**Build fails?** → Run `flutter clean` and `flutter pub get`

**MQTT won't connect?** → Check internet and HiveMQ Cloud credentials

---

**Ready to build!** 🎉

