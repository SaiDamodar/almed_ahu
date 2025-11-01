# User Authentication & Multi-User Access Guide

## Complete Guide for Google Auth + Device-Level Access Control

---

## 🎯 What You Want to Achieve

```
Users authenticate with Google → Admin assigns AHU devices to each user
Admin sees ALL devices → Regular users see only THEIR assigned devices
```

### Current vs Future Architecture

**Current (Simple):**
```
Login Screen → Select Role (Hospital/Admin) → All Devices Visible
```

**Future (Your Vision):**
```
Google Login → Authenticate → Check User's Assigned Devices
Admin: See ALL devices
User: See only assigned devices (e.g., ICU-1 user sees only ahu-01)
```

---

## 📊 System Architecture Options

### Option 1: MQTT Topic-Based Access Control ⭐ **RECOMMENDED**

**How It Works:**
- Each user subscribes to specific device topics only
- HiveMQ supports `username` and per-user access control
- Filter devices in dashboard based on user permissions

**Pros:**
- ✅ Works with your current setup
- ✅ MQTT-native security
- ✅ No backend database needed (simple start)
- ✅ Scales well

**Cons:**
- ⚠️ Requires manual topic configuration per user in HiveMQ

---

### Option 2: Backend API with JWT Tokens

**How It Works:**
- Google OAuth → Get JWT token
- Backend API checks user permissions
- Returns list of accessible device IDs
- Dashboard filters devices

**Pros:**
- ✅ More flexible permissions
- ✅ Centralized user management
- ✅ Audit logging

**Cons:**
- ⚠️ Needs backend server (Node.js/Python)
- ⚠️ Database required (user-device mapping)
- ⚠️ More complex setup

---

### Option 3: Hybrid (Simple Start)

**How It Works:**
- Google Auth for login
- Store user permissions in `SharedPreferences` / file
- Filter devices in dashboard

**Pros:**
- ✅ Google Auth integration
- ✅ No backend needed initially
- ✅ Can migrate to Option 2 later

**Cons:**
- ⚠️ Local storage (not perfect for security)
- ⚠️ Manual permission management

---

## 🚀 Recommended Implementation Plan

### Phase 1: Google Auth + Local Permissions (Start Here)

**Goal**: Get Google login working with device filtering

#### Step 1: Add Google Sign-In to Flutter

**Install Package:**
```yaml
# pubspec.yaml
dependencies:
  google_sign_in: ^6.1.5
  shared_preferences: ^2.2.0
```

**Update Login Screen:**
```dart
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? user = await _googleSignIn.signIn();
      
      if (user != null) {
        // User signed in successfully
        final email = user.email;
        
        // TODO: Check user permissions
        // For now, navigate to dashboard
        _navigateToDashboard(user);
      }
    } catch (e) {
      print('Google sign-in error: $e');
      // Show error dialog
    }
  }

  void _navigateToDashboard(GoogleSignInAccount user) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Check if user is admin
    final isAdmin = _isAdminUser(user.email);
    
    if (isAdmin) {
      provider.setUserRole(UserRole.admin);
    } else {
      provider.setUserRole(UserRole.hospital);
    }
    
    // Set user info
    provider.setUserEmail(user.email);
    provider.setUserName(user.displayName);
    
    // Get user's assigned devices
    final assignedDevices = _getAssignedDevices(user.email);
    provider.setAssignedDevices(assignedDevices);
    
    // Navigate to dashboard
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  bool _isAdminUser(String? email) {
    // Hardcoded admin list (replace with backend later)
    final adminEmails = [
      'admin@hospital.com',
      'supervisor@hospital.com',
    ];
    return adminEmails.contains(email);
  }

  List<String> _getAssignedDevices(String? email) {
    // Hardcoded device assignments (replace with backend/database later)
    final deviceAssignments = {
      'doctor@hospital.com': ['ahu-01'],
      'nurse1@hospital.com': ['ahu-01', 'ahu-02'],
      'manager@hospital.com': ['ahu-01', 'ahu-02', 'ahu-03'],
    };
    
    // Admin gets all devices
    if (_isAdminUser(email)) {
      return [];  // Empty list = all devices
    }
    
    return deviceAssignments[email] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _signInWithGoogle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.login),
              const SizedBox(width: 8),
              const Text('Sign in with Google'),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### Step 2: Update AppProvider for Device Filtering

**Add to app_provider.dart:**
```dart
class AppProvider extends ChangeNotifier {
  // ... existing code ...
  
  String? _userEmail;
  String? _userName;
  List<String> _assignedDevices = [];
  
  // Getters
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  List<String> get assignedDevices => _assignedDevices;
  
  // Methods
  void setUserEmail(String? email) {
    _userEmail = email;
    notifyListeners();
  }
  
  void setUserName(String? name) {
    _userName = name;
    notifyListeners();
  }
  
  void setAssignedDevices(List<String> devices) {
    _assignedDevices = devices;
    notifyListeners();
  }
  
  // Filter AHU units based on permissions
  List<AhuUnit> get visibleAhuUnits {
    // Admin sees all devices
    if (_assignedDevices.isEmpty) {
      return _ahuUnits.values.toList();
    }
    
    // Regular users see only assigned devices
    return _ahuUnits.values
        .where((unit) => _assignedDevices.contains(unit.id))
        .toList();
  }
}
```

#### Step 3: Update Dashboard to Use Filtered Devices

**In dashboard_screen.dart:**
```dart
Consumer<AppProvider>(
  builder: (context, provider, child) {
    final visibleUnits = provider.visibleAhuUnits;
    
    return ListView.builder(
      itemCount: visibleUnits.length,
      itemBuilder: (context, index) {
        final unit = visibleUnits[index];
        // Show unit card
      },
    );
  },
)
```

---

### Phase 2: Add Backend API (Later)

When you're ready to scale, add a backend:

**Backend (Node.js/Python):**
```
GET /api/user/devices?email=user@hospital.com
Response: { devices: ['ahu-01', 'ahu-02'] }

POST /api/admin/assign-device
Body: { email: 'user@hospital.com', deviceId: 'ahu-01' }
```

**Flutter App:**
```dart
Future<List<String>> _getAssignedDevices(String email) async {
  final response = await http.get(
    Uri.parse('$API_URL/user/devices?email=$email'),
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<String>.from(data['devices']);
  }
  
  return [];
}
```

---

## 🔐 MQTT Security with HiveMQ

### Option A: Username-Based Access (Simple)

**HiveMQ Credentials per User:**
```
User: doctor@hospital.com
MQTT Username: doctor_hospital
MQTT Password: [random secure password]

User: admin@hospital.com
MQTT Username: admin_hospital
MQTT Password: [admin password]
```

**HiveMQ ACLs (Access Control Lists):**
```yaml
# Topic filters per user
user: doctor_hospital
  read: almed/ahu/hospitalA/icu1/ahu-01/#
  write: almed/ahu/hospitalA/icu1/ahu-01/cmd

user: admin_hospital
  read: almed/ahu/#
  write: almed/ahu/#/cmd
```

**Setup in HiveMQ Cloud Console:**
1. Go to Access Management
2. Create credentials per user
3. Set up ACL rules

---

### Option B: Shared Credentials + App-Level Filtering (Easier)

**One MQTT credential shared by all users:**
```
MQTT Username: almed
MQTT Password: AlMed123456
```

**Filter in Flutter app:**
```dart
class AppProvider extends ChangeNotifier {
  List<String> _assignedDevices = [];
  
  List<AhuUnit> get visibleAhuUnits {
    if (_assignedDevices.isEmpty) return _ahuUnits.values.toList();
    return _ahuUnits.values
        .where((unit) => _assignedDevices.contains(unit.id))
        .toList();
  }
}
```

**Pros:**
- ✅ Simpler MQTT setup
- ✅ Works immediately
- ✅ No per-user HiveMQ credentials

**Cons:**
- ⚠️ All users connect with same MQTT credentials
- ⚠️ Security enforced at app level only
- ⚠️ If app hacked, all devices accessible

**Recommendation**: Start with Option B, migrate to Option A when scaling.

---

## 📊 Complete Flow Examples

### Flow 1: Admin User (All Devices)

```
1. Admin clicks "Sign in with Google"
2. Google OAuth → Email: admin@hospital.com
3. App checks: Is admin? → YES
4. App sets: assignedDevices = [] (empty = all)
5. Connect to MQTT: shared credentials
6. Subscribe to: almed/ahu/# (all devices)
7. Dashboard shows: ALL ESP32 devices
8. Can control: ALL devices
```

### Flow 2: Regular User (Assigned Devices)

```
1. User clicks "Sign in with Google"
2. Google OAuth → Email: doctor@hospital.com
3. App checks: Is admin? → NO
4. App checks: Assigned devices → ['ahu-01']
5. App sets: assignedDevices = ['ahu-01']
6. Connect to MQTT: shared credentials
7. Subscribe to: almed/ahu/# (all topics)
8. Dashboard filters: Shows only ahu-01
9. Can control: Only ahu-01
```

### Flow 3: Admin Assigning Devices

```
1. Admin logs in (sees all devices)
2. Goes to "User Management" screen
3. Searches for user: doctor@hospital.com
4. Clicks "Assign Devices"
5. Selects: ahu-01
6. Clicks "Save"
7. Updates SharedPreferences/database
8. Next time doctor logs in → sees only ahu-01
```

---

## 🛠️ Implementation Checklist

### Phase 1: Basic Google Auth (Week 1)

- [ ] Add `google_sign_in` package to Flutter
- [ ] Set up Google OAuth in Google Cloud Console
- [ ] Update login screen with Google Sign-In button
- [ ] Add hardcoded admin list
- [ ] Add hardcoded device assignments
- [ ] Filter devices in dashboard
- [ ] Test admin login (sees all devices)
- [ ] Test user login (sees assigned devices only)

### Phase 2: Device Assignment UI (Week 2)

- [ ] Create "User Management" screen (admin only)
- [ ] Show list of users and assigned devices
- [ ] Add "Assign Device" dialog
- [ ] Save assignments to SharedPreferences
- [ ] Load assignments on login
- [ ] Test device assignment flow

### Phase 3: Backend Integration (Week 3+)

- [ ] Set up backend server (Node.js/Python)
- [ ] Create database (user-device mappings)
- [ ] Implement REST API endpoints
- [ ] Update Flutter app to call API
- [ ] Add real-time updates
- [ ] Add audit logging

---

## 📁 File Structure

```
ahu_dashboard/
├── lib/
│   ├── models/
│   │   ├── user_role.dart          # enum UserRole { hospital, admin }
│   │   └── user_permissions.dart   # NEW: UserPermissions class
│   ├── providers/
│   │   ├── app_provider.dart       # Modified: add device filtering
│   │   └── auth_provider.dart      # NEW: Google Sign-In logic
│   ├── screens/
│   │   ├── login_screen.dart       # Modified: Google Sign-In button
│   │   ├── dashboard_screen.dart   # Modified: use filtered devices
│   │   ├── user_management.dart    # NEW: Admin assigns devices
│   │   └── admin_screen.dart       # Add link to user management
│   └── services/
│       ├── mqtt_service.dart       # NO CHANGES (still works)
│       └── auth_service.dart       # NEW: Google Sign-In wrapper
├── pubspec.yaml                     # Add google_sign_in package
└── android/app/google-services.json # NEW: Google OAuth config
```

---

## 🔒 Security Considerations

### Current Risk Assessment

**Low Risk:**
- ✅ ESP32 → Cloud: TLS encrypted
- ✅ Mobile app → Cloud: TLS encrypted
- ✅ Commands published securely

**Medium Risk:**
- ⚠️ Shared MQTT credentials
- ⚠️ Device filtering in app only
- ⚠️ No backend verification

**Mitigations:**
1. Start with app-level filtering (good enough for hospital use)
2. Add MQTT per-user credentials when scaling
3. Add backend API before production deployment
4. Consider rate limiting on MQTT commands

---

## 🚀 Quick Start Implementation

### Step 1: Add Google Sign-In (15 minutes)

**pubspec.yaml:**
```yaml
dependencies:
  google_sign_in: ^6.1.5
```

**Run:**
```bash
flutter pub get
```

**Login Screen (replace existing):**
```dart
import 'package:google_sign_in/google_sign_in.dart';

ElevatedButton.icon(
  onPressed: () async {
    final GoogleSignIn _googleSignIn = GoogleSignIn();
    final user = await _googleSignIn.signIn();
    
    if (user != null) {
      // Handle sign-in
      print('Signed in: ${user.email}');
    }
  },
  icon: Icon(Icons.login),
  label: Text('Sign in with Google'),
)
```

---

### Step 2: Add Device Filtering (30 minutes)

**app_provider.dart:**
```dart
class AppProvider extends ChangeNotifier {
  List<String> _assignedDevices = [];
  
  void setAssignedDevices(List<String> devices) {
    _assignedDevices = devices;
    notifyListeners();
  }
  
  List<AhuUnit> get visibleAhuUnits {
    if (_assignedDevices.isEmpty || _currentRole == UserRole.admin) {
      return _ahuUnits.values.toList();
    }
    return _ahuUnits.values
        .where((unit) => _assignedDevices.contains(unit.id))
        .toList();
  }
}
```

**dashboard_screen.dart:**
```dart
Consumer<AppProvider>(
  builder: (context, provider, child) {
    final units = provider.visibleAhuUnits;  // FILTERED!
    
    if (units.isEmpty) {
      return Center(child: Text('No assigned devices'));
    }
    
    return ListView.builder(...);
  },
)
```

---

### Step 3: Test (10 minutes)

1. Run app
2. Sign in with Google
3. Hardcode yourself as admin: `_assignedDevices = []`
4. See all devices ✅
5. Hardcode as user: `_assignedDevices = ['ahu-01']`
6. See only ahu-01 ✅

---

## 📊 Example User Assignments

```dart
// Hardcoded assignments (replace with database later)
final USER_DEVICE_ASSIGNMENTS = {
  // Admins (see all devices)
  'admin@hospital.com': [],  // Empty = all devices
  'supervisor@hospital.com': [],
  
  // Doctors (specific ICUs)
  'dr.smith@hospital.com': ['ahu-01'],  // ICU-1 only
  'dr.jones@hospital.com': ['ahu-02', 'ahu-03'],  // ICU-2, ICU-3
  
  // Nurses (multiple ICUs)
  'nurse.alpha@hospital.com': ['ahu-01', 'ahu-02'],
  'nurse.beta@hospital.com': ['ahu-03', 'ahu-04'],
  
  // Managers (their department)
  'manager.hvac@hospital.com': ['ahu-01', 'ahu-02', 'ahu-03'],
};
```

---

## 🎯 Next Steps

**Immediate (This Week):**
1. Add Google Sign-In to Flutter app
2. Implement device filtering
3. Test with hardcoded assignments

**Short-term (Next Month):**
4. Create User Management UI
5. Save assignments to SharedPreferences
6. Add admin assignment flow

**Long-term (When Scaling):**
7. Set up backend API
8. Add database for user-device mappings
9. Add MQTT per-user credentials
10. Add audit logging

---

## 🔗 Resources

- **Google Sign-In Flutter**: https://pub.dev/packages/google_sign_in
- **HiveMQ ACL Guide**: https://www.hivemq.com/docs/hivemq/latest/
- **MQTT Security Best Practices**: https://www.hivemq.com/blog/mqtt-security-fundamentals/

---

**Last Updated**: December 2024  
**Status**: Ready to implement  
**Difficulty**: Medium (need Google OAuth setup)

