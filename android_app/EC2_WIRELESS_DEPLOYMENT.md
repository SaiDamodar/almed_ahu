# Wireless iOS Deployment from EC2 Mac

Since you're using an EC2 Mac instance, USB connection won't work. Here are the options for deploying to your iPhone wirelessly.

---

## Option 1: Wireless Debugging (Recommended)

### Prerequisites
- iPhone and Mac on the same network (or iPhone connected to Mac's hotspot)
- Xcode 15+ (you have 15.4 ✅)
- iOS 17+ on iPhone (for wireless debugging)

### Setup Steps

1. **First-time USB connection** (do this once from a local Mac):
   - Connect iPhone to a local Mac via USB
   - In Xcode: Window → Devices and Simulators
   - Select iPhone → Check "Connect via network"
   - iPhone will now appear wirelessly

2. **From EC2 Mac** (after initial setup):
   ```bash
   # Your iPhone should appear wirelessly
   flutter devices
   
   # Deploy wirelessly
   flutter run --release
   ```

**Note**: If you don't have access to a local Mac for initial setup, use Option 2 or 3.

---

## Option 2: Build IPA and Install via TestFlight/Ad Hoc

### Step 1: Build IPA File

```bash
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app

# Build for release
flutter build ipa --release

# The IPA will be at:
# build/ios/ipa/almed_ahu_android.ipa
```

### Step 2: Upload to TestFlight (Recommended)

1. **Install Transporter App** (from Mac App Store) or use Xcode
2. **Upload IPA**:
   ```bash
   # Using Xcode (if you have GUI access)
   open -a Xcode
   # Xcode → Window → Organizer → Archives → Distribute App
   
   # Or use command line (if you have App Store Connect API key)
   xcrun altool --upload-app --type ios --file build/ios/ipa/almed_ahu_android.ipa --apiKey YOUR_API_KEY --apiIssuer YOUR_ISSUER_ID
   ```

3. **In App Store Connect**:
   - Go to https://appstoreconnect.apple.com
   - My Apps → Select/Create App → TestFlight
   - Upload the IPA
   - Add internal/external testers
   - Install TestFlight app on iPhone
   - Install your app from TestFlight

### Step 3: Ad Hoc Distribution (For Specific Devices)

1. **Register devices** in Apple Developer Portal:
   - https://developer.apple.com/account
   - Certificates, Identifiers & Profiles → Devices
   - Add your iPhone's UDID

2. **Create Ad Hoc Provisioning Profile**:
   - Profiles → "+" → Ad Hoc
   - Select your App ID: `com.almed.ahu`
   - Select your devices
   - Download profile

3. **Build with Ad Hoc profile**:
   ```bash
   # In Xcode: Signing & Capabilities → Select Ad Hoc profile
   flutter build ipa --release
   ```

4. **Distribute IPA**:
   - Upload to a file sharing service (Dropbox, Google Drive, etc.)
   - Download on iPhone
   - Install via Safari (requires enterprise cert or TestFlight)

---

## Option 3: Build and Download IPA Locally

### Step 1: Build IPA on EC2

```bash
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app
flutter build ipa --release
```

### Step 2: Download IPA to Your Local Machine

```bash
# From your local machine, download the IPA
scp -i /path/to/your-key.pem \
  ec2-user@your-ec2-ip:/Users/ec2-user/Desktop/Almed/almed_ahu/android_app/build/ios/ipa/almed_ahu_android.ipa \
  ~/Downloads/
```

### Step 3: Install on iPhone

**Option A: Using Xcode on Local Mac**
1. Connect iPhone to local Mac via USB
2. Open Xcode → Window → Devices and Simulators
3. Select iPhone → Click "+" under "Installed Apps"
4. Select the IPA file
5. App installs on iPhone

**Option B: Using Apple Configurator 2**
1. Install Apple Configurator 2 (free from Mac App Store)
2. Connect iPhone via USB
3. Drag IPA file to iPhone in Configurator
4. App installs

**Option C: Using 3uTools or Similar**
- Use third-party tools to install IPA via USB

---

## Option 4: Use Remote Desktop/VNC (If Available)

If you have VNC/Remote Desktop access to EC2 Mac:

1. **Connect to EC2 Mac GUI**:
   ```bash
   # Enable VNC (if not already)
   # Then connect with VNC client
   ```

2. **Use Xcode GUI**:
   - Open Xcode
   - Connect iPhone wirelessly (if already paired)
   - Deploy directly from Xcode

---

## Quick Reference Commands

### Build IPA
```bash
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app
flutter build ipa --release
```

### Check IPA Location
```bash
ls -lh build/ios/ipa/
```

### Download IPA to Local Machine
```bash
# From your local machine
scp -i /path/to/key.pem \
  ec2-user@EC2_IP:/Users/ec2-user/Desktop/Almed/almed_ahu/android_app/build/ios/ipa/*.ipa \
  ~/Downloads/
```

### Upload to TestFlight (if you have API credentials)
```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/almed_ahu_android.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

---

## Recommended Workflow for EC2

**Best Approach**: Build IPA → Download to Local Mac → Install via USB

1. **On EC2**:
   ```bash
   flutter build ipa --release
   ```

2. **Download IPA** to your local machine via SCP

3. **On Local Mac**:
   - Connect iPhone via USB
   - Install IPA using Xcode or Apple Configurator 2

---

## Troubleshooting

### Issue: "No devices found" wirelessly
- Ensure iPhone and EC2 Mac are on same network
- iPhone must be paired via USB first (from local Mac)
- Check: Settings → General → VPN & Device Management

### Issue: Can't download IPA
- Check file permissions: `chmod 644 build/ios/ipa/*.ipa`
- Verify SCP connection works
- Check firewall rules on EC2

### Issue: IPA won't install
- Ensure device is registered in Apple Developer Portal
- Use correct provisioning profile (Development or Ad Hoc)
- Check bundle ID matches: `com.almed.ahu`

---

## Summary

✅ **USB won't work** from EC2 (you're remote)
✅ **Best option**: Build IPA → Download → Install locally via USB
✅ **Alternative**: TestFlight for easy distribution
✅ **Wireless**: Only works if iPhone was previously paired via USB


