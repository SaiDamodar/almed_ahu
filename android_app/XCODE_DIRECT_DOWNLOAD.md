# Download Xcode 16+ Directly (Without App Store)

Since the App Store isn't available on your EC2 Mac, download Xcode directly from Apple Developer.

## Step 1: Download Xcode from Apple Developer

### Option A: Using Browser (Recommended)

1. **Open Safari or any browser on EC2 Mac**:
   ```bash
   open https://developer.apple.com/download/all/
   ```

2. **Sign in with your Apple ID** (free Apple Developer account works)

3. **Search for "Xcode 16"** or look for the latest Xcode version

4. **Download the `.xip` file** (it's large, ~12-15GB)

### Option B: Using Command Line (If you have Apple ID credentials)

```bash
# Install aria2 for faster downloads (optional)
brew install aria2

# You'll need to:
# 1. Get the download URL from developer.apple.com
# 2. Sign in and get the download link
# 3. Download using curl or aria2
```

## Step 2: Extract and Install Xcode

After downloading the `.xip` file:

```bash
# Navigate to Downloads (or wherever you saved it)
cd ~/Downloads

# Extract the .xip file (this takes 10-20 minutes)
xip -x Xcode_16.x.xip

# Move Xcode to Applications
sudo mv Xcode.app /Applications/

# Set permissions
sudo chown -R $(whoami):admin /Applications/Xcode.app
```

## Step 3: Configure Xcode

```bash
# Set Xcode as active developer directory
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Accept license
sudo xcodebuild -license accept

# Run first launch (installs additional components)
sudo xcodebuild -runFirstLaunch

# Verify installation
xcodebuild -version
# Should show: Xcode 16.x.x
```

## Step 4: Install Additional Components

```bash
# Install iOS simulators and additional tools
xcodebuild -downloadPlatform iOS
```

## Alternative: Download Specific Xcode Version

If you need a specific version:

1. Go to: https://developer.apple.com/download/all/
2. Filter by "Xcode"
3. Look for version 16.0 or later
4. Download the `.xip` file

## Troubleshooting

### If download is slow:
- Use `aria2` for multi-connection downloads:
  ```bash
  brew install aria2
  aria2c -x 16 -s 16 "DOWNLOAD_URL"
  ```

### If extraction fails:
- Make sure you have enough disk space (Xcode needs ~30GB)
- Check disk space: `df -h`
- Free up space if needed

### If xcode-select fails:
- Make sure Xcode.app is in /Applications/
- Check permissions: `ls -la /Applications/Xcode.app`

### If you don't have browser access:
You can download on your local machine and transfer via SCP:

```bash
# On your local machine, download Xcode.xip
# Then transfer to EC2:
scp -i /path/to/key.pem Xcode_16.x.xip ec2-user@YOUR_EC2_IP:~/Downloads/

# Then on EC2, extract and install as above
```

## Quick Reference

```bash
# Full installation sequence:
cd ~/Downloads
xip -x Xcode_16.x.xip
sudo mv Xcode.app /Applications/
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -version
```

## Next Steps

After Xcode 16+ is installed:

1. Rebuild your Flutter app:
   ```bash
   cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app
   flutter clean
   flutter pub get
   flutter build ipa --release
   ```

2. Upload to TestFlight:
   ```bash
   ./upload_to_testflight.sh
   ```

