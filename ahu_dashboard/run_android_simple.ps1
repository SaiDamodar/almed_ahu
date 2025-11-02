# Simplified script to launch emulator and run Flutter app
# This version manually specifies the emulator ID

Write-Host "Starting Android Emulator and Flutter App" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

# Navigate to project
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Your emulator ID (change if different)
$emulatorId = "Medium_Phone_API_36.1"

Write-Host "Launching emulator: $emulatorId" -ForegroundColor Yellow
Start-Process -NoNewWindow flutter -ArgumentList "emulators", "--launch", $emulatorId

Write-Host "Waiting for emulator to boot (30-60 seconds)..." -ForegroundColor Yellow
Write-Host "You can see progress in the emulator window that opened." -ForegroundColor Gray
Write-Host ""

# Wait a bit for emulator to start
Start-Sleep -Seconds 10

# Wait for emulator to be ready
$maxWait = 90
$waitTime = 0
$deviceReady = $false

Write-Host "Checking for emulator..." -ForegroundColor Yellow
while ($waitTime -lt $maxWait -and -not $deviceReady) {
    Start-Sleep -Seconds 3
    $waitTime += 3
    
    $devicesOutput = flutter devices 2>&1 | Out-String
    
    if ($devicesOutput -match "emulator-(\d+)") {
        Write-Host ""
        Write-Host "Emulator ready!" -ForegroundColor Green
        $deviceReady = $true
        break
    }
    
    Write-Host "." -NoNewline -ForegroundColor Gray
}

if (-not $deviceReady) {
    Write-Host ""
    Write-Host "Emulator taking longer than expected..." -ForegroundColor Yellow
    Write-Host "Trying to run app anyway..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "Running Flutter app..." -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

flutter run

