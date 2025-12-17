#!/bin/bash

# TestFlight Upload Script with API Key
# Make sure AuthKey_F3WU9KJ42M.p8 is in ~/.appstoreconnect/private_keys/

API_KEY="F3WU9KJ42M"
ISSUER_ID="fa7723dc-ff07-4e9f-9d82-611192079b93"
KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_F3WU9KJ42M.p8"
IPA_FILE="build/ios/ipa/almed_ahu_android.ipa"

echo "🚀 TestFlight Upload Script"
echo "============================"
echo ""

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Key file not found: $KEY_FILE"
    echo ""
    echo "📥 Upload the key file from your local machine:"
    echo "   scp -i /path/to/key.pem \\"
    echo "     ~/Downloads/AuthKey_F3WU9KJ42M.p8 \\"
    echo "     ec2-user@YOUR_EC2_IP:~/.appstoreconnect/private_keys/"
    echo ""
    exit 1
fi

# Set correct permissions
chmod 600 "$KEY_FILE"
echo "✅ Key file found and permissions set"

# Check if IPA exists
if [ ! -f "$IPA_FILE" ]; then
    echo "❌ IPA not found. Building..."
    flutter build ipa --release
    if [ $? -ne 0 ]; then
        echo "❌ Build failed!"
        exit 1
    fi
fi

echo "✅ IPA found: $IPA_FILE"
echo ""

# Upload
echo "📤 Uploading to App Store Connect..."
echo "   API Key: $API_KEY"
echo "   Issuer ID: $ISSUER_ID"
echo ""

xcrun altool --upload-app \
  --type ios \
  --file "$IPA_FILE" \
  --apiKey "$API_KEY" \
  --apiIssuer "$ISSUER_ID"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Upload successful!"
    echo "📱 Check App Store Connect → TestFlight for processing status"
else
    echo ""
    echo "❌ Upload failed. Check errors above."
    exit 1
fi
