# Windows Setup Guide - Android Emulator 🪟

This guide will help you set up Flutter and run Android emulator on Windows.

## Prerequisites Checklist

- [ ] Flutter SDK installed
- [ ] Android Studio installed
- [ ] Android SDK installed
- [ ] Android emulator created
- [ ] PATH configured

## Step 1: Install Flutter SDK on Windows

### Option A: Direct Download (Recommended)

1. **Download Flutter:**
   - Go to: https://docs.flutter.dev/get-started/install/windows
   - Download Flutter SDK for Windows (stable channel)
   - Extract to `C:\src\flutter` (or any path without spaces)

2. **Add to PATH:**
   - Open "Environment Variables" in Windows Settings
   - Edit System/User PATH variable
   - Add: `C:\src\flutter\bin` (or your Flutter path)
   - Restart terminal/PowerShell

3. **Verify:**
   ```powershell
   flutter --version
   flutter doctor
   ```

### Option B: Using Git (Advanced)

```powershell
cd C:\src
git clone https://github.com/flutter/flutter.git -b stable
```

## Step 2: Install Android Studio

1. **Download:**
   - Go to: https://developer.android.com/studio
   - Download Android Studio for Windows

2. **Install:**
   - Run installer
   - Install Android SDK, Android SDK Platform, and Android Virtual Device
   - Accept licenses when prompted

3. **Configure:**
   - Open Android Studio
   - Go to Settings → Appearance & Behavior → System Settings → Android SDK
   - Install Android SDK Platform-Tools
   - Install Android SDK Build-Tools

## Step 3: Set Android Environment Variables

1. **Find Android SDK Location:**
   - Usually: `C:\Users\YourName\AppData\Local\Android\Sdk`
   - Or check Android Studio: Settings → Android SDK → Android SDK Location

2. **Set ANDROID_HOME:**
   ```powershell
   # PowerShell (temporary for current session)
   $env:ANDROID_HOME = "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
   
   # Or set permanently:
   [Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")
   ```

3. **Add to PATH:**
   - Add: `%ANDROID_HOME%\platform-tools`
   - Add: `%ANDROID_HOME%\tools`
   - Add: `%ANDROID_HOME%\tools\bin`

## Step 4: Accept Android Licenses

```powershell
flutter doctor --android-licenses
# Accept all licenses by typing 'y' and pressing Enter
```

## Step 5: Create Android Emulator

### Using Android Studio (Easiest)

1. **Open Android Studio**
2. **Tools → Device Manager**
3. **Create Device**
4. **Choose:** Pixel 5 or Pixel 6 (recommended)
5. **System Image:** Download and select latest API (API 33 or 34)
6. **Finish**

### Using Command Line

```powershell
# List available system images
sdkmanager --list | Select-String "system-images"

# Install a system image (example for API 33)
sdkmanager "system-images;android-33;google_apis;x86_64"

# Create AVD
avdmanager create avd -n Pixel_5_API_33 -k "system-images;android-33;google_apis;x86_64"
```

## Step 6: Run Flutter Doctor

```powershell
flutter doctor -v
```

Fix any issues shown:
- ✅ Flutter (Channel stable)
- ✅ Android toolchain
- ✅ Android Studio
- ✅ VS Code (optional)
- ✅ Connected device

## Step 7: Enable Mobile Platforms & Run

```powershell
# Navigate to project
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"

# Enable mobile platforms (if not done)
flutter create --platforms=android,ios .

# Install dependencies
flutter pub get

# Check available devices
flutter devices

# Start emulator (if not running)
# Option 1: From Android Studio Device Manager - click play
# Option 2: Command line:
emulator -avd Pixel_5_API_33

# Wait for emulator to boot, then run app
flutter run
```

## Quick Commands

### Start Emulator
```powershell
# List AVDs
emulator -list-avds

# Start specific AVD
emulator -avd Pixel_5_API_33
```

### Flutter Commands
```powershell
# List devices
flutter devices

# Run on connected device/emulator
flutter run

# Run on specific device
flutter run -d emulator-5554

# Build APK
flutter build apk

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
# Quit: Press 'q' in terminal
```

## Troubleshooting

### Flutter Not Found
- **Problem:** `flutter` command not recognized
- **Solution:** Add Flutter to PATH or restart terminal

### Android SDK Not Found
- **Problem:** `ANDROID_HOME` not set
- **Solution:** Set ANDROID_HOME environment variable

### Emulator Won't Start
- **Problem:** HAXM or Hyper-V issues
- **Solution:** 
  - Enable Virtualization in BIOS
  - For Intel: Install Intel HAXM
  - For AMD: Enable Windows Hypervisor Platform

### Gradle Build Failed
- **Problem:** Build errors
- **Solution:**
  ```powershell
  cd android
  ./gradlew clean
  cd ..
  flutter clean
  flutter pub get
  ```

### Firebase Config Missing
- **Problem:** Firebase initialization errors
- **Solution:** Add `google-services.json` to `android/app/` (optional for now - app will work without it)

## Automated Setup Script

Create `setup_windows.ps1`:

```powershell
# Check Flutter
Write-Host "Checking Flutter..." -ForegroundColor Yellow
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "✅ Flutter found" -ForegroundColor Green
    flutter --version
} else {
    Write-Host "❌ Flutter not found. Please install Flutter SDK first." -ForegroundColor Red
    exit 1
}

# Check Android SDK
Write-Host "`nChecking Android SDK..." -ForegroundColor Yellow
$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
if (Test-Path $androidSdk) {
    Write-Host "✅ Android SDK found at: $androidSdk" -ForegroundColor Green
} else {
    Write-Host "❌ Android SDK not found. Please install Android Studio." -ForegroundColor Red
    exit 1
}

# Run Flutter Doctor
Write-Host "`nRunning Flutter Doctor..." -ForegroundColor Yellow
flutter doctor

# Enable mobile platforms
Write-Host "`nEnabling mobile platforms..." -ForegroundColor Yellow
flutter create --platforms=android,ios .

# Install dependencies
Write-Host "`nInstalling dependencies..." -ForegroundColor Yellow
flutter pub get

# List devices
Write-Host "`nAvailable devices:" -ForegroundColor Yellow
flutter devices

Write-Host "`n✨ Setup complete! Run 'flutter run' to start the app." -ForegroundColor Green
```

Run it:
```powershell
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
.\setup_windows.ps1
```

## Next Steps

Once everything is set up:

1. **Start emulator** (from Android Studio or command line)
2. **Run app:**
   ```powershell
   flutter run
   ```
3. **Test features:**
   - Login screen
   - MQTT connection (will use HiveMQ Cloud on mobile)
   - Dashboard display

---

**Need help?** Check:
- Flutter docs: https://docs.flutter.dev/get-started/install/windows
- Android Studio docs: https://developer.android.com/studio

