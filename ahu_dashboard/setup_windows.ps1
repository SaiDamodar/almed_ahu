# Windows Setup Script for Flutter Mobile App
# This script helps set up and run the Android emulator on Windows

Write-Host "Windows Flutter Setup for AHU Dashboard" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Step 1: Check Flutter
Write-Host "[1/5] Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterCheck = flutter --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $flutterVersion = $flutterCheck | Select-Object -First 1
        Write-Host "OK - Flutter found: $flutterVersion" -ForegroundColor Green
    } else {
        throw "Flutter not found"
    }
} catch {
    Write-Host "ERROR - Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Flutter SDK:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor White
    Write-Host "2. Extract to C:\src\flutter (or any path)" -ForegroundColor White
    Write-Host "3. Add to PATH: C:\src\flutter\bin" -ForegroundColor White
    Write-Host "4. Restart PowerShell and run this script again" -ForegroundColor White
    exit 1
}

# Step 2: Check Android SDK
Write-Host ""
Write-Host "[2/5] Checking Android SDK..." -ForegroundColor Yellow
$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
if (Test-Path $androidSdk) {
    Write-Host "OK - Android SDK found at: $androidSdk" -ForegroundColor Green
    $env:ANDROID_HOME = $androidSdk
} else {
    Write-Host "WARNING - Android SDK not found in default location" -ForegroundColor Yellow
    Write-Host "Please install Android Studio and Android SDK" -ForegroundColor White
    Write-Host "Download: https://developer.android.com/studio" -ForegroundColor White
}

# Step 3: Run Flutter Doctor
Write-Host ""
Write-Host "[3/5] Running Flutter Doctor..." -ForegroundColor Yellow
flutter doctor
Write-Host ""

# Step 4: Enable mobile platforms (if needed)
Write-Host "[4/5] Checking mobile platforms..." -ForegroundColor Yellow
if (Test-Path "android") {
    Write-Host "OK - Android platform already enabled" -ForegroundColor Green
} else {
    Write-Host "Enabling Android platform..." -ForegroundColor Yellow
    flutter create --platforms=android,ios . 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK - Mobile platforms enabled" -ForegroundColor Green
    } else {
        Write-Host "WARNING - Platform setup may have issues" -ForegroundColor Yellow
    }
}

# Step 5: Install dependencies
Write-Host ""
Write-Host "[5/5] Installing dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK - Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "WARNING - Some dependencies may have issues" -ForegroundColor Yellow
}

# Check for devices
Write-Host ""
Write-Host "Checking available devices..." -ForegroundColor Yellow
flutter devices

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Start Android Emulator:" -ForegroundColor White
Write-Host "   - Open Android Studio -> Device Manager -> Start emulator" -ForegroundColor Gray
Write-Host "   - OR run: emulator -avd <avd_name>" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Run the app:" -ForegroundColor White
Write-Host "   flutter run" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. If emulator is running, the app will launch automatically" -ForegroundColor Gray
Write-Host ""
