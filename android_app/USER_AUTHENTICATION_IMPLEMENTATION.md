# Hospital User Authentication Implementation

## Overview
This document describes the hospital user authentication and registration system implemented for the Android app.

## Features Implemented

### 1. User Models
- **`User` model** (`lib/models/user.dart`):
  - Stores user information (email, username, phone, hospital name, etc.)
  - Tracks user status (pending, approved, active, rejected, suspended)
  - Manages assigned AHU IDs
  - Provides status display messages

- **`RegisterRequest` model** (`lib/models/register_request.dart`):
  - Handles registration data
  - Supports both email and Google registration

### 2. Registration Screen
- **Location**: `lib/screens/register_screen.dart`
- **Features**:
  - Email, username, phone number, hospital name fields
  - Password and confirm password fields
  - Form validation
  - Consistent UI with app theme
  - Loading states
  - Navigation to home screen after successful registration

### 3. User Login Screen
- **Location**: `lib/screens/user_login_screen.dart`
- **Features**:
  - Email and password login
  - Google Sign-In button (UI only, implementation pending)
  - Consistent UI with app theme
  - Navigation to registration screen
  - Error handling

### 4. Home Screen
- **Location**: `lib/screens/home_screen.dart`
- **Features**:
  - Status messages based on user status:
    - **Pending**: "Waiting for Verification"
    - **Rejected**: "Your request is rejected"
    - **Approved**: "Waiting for AHU Assignment"
    - **Suspended**: "Account Suspended"
    - **Active**: Shows assigned AHU units
  - User profile display
  - List of assigned AHU units
  - Navigation to AHU control screen
  - Logout functionality
  - Refresh capability

### 5. API Service Updates
- **Location**: `lib/services/api_service.dart`
- **New Methods**:
  - `register(RegisterRequest request)`: Register new hospital user
  - `userLogin(String email, String password)`: Login hospital user
  - `checkUserStatus()`: Check current user status

### 6. App Provider Updates
- **Location**: `lib/providers/app_provider.dart`
- **New Features**:
  - Separate admin and user authentication
  - `register()`: Handle user registration
  - `userLogin()`: Handle user login
  - `checkUserStatus()`: Check and update user status
  - `currentUser`: Get current logged-in user
  - `isAdmin`: Check if user is admin

### 7. Routing Updates
- **Location**: `lib/main.dart`
- **Features**:
  - `AuthWrapper`: Automatically routes based on authentication state
  - Admin users → Admin dashboard
  - Hospital users → Home screen
  - Unauthenticated → Landing screen

### 8. Landing Screen Updates
- **Location**: `lib/screens/landing_screen.dart`
- **Changes**:
  - Updated "Hospital User" card to route to login screen
  - Removed "Coming Soon" badge

## User Flow

### Registration Flow
1. User taps "Hospital User" on landing screen
2. User taps "Register" on login screen
3. User fills registration form
4. User submits registration
5. User is redirected to home screen with "Waiting for Verification" status
6. Admin approves/rejects from admin panel
7. If approved, user sees "Waiting for AHU Assignment"
8. Admin assigns AHUs to user
9. User sees assigned AHUs on home screen

### Login Flow
1. User taps "Hospital User" on landing screen
2. User enters email and password (or uses Google Sign-In)
3. User is redirected to home screen
4. Home screen shows appropriate status or assigned AHUs

## Backend API Endpoints Required

The following endpoints need to be implemented on the Flask backend:

### 1. POST `/api/register`
**Request Body**:
```json
{
  "email": "user@example.com",
  "username": "johndoe",
  "phone_number": "1234567890",
  "hospital_name": "City Hospital",
  "password": "password123",
  "google_id": "optional_google_id",
  "profile_image_url": "optional_image_url"
}
```

**Response**:
```json
{
  "success": true,
  "user": {
    "_id": "user_id",
    "email": "user@example.com",
    "username": "johndoe",
    "phone_number": "1234567890",
    "hospital_name": "City Hospital",
    "status": "pending",
    "assigned_ahu_ids": [],
    "created_at": "2025-01-20T10:00:00Z"
  }
}
```

### 2. POST `/api/user/login`
**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response**:
```json
{
  "success": true,
  "user": {
    "_id": "user_id",
    "email": "user@example.com",
    "username": "johndoe",
    "phone_number": "1234567890",
    "hospital_name": "City Hospital",
    "status": "active",
    "assigned_ahu_ids": ["ahu1", "ahu2"],
    "created_at": "2025-01-20T10:00:00Z"
  }
}
```

### 3. GET `/api/user/status`
**Headers**: Cookie with session

**Response**:
```json
{
  "success": true,
  "user": {
    "_id": "user_id",
    "email": "user@example.com",
    "username": "johndoe",
    "phone_number": "1234567890",
    "hospital_name": "City Hospital",
    "status": "active",
    "assigned_ahu_ids": ["ahu1", "ahu2"],
    "created_at": "2025-01-20T10:00:00Z"
  }
}
```

## MongoDB Schema

The user collection should have the following structure:

```javascript
{
  _id: ObjectId,
  email: String (unique, required),
  username: String (required),
  phone_number: String (required),
  hospital_name: String (required),
  password: String (hashed, required),
  google_id: String (optional),
  profile_image_url: String (optional),
  status: String (enum: ['pending', 'approved', 'active', 'rejected', 'suspended'], default: 'pending'),
  assigned_ahu_ids: [String] (default: []),
  created_at: Date,
  updated_at: Date
}
```

## Admin Panel Requirements

The admin panel needs to be updated with:

### 1. Users Page
- **Two sections**:
  - **Pending Registrations**: List of users with `status: 'pending'`
    - Show user details (email, username, phone, hospital name)
    - "Accept" button → Changes status to `approved`
    - "Reject" button → Changes status to `rejected`
  
  - **Registered Users**: List of users with `status: 'approved'` or `status: 'active'`
    - Show user details
    - "Assign AHUs" button → Opens dialog to select AHU units
    - Shows currently assigned AHUs

### 2. API Endpoints for Admin
- `GET /api/admin/users/pending`: Get pending registrations
- `GET /api/admin/users/registered`: Get registered users
- `POST /api/admin/users/:userId/approve`: Approve user registration
- `POST /api/admin/users/:userId/reject`: Reject user registration
- `POST /api/admin/users/:userId/assign-ahus`: Assign AHUs to user

## Pending Features

### 1. Google Sign-In
- **Status**: UI implemented, backend integration pending
- **Requirements**:
  - Add `google_sign_in` package to `pubspec.yaml`
  - Implement Google Sign-In flow
  - After Google authentication, show form for username, phone, hospital name
  - Send Google ID to backend during registration

### 2. Password Reset
- Forgot password functionality
- Email verification for password reset

### 3. Profile Management
- Edit profile information
- Change password
- Update profile picture

## Testing Checklist

- [ ] Registration with valid data
- [ ] Registration with invalid data (validation)
- [ ] Login with correct credentials
- [ ] Login with incorrect credentials
- [ ] Home screen shows correct status messages
- [ ] Assigned AHUs display correctly
- [ ] Navigation to AHU control screen works
- [ ] Logout functionality
- [ ] Session persistence
- [ ] Status updates after admin actions

## Notes

- All UI is consistent with the existing app theme
- Error handling is implemented for network issues
- Loading states are shown during API calls
- Form validation is comprehensive
- The app automatically routes based on authentication state

