# Fix Android SDK Command-Line Tools Issue

## Problem
```
Android sdkmanager not found. Update to the latest Android SDK and ensure that the cmdline-tools are installed.
```

## Solution: Install Android SDK Command-Line Tools

### Option 1: Using Android Studio (Recommended)

1. **Open Android Studio**
2. **Go to:** Settings (File → Settings) or (Ctrl+Alt+S)
3. **Navigate to:** Appearance & Behavior → System Settings → Android SDK
4. **Click on:** "SDK Tools" tab
5. **Check these items:**
   - ✅ Android SDK Command-line Tools (latest)
   - ✅ Android SDK Build-Tools
   - ✅ Android SDK Platform-Tools
   - ✅ Android SDK Platform (API 33 or 34)
6. **Click:** "Apply" and let it download/install
7. **Click:** "OK" when done

### Option 2: Using SDK Manager Command Line

1. **Download command-line tools:**
   - Go to: https://developer.android.com/studio#command-tools
   - Download "Command line tools only" for Windows
   - Extract to: `C:\Users\YourName\AppData\Local\Android\Sdk\cmdline-tools\latest`

2. **Set Environment Variable:**
   - Add to PATH: `C:\Users\YourName\AppData\Local\Android\Sdk\cmdline-tools\latest\bin`

### Option 3: Set ANDROID_HOME and PATH

1. **Find Android SDK Location:**
   - Usually: `C:\Users\YourName\AppData\Local\Android\Sdk`
   - Or check Android Studio: Settings → Android SDK → Android SDK Location

2. **Set ANDROID_HOME Environment Variable:**
   ```powershell
   # PowerShell (temporary)
   $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
   
   # Or set permanently:
   [Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")
   ```

3. **Add to PATH:**
   - Add: `%ANDROID_HOME%\platform-tools`
   - Add: `%ANDROID_HOME%\tools`
   - Add: `%ANDROID_HOME%\cmdline-tools\latest\bin`
   - Add: `%ANDROID_HOME%\tools\bin`

4. **Restart PowerShell/Terminal**

## Verify Installation

```powershell
# Check ANDROID_HOME
echo $env:ANDROID_HOME

# Check if sdkmanager exists
sdkmanager --version

# If sdkmanager is found, install command-line tools:
sdkmanager "cmdline-tools;latest"
```

## Accept Licenses After Fix

Once command-line tools are installed:

```powershell
flutter doctor --android-licenses
# Type 'y' for each license
```

## Quick Fix Script

Run this PowerShell script:

```powershell
# Set ANDROID_HOME
$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_HOME = $androidSdk

# Check if cmdline-tools exists
$cmdlineTools = "$androidSdk\cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $cmdlineTools)) {
    Write-Host "Command-line tools not found. Installing via Android Studio..." -ForegroundColor Yellow
    Write-Host "1. Open Android Studio" -ForegroundColor White
    Write-Host "2. Settings -> Android SDK -> SDK Tools" -ForegroundColor White
    Write-Host "3. Check 'Android SDK Command-line Tools (latest)'" -ForegroundColor White
    Write-Host "4. Click Apply" -ForegroundColor White
} else {
    Write-Host "Command-line tools found!" -ForegroundColor Green
}

# Try accepting licenses
flutter doctor --android-licenses
```

## After Fixing

1. **Restart PowerShell/VS Code**
2. **Run setup script:**
   ```powershell
   cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
   .\setup_windows.ps1
   ```
3. **Verify:**
   ```powershell
   flutter doctor
   ```

---

**The easiest fix:** Install command-line tools through Android Studio SDK Manager.

