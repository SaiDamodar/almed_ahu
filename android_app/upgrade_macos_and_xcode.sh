#!/bin/bash

# macOS and Xcode Upgrade Script
# This will upgrade macOS to 15.7.3, then install Xcode 16+

echo "🔄 macOS and Xcode Upgrade Script"
echo "==================================="
echo ""
echo "⚠️  WARNING: This will restart your EC2 Mac instance!"
echo "⚠️  Make sure you save all work before proceeding!"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

echo ""
echo "📥 Upgrading macOS to 15.7.3..."
echo "This will download ~5.3GB and restart your Mac"
echo ""

# Start the upgrade
sudo softwareupdate --install --all --restart

echo ""
echo "✅ Upgrade initiated. Your Mac will restart."
echo ""
echo "After restart:"
echo "1. macOS will be 15.7.3"
echo "2. Install Xcode 16+ from App Store"
echo "3. Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
echo "4. Run: sudo xcodebuild -license accept"
echo "5. Rebuild IPA: flutter build ipa --release"
echo "6. Upload: ./upload_to_testflight.sh"
