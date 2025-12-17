#!/bin/bash

# iOS Device Deployment Script
# This script helps deploy the Flutter app to a connected iPhone

echo "🔍 Checking for connected devices..."
flutter devices

echo ""
echo "📱 To deploy to your iPhone:"
echo "1. Connect iPhone via USB"
echo "2. Trust computer on iPhone (Settings → General → VPN & Device Management)"
echo "3. In Xcode: Signing & Capabilities → Select Team → Enable 'Automatically manage signing'"
echo "4. Run: flutter run --release"
echo ""
echo "📖 For detailed instructions, see: IOS_DEVICE_DEPLOYMENT.md"
echo ""

# Check if device is connected
DEVICE_COUNT=$(flutter devices | grep -c "iPhone" || echo "0")
if [ "$DEVICE_COUNT" -gt 0 ]; then
    echo "✅ iPhone detected!"
    echo "🚀 Ready to deploy. Run: flutter run --release"
else
    echo "⚠️  No iPhone detected. Connect your device and try again."
fi
