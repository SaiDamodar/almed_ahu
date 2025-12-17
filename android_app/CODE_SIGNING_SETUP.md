# Code Signing Setup for TestFlight

## Current Status

- ✅ Xcode 16.4 installed
- ✅ Development Team ID: `7DY5UDNBXH` (configured in project)
- ✅ Development certificate found: "Apple Development: Zaid Shaikh (NT37FZM26K)"
- ❌ App Store Distribution certificate needed for TestFlight
- ❌ Xcode not authenticated with Apple Developer account

## The Problem

`flutter build ipa` requires:
1. Xcode authenticated with your Apple Developer account
2. App Store Distribution certificate (not just Development)
3. Automatic signing enabled and working

## Solution Options

### Option 1: Configure via Xcode GUI (Recommended if you have GUI access)

If you have VNC/Remote Desktop access to EC2:

1. **Open Xcode**:
   ```bash
   open -a Xcode
   ```

2. **Sign in to Apple Developer Account**:
   - Xcode → Settings (or Preferences) → Accounts
   - Click "+" → Add Apple ID
   - Enter your Apple ID and password
   - Select your team: `7DY5UDNBXH`

3. **Configure Project Signing**:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Select "Runner" project (blue icon)
   - Select "Runner" target
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select Team: Your team (should show `7DY5UDNBXH`)
   - Bundle Identifier: `com.almed.ahu`

4. **Xcode will automatically**:
   - Create/select App Store Distribution certificate
   - Create provisioning profile
   - Configure signing

5. **Then build**:
   ```bash
   flutter build ipa --release
   ```

### Option 2: Use Command Line (If you have API access)

If you have App Store Connect API key, you can try:

```bash
# This requires proper certificate setup first
# Usually easier to use Xcode GUI
```

### Option 3: Download IPA from Previous Build (If Available)

If you have a previously built IPA that was signed correctly:

```bash
# Check if old IPA exists
ls -la build/ios/ipa/
```

### Option 4: Build on Local Mac (If Available)

If you have a local Mac with Xcode configured:

1. **On EC2**: Build without signing (won't work for TestFlight directly)
2. **On Local Mac**: Configure signing and rebuild
3. **Upload from Local Mac**

## Quick Check Commands

```bash
# Check installed certificates
security find-identity -v -p codesigning

# Check Xcode accounts (if configured)
# This requires Xcode to be authenticated first

# Check project signing settings
cd ios
xcodebuild -showBuildSettings -workspace Runner.xcworkspace -scheme Runner | grep CODE_SIGN
```

## Next Steps

1. **If you have GUI access**: Follow Option 1
2. **If no GUI access**: You'll need to either:
   - Set up VNC/Remote Desktop to access Xcode GUI
   - Or configure signing on a local Mac and transfer the project
   - Or use a CI/CD service that handles signing automatically

## Troubleshooting

### "No signing certificate found"
- Sign in to Xcode with your Apple ID
- Xcode → Settings → Accounts → Add Apple ID

### "Provisioning profile not found"
- Enable "Automatically manage signing" in Xcode
- Xcode will create the profile automatically

### "Team not found"
- Make sure you're signed in to Xcode with the correct Apple ID
- The Apple ID must be part of team `7DY5UDNBXH`

