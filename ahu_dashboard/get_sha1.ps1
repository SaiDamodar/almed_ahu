# PowerShell script to get SHA-1 fingerprint for Android
# Run this to get your SHA-1 for Firebase Console setup

Write-Host "`n🔑 Getting SHA-1 Fingerprint for Firebase Setup" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

# Change to android directory
Push-Location -Path "$PSScriptRoot\android"

Write-Host "Running Gradle signing report..." -ForegroundColor Yellow
.\gradlew signingReport | Out-String | Select-String -Pattern "SHA1" -Context 2,0

Write-Host "`n📋 Look for 'SHA1:' in the output above" -ForegroundColor Green
Write-Host "Copy the SHA1 value (looks like: A1:B2:C3:D4:...) and add it to Firebase Console" -ForegroundColor Yellow
Write-Host ""
Write-Host "📍 Firebase Console Location:" -ForegroundColor Cyan
Write-Host "   Project Settings → Your Android App → Add fingerprint" -ForegroundColor White
Write-Host ""

# Alternative method
Write-Host "Alternative: Using keytool directly..." -ForegroundColor Yellow
$keytoolPath = "keytool"
$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $keystorePath) {
    Write-Host "`nSHA-1 from debug keystore:" -ForegroundColor Green
    & $keytoolPath -list -v -keystore $keystorePath -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String -Pattern "SHA1"
} else {
    Write-Host "Debug keystore not found at: $keystorePath" -ForegroundColor Yellow
}

Pop-Location

Write-Host "`n✅ Done! Copy the SHA1 value above and add it to Firebase Console" -ForegroundColor Green
Write-Host ""

