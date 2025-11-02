# PowerShell script to help set up Flutter on Windows
# Run this as Administrator for best results

Write-Host "🚀 Flutter & Android Setup for Windows" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚠️  Not running as Administrator. Some steps may require admin rights." -ForegroundColor Yellow
}

# Check Flutter installation
Write-Host "📋 Checking Flutter installation..." -ForegroundColor Green
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
    if ($flutterVersion) {
        Write-Host "✅ Flutter is installed" -ForegroundColor Green
        flutter --version | Select-Object -First 3
    } else {
        Write-Host "❌ Flutter not found in PATH" -ForegroundColor Red
        Write-Host ""
        Write-Host "To install Flutter:" -ForegroundColor Yellow
        Write-Host "1. Download from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor White
        Write-Host "2. Extract to C:\src\flutter (or your preferred location)" -ForegroundColor White
        Write-Host "3. Add C:\src\flutter\bin to your PATH environment variable" -ForegroundColor White
        Write-Host "4. Restart PowerShell and run this script again" -ForegroundColor White
        exit 1
    }
} catch {
    Write-Host "❌ Flutter not found. Please install Flutter first." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Check Android SDK
Write-Host "📋 Checking Android SDK..." -ForegroundColor Green
$androidHome = $env:ANDROID_HOME
if ($androidHome) {
    Write-Host "✅ ANDROID_HOME is set: $androidHome" -ForegroundColor Green
} else {
    $defaultPath = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $defaultPath) {
        Write-Host "⚠️  ANDROID_HOME not set, but found SDK at: $defaultPath" -ForegroundColor Yellow
        Write-Host "Setting ANDROID_HOME for this session..." -ForegroundColor Yellow
        $env:ANDROID_HOME = $defaultPath
        [Environment]::SetEnvironmentVariable("ANDROID_HOME", $defaultPath, "User")
    } else {
        Write-Host "❌ Android SDK not found" -ForegroundColor Red
        Write-Host ""
        Write-Host "To install Android SDK:" -ForegroundColor Yellow
        Write-Host "1. Install Android Studio from: https://developer.android.com/studio" -ForegroundColor White
        Write-Host "2. Open Android Studio → SDK Manager" -ForegroundColor White
        Write-Host "3. Install Android SDK Platform 33 and SDK Tools" -ForegroundColor White
        Write-Host "4. Set ANDROID_HOME environment variable" -ForegroundColor White
    }
}

Write-Host ""

# Run Flutter Doctor
Write-Host "📋 Running Flutter Doctor..." -ForegroundColor Green
flutter doctor

Write-Host ""
Write-Host "📋 Checking for Android Emulators..." -ForegroundColor Green
$emulators = flutter emulators 2>&1
if ($emulators -match "No devices detected") {
    Write-Host "⚠️  No emulators found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To create an emulator:" -ForegroundColor Yellow
    Write-Host "1. Open Android Studio" -ForegroundColor White
    Write-Host "2. Tools → Device Manager" -ForegroundColor White
    Write-Host "3. Create Device → Select Pixel 5 → API 33" -ForegroundColor White
    Write-Host "4. Finish and start the emulator" -ForegroundColor White
} else {
    Write-Host "✅ Found emulators:" -ForegroundColor Green
    flutter emulators
}

Write-Host ""
Write-Host "📋 Checking available devices..." -ForegroundColor Green
flutter devices

Write-Host ""
Write-Host "✨ Setup check complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. If Flutter doctor shows issues, fix them first" -ForegroundColor White
Write-Host "2. Accept Android licenses: flutter doctor --android-licenses" -ForegroundColor White
Write-Host "3. Start an emulator from Android Studio or run: flutter emulators --launch <id>" -ForegroundColor White
Write-Host "4. Run your app: flutter run" -ForegroundColor White

