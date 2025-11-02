# Setting Up Android Emulator on Windows

This guide will help you install Flutter and set up an Android emulator on Windows.

## 📋 Prerequisites

- Windows 10/11 (64-bit)
- At least 8GB RAM (16GB recommended)
- 20GB free disk space
- Administrator privileges

## 🚀 Step-by-Step Setup

### Step 1: Install Flutter SDK

1. **Download Flutter:**
   - Go to https://flutter.dev/docs/get-started/install/windows
   - Download Flutter SDK for Windows
   - Extract to `C:\src\flutter` (or your preferred location)

2. **Add Flutter to PATH:**
   - Open Windows Settings → System → About → Advanced system settings
   - Click "Environment Variables"
   - Under "User variables", find "Path" and click "Edit"
   - Click "New" and add: `C:\src\flutter\bin`
   - Click OK on all dialogs

3. **Verify Installation:**
   ```powershell
   flutter --version
   ```

### Step 2: Install Android Studio

1. **Download Android Studio:**
   - Go to https://developer.android.com/studio
   - Download and install Android Studio

2. **Install Android SDK:**
   - Open Android Studio
   - Go to Tools → SDK Manager
   - In "SDK Platforms" tab, check:
     - Android 13.0 (Tiramisu) - API Level 33
     - Android 12.0 (S) - API Level 31
   - In "SDK Tools" tab, check:
     - Android SDK Build-Tools
     - Android Emulator
     - Android SDK Platform-Tools
     - Google Play services
     - Intel x86 Emulator Accelerator (HAXM installer)
   - Click "Apply" and wait for installation

3. **Set ANDROID_HOME:**
   - Open Environment Variables (same as Step 1)
   - Create new "User variable":
     - Name: `ANDROID_HOME`
     - Value: `C:\Users\YourUsername\AppData\Local\Android\Sdk`
   - Add to PATH:
     - `%ANDROID_HOME%\platform-tools`
     - `%ANDROID_HOME%\tools`
     - `%ANDROID_HOME%\tools\bin`

### Step 3: Create Android Virtual Device (AVD)

1. **Open AVD Manager:**
   - In Android Studio: Tools → Device Manager
   - Or click the device icon in the toolbar

2. **Create Virtual Device:**
   - Click "Create Device"
   - Select a device (e.g., Pixel 5)
   - Click "Next"

3. **Select System Image:**
   - Choose "Release Name" (e.g., Tiramisu - API 33)
   - Click "Download" if needed
   - Click "Next"

4. **Configure AVD:**
   - Name: `Pixel_5_API_33`
   - Click "Finish"

### Step 4: Verify Setup

Run Flutter doctor:
```powershell
flutter doctor
```

Fix any issues it reports. Common fixes:
- **Android toolchain**: Accept Android licenses: `flutter doctor --android-licenses`
- **VS Code**: Install Flutter extension (optional)

### Step 5: Enable Mobile Platforms in Your Project

```powershell
cd "E:\dev files\New folder\almed_ahu\ahu_dashboard"

# Enable Android and iOS platforms
flutter create --platforms=android,ios .

# Install dependencies
flutter pub get
```

### Step 6: Start Android Emulator

1. **Start from Android Studio:**
   - Open Android Studio
   - Tools → Device Manager
   - Click the play button next to your AVD

2. **Start from Command Line:**
   ```powershell
   flutter emulators --launch <emulator_id>
   ```

### Step 7: Run Your App

```powershell
cd "E:\dev files\New folder\almed_ahu\ahu_dashboard"

# List available devices
flutter devices

# Run on emulator
flutter run
```

## 🎯 Quick Commands

### List Devices
```powershell
flutter devices
```

### List Emulators
```powershell
flutter emulators
```

### Launch Specific Emulator
```powershell
flutter emulators --launch <emulator_id>
```

### Run App
```powershell
flutter run
```

### Build APK
```powershell
flutter build apk
```

## 🔧 Troubleshooting

### Flutter Not Found
- Ensure Flutter is added to PATH
- Restart terminal/PowerShell
- Verify: `where flutter` should show path

### Android SDK Not Found
- Verify ANDROID_HOME is set
- Check: `echo $env:ANDROID_HOME` in PowerShell
- Update PATH variables

### Emulator Won't Start
- Enable virtualization in BIOS (VT-x or AMD-V)
- Install HAXM (Intel) or enable Hyper-V (Windows 10 Pro)
- Check: Windows Features → Hyper-V (if using Hyper-V)

### Build Errors
```powershell
flutter clean
flutter pub get
flutter build apk
```

### Accept Android Licenses
```powershell
flutter doctor --android-licenses
```

## 📱 Recommended AVD Configuration

For best performance:
- **Device**: Pixel 5 or Pixel 6
- **API Level**: 33 (Android 13) or 31 (Android 12)
- **RAM**: 2048 MB minimum
- **Graphics**: Hardware - GLES 2.0
- **Storage**: 8 GB minimum

## ✅ Verification Checklist

- [ ] Flutter installed and in PATH
- [ ] Android Studio installed
- [ ] Android SDK installed
- [ ] ANDROID_HOME set
- [ ] AVD created
- [ ] Emulator starts successfully
- [ ] `flutter doctor` shows no critical issues
- [ ] `flutter devices` shows emulator
- [ ] App runs on emulator

## 🚀 Next Steps

Once emulator is running:

1. **Add Firebase Config:**
   - Add `google-services.json` to `android/app/`

2. **Run App:**
   ```powershell
   flutter run
   ```

3. **Test Features:**
   - Verify MQTT connects to HiveMQ Cloud
   - Test Firebase authentication
   - Check UI responsiveness

---

**Need help?** Run `flutter doctor -v` for detailed diagnostics.

