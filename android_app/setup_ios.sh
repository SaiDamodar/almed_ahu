#!/bin/bash

# iOS Setup Script for ALMED AHU App
# This script automates the iOS setup process for EC2 Mac instances

set -e  # Exit on error

echo "=========================================="
echo "iOS Setup Script for ALMED AHU"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get current user
CURRENT_USER=$(whoami)
echo -e "${GREEN}Current user: $CURRENT_USER${NC}"

# Detect project path
if [ -d "$HOME/Desktop/Almed App/almed_ahu" ]; then
    PROJECT_PATH="$HOME/Desktop/Almed App/almed_ahu"
elif [ -d "$HOME/almed_ahu" ]; then
    PROJECT_PATH="$HOME/almed_ahu"
else
    echo -e "${RED}Error: Project not found. Please set PROJECT_PATH manually.${NC}"
    exit 1
fi

echo -e "${GREEN}Project path: $PROJECT_PATH${NC}"
cd "$PROJECT_PATH/android_app"

# Step 1: Fix Permissions
echo -e "\n${YELLOW}Step 1: Fixing permissions...${NC}"
sudo chown -R $CURRENT_USER:staff "$PROJECT_PATH" || true
chmod -R 755 "$PROJECT_PATH" || true
sudo chown -R $CURRENT_USER:staff /usr/local/share/flutter 2>/dev/null || true
chmod -R 755 /usr/local/share/flutter 2>/dev/null || true
sudo chmod -R 755 /tmp || true
sudo chown -R $CURRENT_USER /tmp || true
mkdir -p ~/Library/Developer/Xcode/DerivedData
chmod -R 755 ~/Library/Developer/Xcode/DerivedData
mkdir -p ~/.cocoapods
chmod -R 755 ~/.cocoapods
chmod -R 755 ~/Library/Caches/CocoaPods 2>/dev/null || true
echo -e "${GREEN}✓ Permissions fixed${NC}"

# Step 2: Verify CocoaPods
echo -e "\n${YELLOW}Step 2: Checking CocoaPods...${NC}"
if ! command -v pod &> /dev/null; then
    echo -e "${YELLOW}Installing CocoaPods...${NC}"
    sudo gem install cocoapods
    pod setup
else
    POD_VERSION=$(pod --version)
    echo -e "${GREEN}✓ CocoaPods installed: $POD_VERSION${NC}"
fi

# Step 3: Clean Flutter
echo -e "\n${YELLOW}Step 3: Cleaning Flutter...${NC}"
flutter clean
echo -e "${GREEN}✓ Flutter cleaned${NC}"

# Step 4: Get Flutter Dependencies
echo -e "\n${YELLOW}Step 4: Getting Flutter dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✓ Flutter dependencies installed${NC}"

# Step 5: Clean iOS Pods
echo -e "\n${YELLOW}Step 5: Cleaning iOS pods...${NC}"
cd ios
rm -rf Pods Podfile.lock .symlinks 2>/dev/null || true
pod deintegrate 2>/dev/null || true
echo -e "${GREEN}✓ iOS pods cleaned${NC}"

# Step 6: Install Pods
echo -e "\n${YELLOW}Step 6: Installing iOS pods...${NC}"
pod install --repo-update
echo -e "${GREEN}✓ iOS pods installed${NC}"

# Step 7: Verify GoogleService-Info.plist
echo -e "\n${YELLOW}Step 7: Checking GoogleService-Info.plist...${NC}"
if grep -qi "YOUR_CLIENT_ID" Runner/GoogleService-Info.plist 2>/dev/null; then
    echo -e "${RED}⚠ Warning: GoogleService-Info.plist appears to be a placeholder${NC}"
    echo -e "${YELLOW}Please download the real file from Firebase Console and replace it.${NC}"
else
    echo -e "${GREEN}✓ GoogleService-Info.plist appears to be configured${NC}"
fi

# Step 8: Clean Xcode Derived Data
echo -e "\n${YELLOW}Step 8: Cleaning Xcode derived data...${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo -e "${GREEN}✓ Xcode derived data cleaned${NC}"

# Step 9: Verify Setup
echo -e "\n${YELLOW}Step 9: Verifying setup...${NC}"
cd ..
flutter doctor
echo -e "\n${GREEN}✓ Setup complete!${NC}"

# Summary
echo -e "\n${GREEN}=========================================="
echo "Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Ensure GoogleService-Info.plist is from Firebase Console"
echo "2. Update Info.plist with REVERSED_CLIENT_ID if needed"
echo "3. Open project: open ios/Runner.xcworkspace"
echo "4. Build: flutter build ios --simulator"
echo ""
echo -e "${YELLOW}Note: Always open .xcworkspace, NOT .xcodeproj${NC}"

