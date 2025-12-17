# App Store Connect API Setup Guide

This guide explains how to set up App Store Connect API credentials for command-line uploads.

---

## What is `xcrun altool`?

`xcrun altool` is a command-line tool that allows you to upload your iOS app to App Store Connect **without using the Transporter app or Xcode GUI**. This is useful for:
- Automated CI/CD pipelines
- Scripting uploads
- Uploading directly from EC2 Mac

---

## The Command Explained

```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/almed_ahu_android.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

### Parameter Breakdown

1. **`xcrun altool`**: Command-line tool for App Store operations
2. **`--upload-app`**: Action to upload an app
3. **`--type ios`**: Platform type (iOS in this case)
4. **`--file`**: Path to your IPA file
5. **`--apiKey`**: Your App Store Connect API key (replaces username/password)
6. **`--apiIssuer`**: Your API key issuer ID (identifies your API key)

---

## Step-by-Step: Getting API Credentials

### Step 1: Access App Store Connect

1. **Go to**: https://appstoreconnect.apple.com
2. **Sign in** with your Apple ID
3. **Navigate to**: Users and Access → Keys tab

### Step 2: Create API Key

1. **Click the "+" button** (top left) to create a new key

2. **Fill in Key Information**:
   - **Name**: Give it a descriptive name (e.g., "EC2 Mac Upload Key")
   - **Access**: Select "App Manager" or "Admin" (Admin recommended for full access)
   - **Click "Generate"**

3. **Download the Key**:
   - ⚠️ **IMPORTANT**: You can only download the key **once**
   - Click "Download" to save the `.p8` file
   - **Save it securely** (you can't download it again!)
   - File will be named: `AuthKey_XXXXXXXXXX.p8`

4. **Note the Information**:
   - **Key ID**: Shown on the page (e.g., `ABC123DEF4`)
   - **Issuer ID**: Shown at the top of the Keys page (e.g., `12345678-1234-1234-1234-123456789012`)

### Step 3: Use the Credentials

You now have:
- **API Key File**: `AuthKey_XXXXXXXXXX.p8` (the downloaded file)
- **Key ID**: `ABC123DEF4` (shown on the page)
- **Issuer ID**: `12345678-1234-1234-1234-123456789012` (shown at top)

---

## Using the API Key

### Option A: With Key File (Recommended)

```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/almed_ahu_android.ipa \
  --apiKey ABC123DEF4 \
  --apiIssuer 12345678-1234-1234-1234-123456789012 \
  --keychain /path/to/AuthKey_XXXXXXXXXX.p8
```

**Note**: The `--keychain` parameter is actually not used. The key file should be in a secure location, and you reference it differently. Actually, `altool` uses the key ID and issuer ID, and looks for the key file in `~/.appstoreconnect/private_keys/` or you can specify it.

### Option B: Modern Method (Using `notarytool` or `xcrun altool` with JWT)

Actually, `xcrun altool` with API keys works like this:

```bash
# Place your .p8 key file in a secure location
mkdir -p ~/.appstoreconnect/private_keys
cp ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/

# Then use:
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/almed_ahu_android.ipa \
  --apiKey ABC123DEF4 \
  --apiIssuer 12345678-1234-1234-1234-123456789012
```

The tool automatically looks for the `.p8` file based on the Key ID.

---

## Alternative: Using `notarytool` (Newer Method)

Apple is moving to `notarytool` instead of `altool`. Here's how:

### Step 1: Create App-Specific Password (Alternative Method)

Actually, for `notarytool`, you still need API keys, but the process is similar.

### Step 2: Upload with `notarytool`

```bash
xcrun notarytool submit \
  build/ios/ipa/almed_ahu_android.ipa \
  --key ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \
  --key-id ABC123DEF4 \
  --issuer 12345678-1234-1234-1234-123456789012 \
  --wait
```

---

## Security Best Practices

### 1. Store Key Securely

```bash
# Create secure directory
mkdir -p ~/.appstoreconnect/private_keys
chmod 700 ~/.appstoreconnect/private_keys

# Move key file there
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
```

### 2. Never Commit Keys to Git

Add to `.gitignore`:
```
.appstoreconnect/
*.p8
AuthKey_*.p8
```

### 3. Use Environment Variables

```bash
# Set in your shell profile (~/.zshrc)
export APP_STORE_CONNECT_API_KEY_ID="ABC123DEF4"
export APP_STORE_CONNECT_ISSUER_ID="12345678-1234-1234-1234-123456789012"
export APP_STORE_CONNECT_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"

# Then use:
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/almed_ahu_android.ipa \
  --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
```

---

## Complete Example Script

```bash
#!/bin/bash

# App Store Connect API Upload Script

# Set your credentials (or use environment variables)
API_KEY_ID="ABC123DEF4"
ISSUER_ID="12345678-1234-1234-1234-123456789012"
KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
IPA_FILE="build/ios/ipa/almed_ahu_android.ipa"

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ API key file not found: $KEY_FILE"
    echo "Download it from App Store Connect and place it in the secure location"
    exit 1
fi

# Check if IPA exists
if [ ! -f "$IPA_FILE" ]; then
    echo "❌ IPA file not found: $IPA_FILE"
    echo "Building IPA..."
    flutter build ipa --release
fi

# Upload
echo "📤 Uploading to App Store Connect..."
xcrun altool --upload-app \
  --type ios \
  --file "$IPA_FILE" \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$ISSUER_ID"

if [ $? -eq 0 ]; then
    echo "✅ Upload successful!"
    echo "Check App Store Connect for processing status"
else
    echo "❌ Upload failed. Check errors above."
    exit 1
fi
```

---

## Troubleshooting

### Error: "Invalid API Key"

**Solution**:
- Verify Key ID is correct (no spaces, exact match)
- Verify Issuer ID is correct (full UUID format)
- Ensure `.p8` file is in correct location
- Check key hasn't been revoked in App Store Connect

### Error: "Key file not found"

**Solution**:
- Verify path to `.p8` file is correct
- Check file permissions (should be readable)
- Ensure file wasn't moved or deleted

### Error: "Insufficient permissions"

**Solution**:
- Check API key has "App Manager" or "Admin" access
- Verify you're using the correct Apple ID
- Ensure key hasn't expired

### Error: "altool: command not found"

**Solution**:
- Install Xcode Command Line Tools: `xcode-select --install`
- Update Xcode to latest version
- Use full path: `/Applications/Xcode.app/Contents/Developer/usr/bin/altool`

---

## Comparison: Methods

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Transporter App** | Easy, GUI, no setup | Requires local Mac | Manual uploads |
| **Xcode Organizer** | Integrated, visual | Requires Xcode GUI | Xcode users |
| **altool (API)** | Automated, scriptable | Requires API setup | CI/CD, automation |
| **notarytool** | Modern, recommended | Newer, less docs | Future-proof |

---

## Quick Reference

### Get Your Credentials

1. **App Store Connect** → Users and Access → Keys
2. **Create Key** → Download `.p8` file
3. **Note**: Key ID and Issuer ID

### Upload Command

```bash
xcrun altool --upload-app \
  --type ios \
  --file YOUR_IPA.ipa \
  --apiKey YOUR_KEY_ID \
  --apiIssuer YOUR_ISSUER_ID
```

### File Locations

- **Key File**: `~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8`
- **IPA File**: `build/ios/ipa/almed_ahu_android.ipa`

---

## Summary

- **API Key**: Identifies your App Store Connect API key (like a username)
- **Issuer ID**: Identifies your Apple Developer account (like a domain)
- **Key File (.p8)**: The actual private key file (like a password file)
- **Purpose**: Upload apps to App Store Connect from command line

**Note**: For most users, **Transporter app is easier**. Use API method only if you need automation or scripting.


