# iOS Device Deployment Guide

Complete guide for deploying your Flutter app to a physical iPhone using your Apple Developer account.

## Prerequisites

- ✅ Apple Developer Account (Free or Paid)
- ✅ Physical iPhone connected via USB
- ✅ Xcode installed and configured
- ✅ App configured with Bundle ID: `com.almed.ahu`

---

## Step 1: Register Your iPhone in Apple Developer Portal

### Option A: Automatic Registration (Recommended)

1. **Connect iPhone to Mac via USB**
2. **Open Xcode**
3. **Window → Devices and Simulators** (or `Shift + Cmd + 2`)
4. **Select your iPhone** from the left sidebar
5. **Click "Use for Development"**
   - Xcode will automatically register the device
   - You may need to trust the computer on your iPhone

### Option B: Manual Registration

1. **Go to Apple Developer Portal**: https://developer.apple.com/account
2. **Sign in** with your Apple ID
3. **Navigate to**: Certificates, Identifiers & Profiles
4. **Click "Devices"** in the left sidebar
5. **Click the "+" button** to add a new device
6. **Enter Device Information**:
   - **Name**: Your iPhone name (e.g., "John's iPhone")
   - **UDID**: Get from Xcode (Window → Devices and Simulators) or Settings → General → About → UDID
   - **Device Type**: iPhone
7. **Click "Continue"** and **"Register"**

---

## Step 2: Configure Xcode Signing

### In Xcode:

1. **Open the workspace**:
   ```bash
   cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app
   open ios/Runner.xcworkspace
   ```

2. **Select the Runner project** (blue icon) in the left sidebar

3. **Select the Runner target** (under TARGETS)

4. **Go to "Signing & Capabilities" tab**

5. **Configure Signing**:
   - ✅ Check **"Automatically manage signing"**
   - **Team**: Select your Apple Developer Team
     - If not listed: **Xcode → Settings → Accounts** → Add Apple ID
   - **Bundle Identifier**: `com.almed.ahu`
   - **Provisioning Profile**: Should auto-generate

6. **Verify**:
   - Xcode should show: "Provisioning profile created"
   - No red errors in signing section

---

## Step 3: Trust Your Computer on iPhone

1. **Connect iPhone via USB**
2. **On iPhone**: Settings → General → VPN & Device Management
3. **Tap your Mac/Developer name**
4. **Tap "Trust [Your Mac Name]"**
5. **Enter passcode** if prompted

---

## Step 4: Build and Deploy to Device

### Option A: Using Flutter CLI

```bash
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app

# List connected devices
flutter devices

# Build and deploy to connected iPhone
flutter run --release

# Or specify device explicitly
flutter run -d <device-id> --release
```

### Option B: Using Xcode

1. **In Xcode**, select your **iPhone** from the device dropdown (top toolbar)
   - Should show: "iPhone (Connected)"

2. **Product → Clean Build Folder** (`Shift + Cmd + K`)

3. **Product → Run** (`Cmd + R`) or click the Play button

4. **First time only**:
   - On iPhone: Settings → General → VPN & Device Management
   - Tap your developer certificate
   - Tap "Trust [Your Name]"

---

## Step 5: Create Distribution Certificate (For App Store/TestFlight)

### If you need to distribute the app:

1. **Go to Apple Developer Portal**: https://developer.apple.com/account
2. **Certificates, Identifiers & Profiles**
3. **Certificates → "+" button**
4. **Select Certificate Type**:
   - **Development**: For testing on your devices
   - **Distribution**: For App Store or TestFlight
5. **Follow the wizard** to create certificate
6. **Download and install** the certificate
7. **In Xcode**: The certificate will appear automatically

---

## Step 6: Create Provisioning Profile (If Automatic Signing Fails)

### Usually not needed if "Automatically manage signing" is enabled, but if you have issues:

1. **Apple Developer Portal** → Certificates, Identifiers & Profiles
2. **Profiles → "+" button**
3. **Select Profile Type**:
   - **iOS App Development**: For development
   - **App Store**: For distribution
   - **Ad Hoc**: For specific devices
4. **Select App ID**: `com.almed.ahu`
5. **Select Certificate**: Your development/distribution certificate
6. **Select Devices**: Your registered iPhone(s)
7. **Name the profile** and **Generate**
8. **Download** and **double-click** to install in Xcode

---

## Troubleshooting

### Issue: "No devices found"

**Solution**:
```bash
# Check if device is connected
flutter devices

# If not showing, try:
# 1. Unplug and replug USB cable
# 2. Trust computer on iPhone
# 3. Restart Xcode
```

### Issue: "Signing for Runner requires a development team"

**Solution**:
1. Xcode → Settings → Accounts
2. Add your Apple ID
3. Select team in Signing & Capabilities

### Issue: "Provisioning profile doesn't match"

**Solution**:
1. In Xcode: Signing & Capabilities
2. Uncheck "Automatically manage signing"
3. Check it again
4. Select your team
5. Xcode will regenerate the profile

### Issue: "Device not registered"

**Solution**:
1. Register device in Apple Developer Portal (see Step 1)
2. Wait a few minutes for sync
3. Refresh in Xcode (Product → Clean Build Folder)

### Issue: "Untrusted Developer"

**Solution**:
1. On iPhone: Settings → General → VPN & Device Management
2. Tap your developer certificate
3. Tap "Trust [Your Name]"

---

## Quick Command Reference

```bash
# List connected devices
flutter devices

# Build for device (release mode)
flutter build ios --release

# Run on connected device
flutter run --release

# Build and get device ID
flutter devices | grep iPhone

# Deploy to specific device
flutter run -d <device-id> --release
```

---

## Bundle ID Configuration

Your app is configured with:
- **Bundle ID**: `com.almed.ahu`
- **Display Name**: "Almed Ahu Android"
- **Firebase Project**: alemdahu-0107

Make sure this matches in:
- ✅ Xcode → Signing & Capabilities
- ✅ Firebase Console
- ✅ Apple Developer Portal → App ID

---

## Next Steps After Deployment

1. **Test the app** on your iPhone
2. **For App Store**: Create App Store Connect listing
3. **For TestFlight**: Upload build via Xcode or Transporter
4. **For Ad Hoc**: Distribute to specific registered devices

---

## Important Notes

- ⚠️ **Free Apple Developer Account**: Limited to 3 registered devices
- ⚠️ **Paid Account ($99/year)**: Unlimited devices, App Store distribution
- ⚠️ **Certificates expire**: Renew annually
- ⚠️ **Provisioning Profiles**: Auto-managed by Xcode (recommended)

---

## Verification Checklist

Before deploying, verify:
- [ ] iPhone connected and trusted
- [ ] Device registered in Apple Developer Portal
- [ ] Apple ID added in Xcode → Settings → Accounts
- [ ] Team selected in Signing & Capabilities
- [ ] "Automatically manage signing" enabled
- [ ] Bundle ID matches: `com.almed.ahu`
- [ ] No signing errors in Xcode
- [ ] Device appears in `flutter devices`

---

## Support

If you encounter issues:
1. Check Xcode build logs
2. Verify device registration in Apple Developer Portal
3. Ensure certificates are valid
4. Try cleaning build folder and rebuilding


