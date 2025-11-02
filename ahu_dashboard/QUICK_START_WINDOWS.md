# Quick Start: Run Android Simulation on Windows 🪟

## Current Status
❌ **Flutter is NOT installed on Windows**

To run the Android simulation, you need to install Flutter SDK and Android Studio first.

---

## Installation Steps

### Step 1: Install Flutter SDK

1. **Download Flutter:**
   - Go to: https://docs.flutter.dev/get-started/install/windows
   - Download Flutter SDK (stable channel)
   - Extract to: `C:\src\flutter`

2. **Add to PATH:**
   - Open Windows Settings → System → About → Advanced system settings
   - Click "Environment Variables"
   - Under "User variables", edit "Path"
   - Add: `C:\src\flutter\bin`
   - Click OK on all dialogs

3. **Restart PowerShell/VS Code**

4. **Verify:**
   ```powershell
   flutter --version
   ```

### Step 2: Install Android Studio

1. **Download:**
   - Go to: https://developer.android.com/studio
   - Download Android Studio for Windows

2. **Install:**
   - Run installer
   - Install Android SDK, Platform-Tools, and Build-Tools
   - Accept all licenses

3. **Set ANDROID_HOME:**
   - Usually located at: `C:\Users\YourName\AppData\Local\Android\Sdk`
   - Add to Environment Variables:
     - Variable: `ANDROID_HOME`
     - Value: `C:\Users\YourName\AppData\Local\Android\Sdk`

### Step 3: Accept Android Licenses

```powershell
flutter doctor --android-licenses
# Type 'y' and press Enter for each license
```

### Step 4: Create Android Emulator

1. **Open Android Studio**
2. **Tools → Device Manager**
3. **Create Device**
4. **Choose:** Pixel 5 or Pixel 6
5. **System Image:** Download API 33 or 34
6. **Finish**

### Step 5: Run Setup Script

```powershell
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
.\setup_windows.ps1
```

This will:
- ✅ Check Flutter installation
- ✅ Enable mobile platforms
- ✅ Install dependencies
- ✅ Check for available devices

### Step 6: Start Emulator & Run App

```powershell
# Option 1: Start from Android Studio
# Open Android Studio → Device Manager → Click Play on emulator

# Option 2: Start from command line
emulator -list-avds  # List available AVDs
emulator -avd Pixel_5_API_33  # Start specific emulator

# Wait for emulator to boot, then run app
flutter run
```

---

## Alternative: Use VS Code with Flutter Extension

1. **Install VS Code Flutter Extension:**
   - Open VS Code
   - Extensions → Search "Flutter"
   - Install Flutter extension

2. **Run from VS Code:**
   - Open `ahu_dashboard` folder in VS Code
   - Press `F5` or click "Run and Debug"
   - Select "Flutter" and device
   - App will launch on emulator

---

## Quick Commands

```powershell
# Navigate to project
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"

# Check setup
.\setup_windows.ps1

# List devices
flutter devices

# Run app
flutter run

# Build APK
flutter build apk

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
# Quit: Press 'q' in terminal
```

---

## Troubleshooting

### Flutter Command Not Found
- ✅ Add `C:\src\flutter\bin` to PATH
- ✅ Restart PowerShell/VS Code
- ✅ Verify: `flutter --version`

### Android SDK Not Found
- ✅ Install Android Studio
- ✅ Set ANDROID_HOME environment variable
- ✅ Verify: `flutter doctor`

### Emulator Won't Start
- ✅ Enable Virtualization in BIOS
- ✅ Install Intel HAXM (for Intel processors)
- ✅ Enable Windows Hypervisor Platform (for AMD)

### Gradle Build Failed
```powershell
cd android
.\gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

---

## What's Already Ready

Your project is already configured for mobile:
- ✅ Android platform files created
- ✅ iOS platform files created
- ✅ Firebase dependencies added
- ✅ MQTT service with TLS support
- ✅ Platform detection (mobile uses cloud MQTT)

---

## Next Steps After Installation

1. **Install Flutter SDK** (Step 1 above)
2. **Install Android Studio** (Step 2 above)
3. **Run setup script:** `.\setup_windows.ps1`
4. **Start emulator** from Android Studio
5. **Run app:** `flutter run`

The app will automatically:
- Detect it's running on mobile (emulator)
- Connect to HiveMQ Cloud with TLS
- Use cloud MQTT broker

---

**Need help?** See `WINDOWS_SETUP_GUIDE.md` for detailed instructions.

