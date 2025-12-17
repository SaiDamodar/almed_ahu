#!/bin/bash

# TestFlight Upload Helper Script
# This script helps you prepare and upload your app to TestFlight

echo "🚀 TestFlight Upload Helper"
echo "============================"
echo ""

# Check if IPA exists
IPA_PATH="build/ios/ipa/almed_ahu_android.ipa"
if [ ! -f "$IPA_PATH" ]; then
    echo "❌ IPA not found. Building..."
    flutter build ipa --release
    if [ $? -ne 0 ]; then
        echo "❌ Build failed!"
        exit 1
    fi
fi

IPA_SIZE=$(ls -lh "$IPA_PATH" | awk '{print $5}')
echo "✅ IPA found: $IPA_PATH"
echo "📊 Size: $IPA_SIZE"
echo ""

# Get EC2 IP
EC2_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_IP")

echo "📥 To upload to TestFlight:"
echo ""
echo "1️⃣  Download IPA to your local Mac:"
echo "   scp -i /path/to/your-key.pem \\"
echo "     ec2-user@$EC2_IP:$PWD/$IPA_PATH \\"
echo "     ~/Downloads/almed_ahu_android.ipa"
echo ""
echo "2️⃣  Upload via Transporter:"
echo "   - Open Transporter app (Mac App Store)"
echo "   - Sign in with Apple ID"
echo "   - Drag ~/Downloads/almed_ahu_android.ipa into Transporter"
echo "   - Click 'Deliver'"
echo ""
echo "3️⃣  Or upload via Xcode:"
echo "   - Open Xcode → Window → Organizer"
echo "   - Click '+' → Add IPA file"
echo "   - Select archive → 'Distribute App' → 'App Store Connect'"
echo ""
echo "4️⃣  Process in App Store Connect:"
echo "   - Go to: https://appstoreconnect.apple.com"
echo "   - My Apps → Your App → TestFlight"
echo "   - Wait for processing (10-30 minutes)"
echo "   - Add to test groups"
echo ""
echo "📖 For detailed instructions, see: TESTFLIGHT_DEPLOYMENT_GUIDE.md"
echo ""

# Check version
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
echo "📱 Current version: $VERSION"
echo "💡 Remember to increment version for new builds!"
