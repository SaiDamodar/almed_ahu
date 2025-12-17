# Post-Upgrade Steps (After macOS 15.7.3 Upgrade)

After your EC2 Mac restarts with macOS 15.7.3, follow these steps:

## Step 1: Install Xcode 16+

**Since App Store isn't available, download directly from Apple Developer:**

### Option A: Download via Browser (Recommended)

1. **Open browser on EC2 Mac**:
   ```bash
   open https://developer.apple.com/download/all/
   ```

2. **Sign in with your Apple ID** (free account works)

3. **Search for "Xcode 16"** and download the `.xip` file (~12-15GB)

4. **Extract and install**:
   ```bash
   cd ~/Downloads
   xip -x Xcode_16.x.xip
   sudo mv Xcode.app /Applications/
   sudo chown -R $(whoami):admin /Applications/Xcode.app
   ```

### Option B: Download on Local Machine and Transfer

If browser access is limited:

1. **Download Xcode.xip on your local machine** from developer.apple.com

2. **Transfer to EC2**:
   ```bash
   # From your local machine:
   scp -i /path/to/key.pem Xcode_16.x.xip ec2-user@YOUR_EC2_IP:~/Downloads/
   ```

3. **On EC2, extract and install** (as shown in Option A)

**See `XCODE_DIRECT_DOWNLOAD.md` for detailed instructions.**

## Step 2: Configure Xcode

```bash
# Set Xcode as active developer directory
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Accept license
sudo xcodebuild -license accept

# Run first launch
sudo xcodebuild -runFirstLaunch

# Verify
xcodebuild -version
# Should show Xcode 16.x
```

## Step 3: Update Flutter (If Needed)

```bash
cd ~/flutter
git pull
flutter upgrade
flutter doctor
```

## Step 4: Rebuild IPA

```bash
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app

# Clean and rebuild
flutter clean
flutter pub get
flutter build ipa --release
```

## Step 5: Upload to TestFlight

```bash
./upload_to_testflight.sh
```

## Step 6: Verify Upload

1. Go to: https://appstoreconnect.apple.com
2. My Apps → Your App → TestFlight
3. Wait 10-30 minutes for processing
4. Add to test groups

## Troubleshooting

### If Xcode 16 won't install:
- Check macOS version: `sw_vers` (should be 15.7.3)
- Try downloading from: https://developer.apple.com/xcode/

### If build fails:
- Run `flutter doctor` to check setup
- Verify Xcode version: `xcodebuild -version`
- Check iOS deployment target in Podfile

### If upload still fails:
- Verify Xcode 16 is installed
- Check build logs for SDK version
- Ensure IPA was built with Xcode 16

