#!/bin/bash
# Setup script for enabling mobile platforms in Flutter project

echo "🚀 Setting up mobile platforms for AHU Dashboard..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "Please install Flutter SDK first"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Enable Android and iOS platforms
echo "📱 Enabling Android and iOS platforms..."
flutter create --platforms=android,ios .

if [ $? -eq 0 ]; then
    echo "✅ Mobile platforms enabled successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Add google-services.json to android/app/"
    echo "2. Add GoogleService-Info.plist to ios/Runner/"
    echo "3. Run: flutter pub get"
    echo "4. Run: flutter build apk --release"
else
    echo "❌ Failed to enable mobile platforms"
    exit 1
fi

echo ""
echo "✨ Mobile setup complete!"

