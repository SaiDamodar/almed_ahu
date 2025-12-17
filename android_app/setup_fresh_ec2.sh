#!/bin/bash

# Fresh EC2 Mac iOS Setup Script
# Run this on a brand new EC2 Mac instance

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "Fresh EC2 Mac iOS Setup"
echo "==========================================${NC}"

# Get current user
CURRENT_USER=$(whoami)
echo -e "${GREEN}Current user: $CURRENT_USER${NC}"

# Phase 1: Install Xcode Command Line Tools
echo -e "\n${YELLOW}Phase 1: Installing Xcode Command Line Tools...${NC}"
if ! xcode-select -p &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please complete the installation, then run this script again."
    exit 0
else
    echo -e "${GREEN}✓ Xcode Command Line Tools already installed${NC}"
fi

# Accept Xcode license
echo -e "\n${YELLOW}Accepting Xcode license...${NC}"
sudo xcodebuild -license accept || true
echo -e "${GREEN}✓ License accepted${NC}"

# Check if Xcode is installed
echo -e "\n${YELLOW}Checking Xcode installation...${NC}"
if [ ! -d "/Applications/Xcode.app" ]; then
    echo -e "${RED}⚠ Xcode not found in /Applications/Xcode.app${NC}"
    echo -e "${YELLOW}Please install Xcode from App Store or download from developer.apple.com${NC}"
    echo -e "${YELLOW}After installation, run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer${NC}"
else
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
    XCODE_VERSION=$(xcodebuild -version | head -1)
    echo -e "${GREEN}✓ $XCODE_VERSION installed${NC}"
fi

# Phase 2: Install Flutter
echo -e "\n${YELLOW}Phase 2: Installing Flutter...${NC}"
if [ ! -d "$HOME/flutter" ]; then
    echo "Cloning Flutter repository..."
    cd ~
    git clone https://github.com/flutter/flutter.git -b stable
    echo -e "${GREEN}✓ Flutter cloned${NC}"
else
    echo -e "${GREEN}✓ Flutter already exists${NC}"
fi

# Add Flutter to PATH
if ! grep -q "flutter/bin" ~/.zshrc 2>/dev/null; then
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
    echo -e "${GREEN}✓ Flutter added to PATH${NC}"
fi

# Source to use in current session
export PATH="$PATH:$HOME/flutter/bin"

# Verify Flutter
FLUTTER_VERSION=$(flutter --version | head -1)
echo -e "${GREEN}✓ $FLUTTER_VERSION${NC}"

# Phase 3: Install CocoaPods
echo -e "\n${YELLOW}Phase 3: Installing CocoaPods...${NC}"
if ! command -v pod &> /dev/null; then
    echo "Installing CocoaPods..."
    sudo gem install cocoapods
    pod setup
    echo -e "${GREEN}✓ CocoaPods installed${NC}"
else
    POD_VERSION=$(pod --version)
    echo -e "${GREEN}✓ CocoaPods already installed: $POD_VERSION${NC}"
fi

# Phase 4: Fix Permissions
echo -e "\n${YELLOW}Phase 4: Fixing permissions...${NC}"
sudo chmod -R 755 /tmp || true
sudo chown -R $CURRENT_USER /tmp || true
mkdir -p ~/Library/Developer/Xcode/DerivedData
chmod -R 755 ~/Library/Developer/Xcode/DerivedData
mkdir -p ~/.cocoapods
chmod -R 755 ~/.cocoapods
echo -e "${GREEN}✓ Permissions fixed${NC}"

# Phase 5: Check if project exists
echo -e "\n${YELLOW}Phase 5: Checking project...${NC}"
if [ -d "$HOME/almed_ahu" ]; then
    echo -e "${GREEN}✓ Project found at $HOME/almed_ahu${NC}"
    PROJECT_PATH="$HOME/almed_ahu"
elif [ -d "$HOME/Desktop/Almed App/almed_ahu" ]; then
    echo -e "${GREEN}✓ Project found at $HOME/Desktop/Almed App/almed_ahu${NC}"
    PROJECT_PATH="$HOME/Desktop/Almed App/almed_ahu"
else
    echo -e "${YELLOW}⚠ Project not found. Please clone the repository:${NC}"
    echo -e "${YELLOW}  cd ~ && git clone https://github.com/your-username/almed_ahu.git${NC}"
    PROJECT_PATH=""
fi

# Fix project permissions if found
if [ -n "$PROJECT_PATH" ]; then
    echo "Fixing project permissions..."
    sudo chown -R $CURRENT_USER:staff "$PROJECT_PATH"
    chmod -R 755 "$PROJECT_PATH"
    echo -e "${GREEN}✓ Project permissions fixed${NC}"
    
    # Check if ios_customizations folder exists
    if [ -d "$PROJECT_PATH/android_app/ios_customizations" ]; then
        echo -e "${GREEN}✓ iOS customizations folder found${NC}"
    else
        echo -e "${YELLOW}⚠ iOS customizations folder not found${NC}"
        echo -e "${YELLOW}  Make sure ios_customizations/ folder exists in android_app/${NC}"
    fi
fi

# Summary
echo -e "\n${GREEN}=========================================="
echo "Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. If Xcode not installed: Install from App Store"
echo "2. Clone repository: cd ~ && git clone <repo-url>"
echo "3. Generate iOS folder:"
echo "   cd almed_ahu/android_app"
echo "   rm -rf ios"
echo "   flutter create --platforms=ios ."
echo "4. Apply customizations:"
echo "   cp ios_customizations/Podfile ios/Podfile"
echo "   cp ios_customizations/AppDelegate.swift ios/Runner/AppDelegate.swift"
echo "5. Configure Firebase:"
echo "   - Add iOS app in Firebase Console"
echo "   - Download GoogleService-Info.plist"
echo "   - Copy to ios/Runner/GoogleService-Info.plist"
echo "   - Update Info.plist with REVERSED_CLIENT_ID"
echo "6. Install pods: cd ios && pod install && cd .."
echo "7. Build: flutter build ios --simulator"
echo ""
echo -e "${YELLOW}Read FRESH_EC2_IOS_SETUP.md for detailed instructions.${NC}"

