# Firebase Setup Guide for Android App

## Prerequisites
- Firebase project created: `AlemdAHU-0107`
- Android app added to Firebase with package name: `com.almed.ahu_android`
- SHA-1 certificate fingerprint added to Firebase

## Steps to Complete Setup

### 1. Download google-services.json
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project: `AlemdAHU-0107`
3. Click on the Android app: `AHU Monitor` (com.almed.ahu_android)
4. Click "Download google-services.json"
5. Place the file in: `android_app/android/app/google-services.json`

### 2. Enable Google Sign-In in Firebase
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in provider
3. Add your support email
4. Save

### 3. Install Dependencies
Run in the `android_app` directory:
```bash
flutter pub get
```

### 4. Build Configuration
The following files have been updated:
- ✅ `pubspec.yaml` - Added Firebase and Google Sign-In dependencies
- ✅ `android/build.gradle` - Added Google Services plugin
- ✅ `android/app/build.gradle` - Applied Google Services plugin
- ✅ `lib/main.dart` - Initialized Firebase

### 5. Verify Setup
1. Make sure `google-services.json` is in `android_app/android/app/`
2. Run `flutter clean`
3. Run `flutter pub get`
4. Build the app: `flutter build apk --debug`

## Google Sign-In Flow

1. **User taps "Continue with Google"**
   - Firebase handles Google authentication
   - Returns user info (email, name, photo, ID token)

2. **Check if user exists**
   - Try to login with Google credentials
   - If successful → Navigate to Home Screen
   - If user not found → Show completion screen

3. **Complete Registration (New Users)**
   - Collect: Username, Phone Number, Hospital Name
   - Register with Google ID and additional info
   - Status: Pending (waiting for admin approval)

4. **Admin Approval**
   - Admin approves user from admin panel
   - User status changes to "approved"
   - Admin assigns AHUs
   - User status changes to "active"

## Backend Endpoints

### POST `/api/register/google`
Register new user with Google authentication.

**Request:**
```json
{
  "email": "user@example.com",
  "username": "johndoe",
  "phone_number": "1234567890",
  "hospital_name": "City Hospital",
  "google_id": "firebase_uid",
  "profile_image_url": "https://...",
  "id_token": "firebase_id_token"
}
```

### POST `/api/user/login/google`
Login existing user with Google.

**Request:**
```json
{
  "google_id": "firebase_uid",
  "email": "user@example.com",
  "display_name": "John Doe",
  "profile_image_url": "https://...",
  "id_token": "firebase_id_token"
}
```

## Security Notes

⚠️ **Important**: The backend currently accepts Google ID tokens without verification. In production, you should:

1. Install Firebase Admin SDK in the backend
2. Verify the ID token on the server
3. Only create/login users after token verification

Example (Python):
```python
from firebase_admin import auth, initialize_app

# Initialize Firebase Admin (once)
initialize_app()

# Verify token
try:
    decoded_token = auth.verify_id_token(id_token)
    uid = decoded_token['uid']
    email = decoded_token['email']
    # Proceed with user creation/login
except Exception as e:
    # Invalid token
    return error
```

## Troubleshooting

### Error: "Default FirebaseApp is not initialized"
- Make sure `google-services.json` is in the correct location
- Run `flutter clean` and rebuild

### Error: "Google Sign-In failed"
- Check if Google Sign-In is enabled in Firebase Console
- Verify SHA-1 fingerprint is added to Firebase
- Check internet connection

### Error: "User not found"
- This is normal for new users - they'll be shown the completion screen
- Make sure backend endpoints are deployed

## Testing

1. Test Google Sign-In with existing user
2. Test Google Sign-In with new user (should show completion screen)
3. Test registration completion
4. Test admin approval flow
5. Test login after approval

