# Cursor Setup Guide - Run Android Emulator 🎯

This guide will help you run the Android emulator and Flutter app directly from Cursor.

## ✅ Prerequisites

- ✅ Flutter SDK installed
- ✅ Android Studio installed
- ✅ Android SDK command-line tools installed
- ✅ At least one Android Virtual Device (AVD) created

## 🚀 Quick Start

### Option 1: Using the Run Script (Easiest)

1. **Open Cursor Terminal:**
   - Press `` Ctrl+` `` (backtick) to open terminal
   - Or: View → Terminal

2. **Run the script:**
   ```powershell
   cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
   .\run_android.ps1
   ```
   
   This will:
   - List available emulators
   - Start the first available emulator
   - Wait for emulator to boot
   - Run the Flutter app automatically

### Option 2: Manual Steps

#### Step 1: Start Emulator

**Option A: From Android Studio**
1. Open Android Studio
2. Tools → Device Manager
3. Click Play button on your AVD
4. Close Android Studio (emulator stays running)

**Option B: From Cursor Terminal**
```powershell
# List available emulators
flutter emulators

# Launch specific emulator (replace with your emulator name)
flutter emulators --launch Pixel_5_API_33
```

#### Step 2: Run App in Cursor

**Method A: Using F5 (Recommended)**
1. Press `F5` or click "Run and Debug"
2. Select "Flutter (Debug)" from dropdown
3. Select your emulator when prompted
4. App launches!

**Method B: Using Terminal**
```powershell
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"

# Check devices
flutter devices

# Run app
flutter run
```

## 📱 Development Workflow

Once app is running:

- **Hot Reload:** Press `r` in terminal or save file
- **Hot Restart:** Press `R` in terminal
- **Stop:** Press `q` in terminal
- **Debug:** Press `F5` and set breakpoints in code

## 🔧 Cursor Extensions

Install these extensions for better Flutter development:

1. **Flutter** (by Dart Code)
   - Provides debugging, code completion, hot reload
   - Search: "Flutter" in Extensions (Ctrl+Shift+X)

2. **Dart** (by Dart Code)  
   - Usually installed automatically with Flutter extension
   - Provides Dart language support

## 📋 Setup Checklist

- [ ] Flutter extension installed in Cursor
- [ ] AVD created in Android Studio
- [ ] Emulator can start successfully
- [ ] `flutter devices` shows emulator
- [ ] Launch configuration works (F5)

## 🐛 Troubleshooting

### Flutter Extension Not Found
- Open Extensions (Ctrl+Shift+X)
- Search "Flutter"
- Install "Flutter" by Dart Code

### No Devices Found
```powershell
# Check if emulator is running
flutter devices

# If no emulator, start one:
flutter emulators --launch <emulator_name>
```

### Launch Configuration Error
- Ensure `.vscode/launch.json` exists (already created)
- Restart Cursor
- Try running from terminal first: `flutter run`

### Emulator Won't Start
- Check Android SDK installation
- Verify AVD exists: `flutter emulators`
- Try starting from Android Studio first

### Build Errors
```powershell
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
flutter clean
flutter pub get
flutter run
```

## 📝 Useful Commands

```powershell
# List emulators
flutter emulators

# Launch emulator
flutter emulators --launch Pixel_5_API_33

# List connected devices
flutter devices

# Run app
flutter run

# Run on specific device
flutter run -d emulator-5554

# Build APK
flutter build apk

# Check Flutter setup
flutter doctor
flutter doctor -v
```

## 🎯 What Happens When You Run

1. **App Detects Platform:** Running on Android emulator
2. **MQTT Configuration:** Automatically uses HiveMQ Cloud (TLS port 8883)
3. **Firebase Initializes:** If config files added later
4. **UI Loads:** Login screen appears
5. **Hot Reload:** Changes reflect immediately

## 🚀 Next Steps

1. **Start Emulator** (one-time or when needed)
2. **Press F5** in Cursor to run app
3. **Develop** with hot reload enabled
4. **Debug** using breakpoints in Cursor

---

**You're all set!** Just press `F5` in Cursor after starting your emulator! 🎉

