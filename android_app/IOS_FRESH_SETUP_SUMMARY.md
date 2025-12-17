# iOS Fresh Setup Summary

## New Approach

Instead of using the existing `ios/` folder, we now **delete it and regenerate it fresh** using Flutter, then apply customizations.

## Why This Approach?

- ✅ Clean, fresh iOS project structure
- ✅ No legacy configuration issues
- ✅ Flutter generates latest iOS templates
- ✅ Only apply necessary customizations
- ✅ Easier to troubleshoot

## What's Different?

### Old Approach
- Used existing `ios/` folder
- Modified existing files
- Risk of legacy issues

### New Approach
1. Delete `ios/` folder
2. Generate fresh: `flutter create --platforms=ios .`
3. Apply customizations from `ios_customizations/` folder
4. Configure Firebase
5. Install pods

## Files Structure

```
android_app/
├── ios_customizations/          # Custom files to apply
│   ├── Podfile                  # Custom Podfile (Swift 5.9)
│   ├── AppDelegate.swift        # Firebase-enabled AppDelegate
│   ├── Info.plist.additions     # Firebase/Google Sign-In config
│   └── README.md                # Instructions
├── FRESH_EC2_IOS_SETUP.md       # Complete setup guide
├── EC2_CURSOR_PROMPT.txt       # Quick prompt for Cursor
└── setup_fresh_ec2.sh          # Automated setup script
```

## Quick Setup Steps

```bash
# 1. Generate fresh iOS folder
cd android_app
rm -rf ios
flutter create --platforms=ios .

# 2. Apply customizations
cp ios_customizations/Podfile ios/Podfile
cp ios_customizations/AppDelegate.swift ios/Runner/AppDelegate.swift

# 3. Add Firebase config to Info.plist
# (Manually add entries from Info.plist.additions)

# 4. Copy GoogleService-Info.plist
# (From Firebase Console)

# 5. Update REVERSED_CLIENT_ID in Info.plist

# 6. Install pods
cd ios
pod install
cd ..

# 7. Build
flutter build ios --simulator
```

## For Cursor Agents

Use the prompt in `EC2_CURSOR_PROMPT.txt` - it includes all steps to:
1. Delete ios folder
2. Regenerate it
3. Apply customizations
4. Configure Firebase
5. Build

## Benefits

- **Clean Start**: No legacy configuration
- **Latest Templates**: Flutter generates latest iOS structure
- **Minimal Customization**: Only what's needed
- **Easy Troubleshooting**: Know exactly what was customized
- **Reproducible**: Same process every time

---

**Note**: The `ios/` folder is now generated, not committed. Customizations are in `ios_customizations/` folder.

