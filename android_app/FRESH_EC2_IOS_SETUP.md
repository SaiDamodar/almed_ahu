# Fresh EC2 Mac iOS Setup - Complete Guide

This guide is for setting up iOS development on a **brand new EC2 Mac instance** from scratch.

## Prerequisites

- New EC2 Mac instance (macOS 14.0+ recommended)
- SSH access to the instance
- Apple ID (free account works for testing)
- Firebase project access (alemdahu-0107)

---

## Phase 1: Initial EC2 Mac Setup

### Step 1: Connect to EC2 Mac

```bash
# SSH into your EC2 Mac instance
ssh -i /path/to/your-key.pem ec2-user@your-ec2-ip
# Or if using username 'admin' or 'macos'
ssh -i /path/to/your-key.pem admin@your-ec2-ip
```

### Step 2: Update System

```bash
# Update macOS (if needed)
sudo softwareupdate -i -a

# Install Xcode Command Line Tools
xcode-select --install

# Accept Xcode license
sudo xcodebuild -license accept
```

### Step 3: Install Xcode

```bash
# Open App Store
open -a "App Store"

# Search for "Xcode" and install
# OR download from: https://developer.apple.com/xcode/

# After installation, verify
xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

### Step 4: Install Homebrew (Optional but Recommended)

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (follow instructions from install output)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Step 5: Install Flutter

```bash
# Download Flutter SDK
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# Add Flutter to PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
flutter --version
flutter doctor
```

### Step 6: Install CocoaPods

```bash
# Install CocoaPods
sudo gem install cocoapods

# Setup CocoaPods
pod setup

# Verify installation
pod --version
```

### Step 7: Configure Git (If Needed)

```bash
# Set up Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Generate SSH key for GitHub (optional)
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub
# Add this to GitHub: Settings → SSH and GPG keys
```

---

## Phase 2: Clone and Setup Project

### Step 1: Clone Repository

```bash
# Navigate to desired directory
cd ~
# OR
cd ~/Documents

# Clone repository
git clone https://github.com/your-username/almed_ahu.git
# OR if using SSH
git clone git@github.com:your-username/almed_ahu.git

# Navigate to project
cd almed_ahu/android_app
```

### Step 2: Fix Permissions

```bash
# Get current user
CURRENT_USER=$(whoami)

# Fix project ownership
sudo chown -R $CURRENT_USER:staff ~/almed_ahu
chmod -R 755 ~/almed_ahu

# Fix Flutter SDK permissions
sudo chown -R $CURRENT_USER:staff ~/flutter
chmod -R 755 ~/flutter

# Fix temporary directories
sudo chmod -R 755 /tmp
sudo chown -R $CURRENT_USER /tmp

# Create Xcode directories
mkdir -p ~/Library/Developer/Xcode/DerivedData
chmod -R 755 ~/Library/Developer/Xcode/DerivedData
```

### Step 3: Get Flutter Dependencies

```bash
cd ~/almed_ahu/android_app

# Clean and get dependencies
flutter clean
flutter pub get

# Verify Flutter setup
flutter doctor
```

---

## Phase 3: Firebase Configuration

### Step 1: Add iOS App to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **alemdahu-0107**
3. Click **Settings gear** → **Project settings**
4. Scroll to **Your apps** section
5. Click **Add app** → Select **iOS**
6. Enter details:
   - **iOS bundle ID**: `com.almed.ahu`
   - **App nickname**: ALMED AHU iOS (optional)
   - **App Store ID**: Leave blank
7. Click **Register app**
8. **Download** `GoogleService-Info.plist`

### Step 2: Replace GoogleService-Info.plist

```bash
# Copy downloaded file to project
# If downloaded to local machine, transfer to EC2:
# scp -i /path/to/key.pem ~/Downloads/GoogleService-Info.plist ec2-user@ec2-ip:~/almed_ahu/android_app/ios/Runner/

# On EC2 Mac, verify file is in place (after iOS folder is generated)
ls -la ~/almed_ahu/android_app/ios/Runner/GoogleService-Info.plist

# Verify it's not a placeholder
grep -i "YOUR_CLIENT_ID\|your-project-id" ~/almed_ahu/android_app/ios/Runner/GoogleService-Info.plist
# Should return nothing if file is correct
```

### Step 3: Update Info.plist with REVERSED_CLIENT_ID

**Note**: Do this AFTER generating the iOS folder and copying GoogleService-Info.plist

```bash
cd ~/almed_ahu/android_app

# Extract REVERSED_CLIENT_ID from GoogleService-Info.plist
REVERSED_CLIENT_ID=$(grep -A 1 "REVERSED_CLIENT_ID" ios/Runner/GoogleService-Info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

echo "REVERSED_CLIENT_ID: $REVERSED_CLIENT_ID"

# Update Info.plist (replace placeholder)
sed -i '' "s/com.googleusercontent.apps.YOUR_CLIENT_ID/$REVERSED_CLIENT_ID/g" ios/Runner/Info.plist

# Verify update
grep "$REVERSED_CLIENT_ID" ios/Runner/Info.plist
```

---

## Phase 4: iOS Project Configuration

### Step 1: Generate iOS Folder

Flutter will create a fresh iOS folder with default configuration:

```bash
cd ~/almed_ahu/android_app

# Remove existing ios folder if it exists
rm -rf ios

# Generate fresh iOS project
flutter create --platforms=ios .

# Verify ios folder was created
ls -la ios/
```

### Step 2: Apply Customizations

Copy the custom files from `ios_customizations/` folder:

```bash
# Copy custom Podfile (with Swift 5.9 and Firebase settings)
cp ios_customizations/Podfile ios/Podfile

# Copy custom AppDelegate.swift (with Firebase imports)
cp ios_customizations/AppDelegate.swift ios/Runner/AppDelegate.swift

# Update Info.plist with Firebase and Google Sign-In settings
# First, get REVERSED_CLIENT_ID from GoogleService-Info.plist (after Firebase setup)
# Then manually add the additions from Info.plist.additions
```

### Step 3: Install iOS Pods

```bash
cd ~/almed_ahu/android_app/ios

# Install pods (fresh install, no cleanup needed)
pod install --repo-update

# Verify installation
ls -la Pods/

# Go back to project root
cd ..
```

### Step 3: Clean Xcode Derived Data

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

---

## Phase 5: Build and Test

### Step 1: Open in Xcode

```bash
cd ~/almed_ahu/android_app

# IMPORTANT: Open .xcworkspace, NOT .xcodeproj
open ios/Runner.xcworkspace
```

### Step 2: Configure Signing in Xcode

1. In Xcode, select **Runner** project (blue icon)
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Check **"Automatically manage signing"**
5. Select your **Team** (your Apple ID)
   - If not listed: **Xcode → Settings → Accounts** → Add Apple ID
6. Verify **Bundle Identifier** is: `com.almed.ahu`

### Step 3: Build for Simulator

**Option A: From Terminal**
```bash
cd ~/almed_ahu/android_app
flutter build ios --simulator
```

**Option B: From Xcode**
1. Select iOS Simulator from device dropdown (top toolbar)
2. **Product → Clean Build Folder** (`Shift + Cmd + K`)
3. **Product → Build** (`Cmd + B`)

### Step 4: Run on Simulator

```bash
# List available simulators
flutter devices

# Run on simulator
flutter run

# Or specify simulator
flutter run -d <simulator-id>
```

---

## Verification Checklist

Before considering setup complete, verify:

- [ ] Xcode installed and working (`xcodebuild -version`)
- [ ] Flutter installed (`flutter --version`)
- [ ] CocoaPods installed (`pod --version`)
- [ ] Project cloned successfully
- [ ] Permissions fixed
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] GoogleService-Info.plist replaced with real file
- [ ] Info.plist updated with REVERSED_CLIENT_ID
- [ ] iOS pods installed (`pod install`)
- [ ] Xcode opens without errors
- [ ] Build succeeds (`flutter build ios --simulator`)

---

## Troubleshooting

### Issue: Xcode Not Found
```bash
# Set Xcode path
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Issue: Flutter Not Found
```bash
# Add to PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Issue: CocoaPods Broken
```bash
# Reinstall
sudo gem uninstall cocoapods
sudo gem install cocoapods
pod setup
```

### Issue: Permission Errors
```bash
# Fix all permissions
CURRENT_USER=$(whoami)
sudo chown -R $CURRENT_USER:staff ~/almed_ahu
chmod -R 755 ~/almed_ahu
```

### Issue: "No such module 'Flutter'"
- Always open `Runner.xcworkspace`, NOT `Runner.xcodeproj`
- Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`

### Issue: "No such module 'Firebase'"
```bash
cd ios
pod install
cd ..
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

---

## Quick Setup Script

Save this as `setup_fresh_ec2.sh`:

```bash
#!/bin/bash
set -e

echo "Setting up fresh EC2 Mac for iOS development..."

# Install Xcode Command Line Tools
xcode-select --install || true
sudo xcodebuild -license accept

# Install CocoaPods
sudo gem install cocoapods
pod setup

# Install Flutter
cd ~
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# Fix permissions
CURRENT_USER=$(whoami)
sudo chmod -R 755 /tmp
sudo chown -R $CURRENT_USER /tmp

echo "Setup complete! Next steps:"
echo "1. Install Xcode from App Store"
echo "2. Clone repository"
echo "3. Configure Firebase"
echo "4. Install pods and build"
```

---

## Next Steps After Setup

1. **Test the app** on iOS Simulator
2. **Register device** (if testing on physical iPhone)
3. **Configure push notifications** (if needed)
4. **Build for release** (when ready)

---

## Summary

This is a complete fresh setup guide. Follow phases in order:
1. **Phase 1**: Install all tools (Xcode, Flutter, CocoaPods)
2. **Phase 2**: Clone project and fix permissions
3. **Phase 3**: Configure Firebase
4. **Phase 4**: Configure iOS project
5. **Phase 5**: Build and test

**Expected time**: 30-60 minutes (mostly waiting for Xcode download/install)

---

**Last Updated**: For fresh EC2 Mac instances
**Project**: ALMED AHU iOS App
**Bundle ID**: com.almed.ahu

