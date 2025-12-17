# Complete TestFlight Deployment Guide

Step-by-step guide to deploy your iOS app to TestFlight for testing and distribution.

---

## Prerequisites

- ✅ Apple Developer Account (Free or Paid - $99/year for distribution)
- ✅ App built as IPA (already done ✅)
- ✅ Bundle ID: `com.almed.ahu` (already configured ✅)
- ✅ Apple ID with App Store Connect access

---

## Part 1: App Store Connect Setup

### Step 1: Access App Store Connect

1. **Go to App Store Connect**: https://appstoreconnect.apple.com
2. **Sign in** with your Apple ID (must be part of your developer team)
3. **Navigate to**: My Apps

### Step 2: Create New App

1. **Click the "+" button** (top left) → "New App"

2. **Fill in App Information**:
   - **Platform**: iOS
   - **Name**: "ALMED AHU" (or your preferred name)
   - **Primary Language**: English (or your preference)
   - **Bundle ID**: Select `com.almed.ahu` from dropdown
     - If not listed: Go to Certificates, Identifiers & Profiles → Identifiers → Register new App ID
   - **SKU**: `almed-ahu-001` (unique identifier, can be anything)
   - **User Access**: Full Access (or Limited if you have team)

3. **Click "Create"**

### Step 3: Complete App Information

1. **App Information Tab**:
   - **Category**: Select appropriate categories (e.g., Business, Productivity)
   - **Privacy Policy URL**: (Optional for TestFlight, required for App Store)
   - **Subtitle**: (Optional) Short description

2. **Pricing and Availability**:
   - Set price (Free or Paid)
   - Select countries/regions

3. **App Privacy** (Required):
   - Click "Get Started" or "Edit"
   - Answer privacy questions about data collection
   - For Firebase: You collect analytics, authentication data, etc.

---

## Part 2: Upload IPA to TestFlight

### Option A: Using Transporter App (Easiest)

#### Step 1: Install Transporter

1. **Open Mac App Store** on your local Mac (not EC2)
2. **Search for "Transporter"**
3. **Install** (Free app by Apple)

#### Step 2: Download IPA from EC2

From your **local machine** terminal:

```bash
# Replace YOUR_EC2_IP with your actual EC2 IP
# Replace /path/to/key.pem with your SSH key path

scp -i /path/to/your-key.pem \
  ec2-user@YOUR_EC2_IP:/Users/ec2-user/Desktop/Almed/almed_ahu/android_app/build/ios/ipa/almed_ahu_android.ipa \
  ~/Downloads/almed_ahu_android.ipa
```

#### Step 3: Upload via Transporter

1. **Open Transporter app** on your local Mac
2. **Sign in** with your Apple ID (same as App Store Connect)
3. **Drag and drop** the IPA file (`~/Downloads/almed_ahu_android.ipa`) into Transporter
4. **Click "Deliver"**
5. **Wait for upload** to complete (may take 5-15 minutes)
6. **You'll see**: "Successfully delivered" message

### Option B: Using Xcode Organizer

1. **Open Xcode** on your local Mac
2. **Window → Organizer** (or `Shift + Cmd + 9`)
3. **Archives tab**
4. **Click "+"** → **"Add"** → Select your IPA file
5. **Select archive** → **"Distribute App"**
6. **Choose**: "App Store Connect"
7. **Follow wizard** to upload

### Option C: Using Command Line (From EC2)

If you have App Store Connect API credentials:

```bash
# On EC2 Mac
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app

# Upload using altool (requires API key)
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/almed_ahu_android.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

**To get API credentials**:
1. App Store Connect → Users and Access → Keys
2. Create new API key
3. Download `.p8` key file
4. Note the Key ID and Issuer ID

---

## Part 3: Process Build in App Store Connect

### Step 1: Wait for Processing

1. **Go to App Store Connect** → My Apps → Your App
2. **TestFlight tab**
3. **iOS Builds section**
4. **You'll see**: "Processing" status
   - Usually takes 10-30 minutes
   - You'll get email when ready

### Step 2: Add Build Information (When Processing Complete)

1. **Click on the build** (when status changes to "Ready to Submit")
2. **Add Test Information** (if prompted):
   - What to test
   - Test notes
   - Contact information

### Step 3: Complete Compliance

1. **Export Compliance**:
   - Answer questions about encryption
   - For most apps: "No, this app does not use encryption"
   - If using HTTPS/Firebase: May need to select "Yes" and provide details

2. **Content Rights**:
   - Confirm you have rights to all content

---

## Part 4: Set Up TestFlight Testing

### Internal Testing (Up to 100 testers)

#### Step 1: Add Internal Testers

1. **TestFlight tab** → **Internal Testing**
2. **Click "+"** to create new group (e.g., "Internal Team")
3. **Add Testers**:
   - Click "Add" → Enter email addresses
   - Or select existing users from your team
4. **Select Build**: Choose your uploaded build
5. **Enable Testing**: Toggle on

#### Step 2: Testers Receive Invitation

- Testers get email invitation
- They need to install **TestFlight app** from App Store (free)
- Open invitation email on iPhone → Install TestFlight → Install your app

### External Testing (Up to 10,000 testers)

#### Step 1: Create External Test Group

1. **TestFlight tab** → **External Testing**
2. **Click "+"** to create new group
3. **Name it**: e.g., "Beta Testers"

#### Step 2: Add Build to External Testing

1. **Select your build**
2. **Add Test Information**:
   - **What to Test**: Describe what testers should focus on
   - **Feedback Email**: Your email for bug reports
   - **Description**: Instructions for testers

#### Step 3: Submit for Beta Review

1. **Click "Submit for Review"**
2. **Apple reviews** your app (usually 24-48 hours)
3. **Once approved**: Testers can install

#### Step 4: Add External Testers

1. **Testers section** → **Add Testers**
2. **Enter email addresses** (up to 10,000)
3. **Testers receive invitation** via email

---

## Part 5: Install on iPhone via TestFlight

### For Testers:

1. **Install TestFlight App**:
   - Go to App Store on iPhone
   - Search "TestFlight"
   - Install (free)

2. **Accept Invitation**:
   - Open invitation email on iPhone
   - Tap "View in TestFlight" or "Start Testing"
   - Or open TestFlight app → Tap invitation

3. **Install App**:
   - In TestFlight app, tap "Install" next to your app
   - App installs on iPhone
   - First launch: May need to trust developer certificate
     - Settings → General → VPN & Device Management
     - Tap your developer certificate → Trust

4. **Test the App**:
   - Launch app from home screen
   - TestFlight shows build number and expiration date
   - Can provide feedback directly from TestFlight

---

## Part 6: Managing TestFlight

### View Test Results

1. **App Store Connect** → Your App → TestFlight
2. **Crashes**: View crash reports
3. **Feedback**: Read tester feedback
4. **Usage**: See how many testers installed

### Update Build

When you have a new version:

1. **Build new IPA** on EC2:
   ```bash
   cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app
   flutter build ipa --release
   ```

2. **Update version** in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Increment version and build number
   ```

3. **Upload new IPA** (same process as before)

4. **Add to TestFlight**: New build appears, add to test groups

### Remove Testers

1. **TestFlight** → Select test group
2. **Testers tab** → Select tester → Remove

---

## Part 7: Troubleshooting

### Issue: "Invalid Bundle" Error

**Solution**:
- Check Bundle ID matches: `com.almed.ahu`
- Verify signing certificate is valid
- Ensure all required app icons are present

### Issue: "Missing Compliance" Error

**Solution**:
- Answer Export Compliance questions
- If using encryption: Provide compliance documentation

### Issue: Build Stuck in "Processing"

**Solution**:
- Wait up to 2 hours (usually 10-30 min)
- Check email for any issues
- Try uploading again if stuck >2 hours

### Issue: Testers Can't Install

**Solution**:
- Verify TestFlight app is installed
- Check invitation email was received
- Ensure iOS version meets minimum (iOS 13.0+)
- Check device is registered (for Ad Hoc, not needed for TestFlight)

### Issue: "App Expired" Error

**Solution**:
- TestFlight builds expire after 90 days
- Upload a new build
- Testers need to update via TestFlight

---

## Part 8: Quick Reference Commands

### Build IPA for TestFlight

```bash
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app

# Update version in pubspec.yaml first
# version: 1.0.1+2

flutter clean
flutter pub get
flutter build ipa --release
```

### Download IPA to Local Machine

```bash
# From your local machine
scp -i /path/to/key.pem \
  ec2-user@YOUR_EC2_IP:/Users/ec2-user/Desktop/Almed/almed_ahu/android_app/build/ios/ipa/almed_ahu_android.ipa \
  ~/Downloads/
```

### Check IPA Info

```bash
# On EC2 or local Mac
unzip -l build/ios/ipa/almed_ahu_android.ipa | head -20
```

---

## Part 9: Version Management

### Update Version Numbers

Edit `pubspec.yaml`:

```yaml
version: 1.0.1+2
#        ^    ^
#        |    └─ Build number (increment for each build)
#        └────── Version number (increment for releases)
```

**Rules**:
- **Version** (1.0.1): User-facing version, increment for new features
- **Build** (+2): Internal build number, increment for each upload

### Version History Example

```
1.0.0+1  - Initial TestFlight build
1.0.0+2  - Bug fixes (same version, new build)
1.0.1+1  - New features (new version)
1.0.1+2  - More bug fixes
1.1.0+1  - Major update
```

---

## Part 10: Best Practices

### Before Each Upload

- [ ] Update version/build number
- [ ] Test on simulator first
- [ ] Update release notes
- [ ] Check Firebase configuration
- [ ] Verify all features work

### TestFlight Testing

- [ ] Test on multiple devices (if possible)
- [ ] Test all critical features
- [ ] Check push notifications
- [ ] Verify Firebase authentication
- [ ] Test offline functionality

### Communication with Testers

- [ ] Provide clear testing instructions
- [ ] List known issues
- [ ] Set expectations (beta software)
- [ ] Collect feedback systematically
- [ ] Respond to tester questions

---

## Part 11: Moving to App Store

Once testing is complete:

1. **App Store Connect** → Your App → **App Store** tab
2. **Prepare for Submission**:
   - App screenshots (required)
   - App description
   - Keywords
   - Support URL
   - Marketing URL (optional)
   - Privacy policy URL (required)

3. **Select Build**: Choose from TestFlight builds

4. **Submit for Review**: Apple reviews (1-7 days typically)

5. **Release**: Once approved, app goes live on App Store

---

## Summary Checklist

### Initial Setup
- [ ] Create app in App Store Connect
- [ ] Complete app information
- [ ] Set up privacy policy
- [ ] Configure app categories

### Upload Process
- [ ] Build IPA on EC2
- [ ] Download IPA to local machine
- [ ] Upload via Transporter/Xcode
- [ ] Wait for processing (10-30 min)

### TestFlight Setup
- [ ] Create internal test group
- [ ] Add testers
- [ ] Enable build for testing
- [ ] (Optional) Set up external testing

### Testing
- [ ] Testers install TestFlight app
- [ ] Testers accept invitation
- [ ] Testers install and test app
- [ ] Collect feedback

### Updates
- [ ] Update version numbers
- [ ] Build new IPA
- [ ] Upload new build
- [ ] Notify testers of update

---

## Support Resources

- **App Store Connect Help**: https://help.apple.com/app-store-connect/
- **TestFlight Documentation**: https://developer.apple.com/testflight/
- **Transporter App**: https://apps.apple.com/us/app/transporter/id1450874784
- **Flutter iOS Deployment**: https://docs.flutter.dev/deployment/ios

---

## Your App Details

- **Bundle ID**: `com.almed.ahu`
- **Display Name**: "Almed Ahu Android"
- **Current Version**: 1.0.0+1
- **Firebase Project**: alemdahu-0107
- **IPA Location**: `build/ios/ipa/almed_ahu_android.ipa`

---

**Ready to deploy!** Follow the steps above to get your app on TestFlight. 🚀


