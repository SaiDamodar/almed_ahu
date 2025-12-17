#!/bin/bash

# Script to build IPA and provide download instructions

echo "🔨 Building IPA for iOS..."
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app

flutter build ipa --release

if [ $? -eq 0 ]; then
    IPA_PATH=$(find build/ios/ipa -name "*.ipa" | head -1)
    IPA_SIZE=$(ls -lh "$IPA_PATH" | awk '{print $5}')
    
    echo ""
    echo "✅ IPA built successfully!"
    echo "📦 File: $IPA_PATH"
    echo "📊 Size: $IPA_SIZE"
    echo ""
    echo "📥 To download to your local machine, run from your local terminal:"
    echo ""
    echo "   scp -i /path/to/your-key.pem \\"
    echo "     ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'YOUR_EC2_IP'):$IPA_PATH \\"
    echo "     ~/Downloads/"
    echo ""
    echo "📱 Then install on iPhone:"
    echo "   1. Connect iPhone to local Mac via USB"
    echo "   2. Open Xcode → Window → Devices and Simulators"
    echo "   3. Select iPhone → Click '+' → Select IPA file"
    echo ""
else
    echo "❌ Build failed. Check errors above."
    exit 1
fi
