# Quick script to start Android emulator and run Flutter app
# Run this from Cursor terminal or PowerShell

Write-Host "🚀 Starting Android Emulator and Flutter App" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

# Navigate to project
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Step 1: List available emulators
Write-Host "[1/3] Checking available emulators..." -ForegroundColor Yellow
$emulators = flutter emulators 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR - Flutter not found or emulators command failed" -ForegroundColor Red
    Write-Host "Please ensure Flutter is installed and in PATH" -ForegroundColor Yellow
    exit 1
}

Write-Host $emulators
Write-Host ""

# Step 2: Ask user to select emulator or auto-start
Write-Host "[2/3] Starting emulator..." -ForegroundColor Yellow

# Parse emulator list from text output
# Extract emulator ID from the output (looks like: "Medium_Phone_API_36.1")
$emulatorOutput = flutter emulators 2>&1 | Out-String
$emulatorLines = $emulatorOutput -split "`n" | Where-Object { $_ -match "\w+.*API" }

if ($emulatorLines.Count -gt 0) {
    # Extract the emulator ID (first column after the number)
    $emulatorId = $null
    
    # Try different parsing methods
    foreach ($line in $emulatorLines) {
        # Look for pattern: "Id • Name • Manufacturer • Platform"
        # or extract ID from lines with format: "Medium_Phone_API_36.1"
        if ($line -match "(\w+_\w+_API_\d+\.?\d*)") {
            $emulatorId = $matches[1]
            break
        }
        # Alternative: split by tabs/spaces and take first word that looks like an ID
        $parts = $line -split "\s+" | Where-Object { $_ -match "^\w+" -and $_ -notmatch "^Id$|^Name$|^Manufacturer$|^Platform$" }
        if ($parts.Count -gt 0 -and -not $emulatorId) {
            $emulatorId = $parts[0]
        }
    }
    
    # Fallback: try to extract from the entire output
    if (-not $emulatorId -and $emulatorOutput -match "(\w+_\w+_API_\d+\.?\d*)") {
        $emulatorId = $matches[1]
    }
    
    if ($emulatorId) {
        Write-Host "Launching emulator: $emulatorId" -ForegroundColor Green
        Start-Process -NoNewWindow flutter -ArgumentList "emulators", "--launch", $emulatorId
        
        Write-Host "Waiting for emulator to start (this may take 30-60 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Wait for emulator to be ready
        $maxWait = 60
        $waitTime = 0
        $deviceReady = $false
        
        while ($waitTime -lt $maxWait -and -not $deviceReady) {
            Start-Sleep -Seconds 2
            $waitTime += 2
            $devicesOutput = flutter devices 2>&1 | Out-String
            
            if ($devicesOutput -match "emulator-(\d+)") {
                Write-Host "✅ Emulator ready!" -ForegroundColor Green
                $deviceReady = $true
            }
            
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
        
        if (-not $deviceReady) {
            Write-Host ""
            Write-Host "⚠️  Emulator taking longer than expected. Trying to run anyway..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  Could not parse emulator ID from output." -ForegroundColor Yellow
        Write-Host "Please start emulator manually:" -ForegroundColor White
        Write-Host "  flutter emulators --launch <emulator_id>" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Or run:" -ForegroundColor White
        Write-Host "  flutter run" -ForegroundColor Gray
        exit 1
    }
} else {
    Write-Host "⚠️  No emulators found. Please create an emulator in Android Studio first." -ForegroundColor Yellow
    Write-Host "Or start emulator manually and then run: flutter run" -ForegroundColor White
    exit 1
}

# Step 3: Run Flutter app
Write-Host ""
Write-Host "[3/3] Running Flutter app..." -ForegroundColor Yellow
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

flutter run

