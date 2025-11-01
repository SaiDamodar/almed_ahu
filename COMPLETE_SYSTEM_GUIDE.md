# ALMED AHU System - Complete Implementation Guide

## Single Comprehensive Guide for Your Entire System

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Architecture (ESP → RPI → Cloud)](#architecture)
3. [Multi-Device Support](#multi-device)
4. [Cloud Setup (HiveMQ)](#cloud-setup)
5. [User Authentication Flow](#authentication)
6. [Admin Web Dashboard](#admin-dashboard)
7. [Mobile App](#mobile-app)
8. [Complete Data Flow](#data-flow)
9. [Implementation Checklist](#checklist)
10. [Cloud Infrastructure](#cloud-infrastructure)
11. [Database & Analytics](#database--analytics)

---

## 🎯 System Overview

### What You're Building

**Hospital AHU Control System** with:
- ESP32 sensors in multiple locations (ICU, ER, OR, etc.)
- Local Raspberry Pi for on-site control
- Cloud connectivity for remote access
- Multi-user authentication with device assignments
- Admin web dashboard for user management
- Mobile app for staff monitoring

### Key Features

✅ **ESP32 sensors** publish to both local RPI and cloud  
✅ **Auto-discovery** of new devices  
✅ **Multi-user support** with Google authentication  
✅ **Device assignments** managed by admins  
✅ **Real-time monitoring** via mobile app  
✅ **Secure access control** per user  

---

## 🏗️ Architecture

### Complete System Diagram (Normal Operation: PiSpot)

```
┌────────────────────────────────────────────────────────────────────────┐
│                    HOSPITAL LOCAL NETWORK (PiSpot)                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ESP32-AHU-01 (ICU-1)  ──┐                                            │
│  ESP32-AHU-02 (ICU-2)  ──┤                                            │
│  ESP32-AHU-03 (ICU-3)  ──┼─→ Raspberry Pi MQTT Broker (10.42.0.1:1883) │
│  ESP32-AHU-04 (ER-1)   ──┤    │                                         │
│  ESP32-AHU-05 (OR-1)   ──┤    ├─→ Desktop Kiosk (on-site control)       │
│  ...                     │    │                                         │
│                          │    └─→ Python Bridge Script (mqtt_bridge.py) │
│                          │         │                                     │
└──────────────────────────┼─────────┼─────────────────────────────────────┘
                           │         │
                           │         ↓
                           │    [Bridge Forwards All to Cloud]
                           │         │
                           │         ↓
┌──────────────────────────┼─────────┼─────────────────────────────────────┐
│                      CLOUD LAYER (HiveMQ Cloud)                        │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│         HiveMQ Cloud Broker (abc123.hivemq.cloud:8883)                 │
│                            │                                            │
│                            ├─→ Admin Web Dashboard                     │
│                            │   (User management, system monitoring)     │
│                            │                                            │
│                            └─→ Mobile App                              │
│                                (Staff control their assigned devices)  │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

**Key Points:**
- ESP32 only connects to **local Pi MQTT broker** when on PiSpot (10.42.0.x network)
- ESP32 **does NOT connect directly** to HiveMQ Cloud when on PiSpot
- Raspberry Pi bridge script (`mqtt_bridge.py`) forwards all messages to cloud
- Desktop dashboard continues working unchanged (connects to local Pi broker)

### Fallback Architecture (Hospital WiFi - When PiSpot Fails)

```
ESP32 → Hospital WiFi → HiveMQ Cloud DIRECT (8883 TLS)
                              ↓
                    Mobile App (works immediately)
```

**When used**: 
- PiSpot fails or ESP32 out of range
- ESP32 automatically detects it's NOT on PiSpot (IP not 10.42.0.x)
- ESP32 connects directly to HiveMQ Cloud
- Bridge script not needed (ESP32 handles cloud connection directly)

---

## 🔄 Multi-Device Support

### How Multiple ESP32s Work Together

**Your architecture supports 1 → 1000+ devices automatically!**

#### ESP32 Configuration

Each ESP32 has a **unique identifier**:
```cpp
// In esp32_main.ino, line 113
const char* AHU = "ahu-01";  // Change to "ahu-02", "ahu-03", etc.
```

**To add more devices**, just flash ESP32 with different `AHU` ID:
- ESP32 #1: `AHU = "ahu-01"`
- ESP32 #2: `AHU = "ahu-02"`
- ESP32 #3: `AHU = "ahu-03"`
- etc.

#### Automatic Topic Generation

```cpp
// Topic structure
almed/ahu/hospitalA/icu1/ahu-01/telemetry
almed/ahu/hospitalA/icu2/ahu-02/telemetry
almed/ahu/hospitalA/icu3/ahu-03/telemetry
```

#### Dashboard Auto-Discovery

```dart
// mqtt_service.dart
_client!.subscribe('almed/ahu/#', MqttQos.atLeastOnce);  // Catches ALL devices

// app_provider.dart - Auto-discovers new devices
void _ensureAhuRegistered(String topicData) {
  final ahuId = parts[0];  // "ahu-01", "ahu-02", etc.
  if (!_ahuUnits.containsKey(ahuId)) {
    addAhuUnit(newAhu);  // Creates automatically!
  }
}
```

**Result**: No cloud configuration needed! Flash ESP32 → See it in dashboard! ✅

---

## ☁️ Cloud Setup (HiveMQ)

### Why HiveMQ Over AWS IoT Core?

| Factor | HiveMQ Cloud | AWS IoT Core | Winner |
|--------|-------------|--------------|--------|
| Setup Time | 5 minutes | 30+ minutes | 🏆 **HiveMQ** |
| Free Tier | Unlimited devices | Limited | 🏆 **HiveMQ** |
| Implementation | Simple | Complex | 🏆 **HiveMQ** |
| Cost (100 devices) | FREE | $25-50/month | 🏆 **HiveMQ** |

**Verdict**: HiveMQ Cloud wins in all categories! ✅

### Quick Setup Steps

#### 1. Create HiveMQ Account (5 minutes)

1. Go to: **https://www.hivemq.com/mqtt-cloud-broker/**
2. Click **"Get Started for Free"**
3. Enter email and password
4. Verify email
5. **No credit card required!**

#### 2. Create Cluster (2 minutes)

1. Click **"Create Cluster"**
2. Choose **"Serverless"** (Free tier)
3. Configure:
   - Name: `almed-ahu-production`
   - Region: Choose closest (India: Mumbai, Europe: Frankfurt, USA: Virginia)
4. Wait 2-3 minutes

**Save your cluster URL**: `abc123def456.s2.eu.hivemq.cloud`

#### 3. Create Credentials (2 minutes)

1. Click **"Access Management"**
2. Click **"Add Credentials"**
3. Enter:
   - Username: `almed`
   - Password: `YourSecurePassword123!`
4. **Save password NOW** (you won't see it again!)

#### 4. Setup Raspberry Pi Bridge Script (Required for PiSpot)

The bridge script forwards all MQTT messages from local Pi broker to HiveMQ Cloud.

**4.1 Install Python MQTT Library:**

```bash
sudo pip3 install paho-mqtt
```

**4.2 Update Bridge Script Credentials:**

Edit `/home/almed/Documents/almed_ahu/mqtt_bridge.py`:

```python
# CLOUD BROKER (HiveMQ Cloud)
CLOUD_BROKER = "YOUR_CLUSTER_URL.s1.eu.hivemq.cloud"  # Your HiveMQ cluster URL
CLOUD_PORT = 8883
CLOUD_USER = "almed"
CLOUD_PASS = "YourSecurePassword123!"  # Your HiveMQ password
```

**4.3 Install Bridge as Systemd Service:**

```bash
# Copy service file
sudo cp /home/almed/Documents/almed_ahu/mqtt-bridge.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service (starts on boot)
sudo systemctl enable mqtt-bridge.service

# Start service
sudo systemctl start mqtt-bridge.service

# Check status
sudo systemctl status mqtt-bridge.service

# View logs
sudo journalctl -u mqtt-bridge -f
```

**4.4 Verify Bridge is Working:**

```bash
# Check bridge is forwarding
sudo journalctl -u mqtt-bridge | grep "Bridge ready"

# Expected output:
# ✓ Connected to LOCAL broker (Raspberry Pi)
# ✓ Connected to CLOUD broker (HiveMQ)
# Bridge ready: LOCAL → CLOUD forwarding active
```

---

## 👤 Authentication Flow

### Complete User Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                   USER AUTHENTICATION & ASSIGNMENT               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. NEW USER                                                      │
│     Opens Mobile App                                             │
│     Sees "Sign in with Google" button                           │
│     Clicks button                                                │
│           ↓                                                       │
│     Google OAuth popup                                           │
│     User authenticates (email: doctor@hospital.com)             │
│           ↓                                                       │
│     App shows: "Pending approval..."                            │
│           ↓                                                       │
│     NOTIFICATION SENT TO ADMIN                                   │
│                                                                  │
│  2. ADMIN REVIEWS                                                │
│     Admin opens web dashboard                                    │
│     Sees notification: "New user waiting approval"              │
│     Clicks: doctor@hospital.com                                 │
│     Sees user info (email, name, first login time)             │
│           ↓                                                       │
│     ADMIN ASSIGNS DEVICES                                        │
│     Clicks "Assign Devices"                                      │
│     Selects from list:                                           │
│       ☑️ ahu-01 (ICU-1)                                          │
│       ☑️ ahu-02 (ICU-2)                                          │
│       ☐ ahu-03 (ICU-3)                                           │
│     Clicks "Save"                                                │
│           ↓                                                       │
│     Assignment saved to database/SharedPreferences              │
│                                                                  │
│  3. USER CAN ACCESS                                              │
│     User refreshes mobile app                                    │
│     OR user logs in again                                        │
│           ↓                                                       │
│     App checks: assignedDevices = ['ahu-01', 'ahu-02']         │
│     Dashboard shows: ONLY assigned devices                      │
│     User can control: ONLY their devices                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Technical Implementation

#### Mobile App (User Side)

```dart
// 1. Google Sign-In
import 'package:google_sign_in/google_sign_in.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn();

ElevatedButton(
  onPressed: () async {
    final user = await _googleSignIn.signIn();
    if (user != null) {
      // Send user info to admin (via MQTT or API)
      await _notifyAdmin(user.email, user.displayName);
      
      // Wait for approval
      await _checkApprovalStatus(user.email);
    }
  },
  child: Text('Sign in with Google'),
)
```

#### Admin Web Dashboard

**User Management Screen:**

```dart
// Shows pending users
class UserManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Management')),
      body: Column(
        children: [
          // Pending approvals list
          PendingUsersList(),
          
          // Manage existing users
          ExistingUsersList(),
        ],
      ),
    );
  }
}

// Pending user card
class PendingUserCard extends StatelessWidget {
  final String email;
  final String name;
  final DateTime firstLogin;
  
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.person_add),
        title: Text(name),
        subtitle: Text(email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Approve button
            ElevatedButton(
              onPressed: () => _assignDevices(context, email),
              child: Text('Assign Devices'),
            ),
          ],
        ),
      ),
    );
  }
}

// Device assignment dialog
void _assignDevices(BuildContext context, String email) {
  showDialog(
    context: context,
    builder: (context) => DeviceAssignmentDialog(email: email),
  );
}
```

#### Device Assignment UI

```dart
class DeviceAssignmentDialog extends StatefulWidget {
  final String email;
  
  @override
  _DeviceAssignmentDialogState createState() => _DeviceAssignmentDialogState();
}

class _DeviceAssignmentDialogState extends State<DeviceAssignmentDialog> {
  final Set<String> _selectedDevices = {};
  
  @override
  Widget build(BuildContext context) {
    final allDevices = Provider.of<AppProvider>(context).ahuUnits;
    
    return AlertDialog(
      title: Text('Assign Devices to ${widget.email}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select devices this user can access:'),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: allDevices.length,
              itemBuilder: (context, index) {
                final device = allDevices[index];
                return CheckboxListTile(
                  title: Text(device.name),
                  subtitle: Text('${device.site}/${device.room}'),
                  value: _selectedDevices.contains(device.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked) {
                        _selectedDevices.add(device.id);
                      } else {
                        _selectedDevices.remove(device.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAssignment,
          child: Text('Save'),
        ),
      ],
    );
  }
  
  void _saveAssignment() async {
    // Save to SharedPreferences/database
    await SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList('user_devices_${widget.email}', _selectedDevices.toList());
    });
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Devices assigned successfully')),
    );
  }
}
```

#### Mobile App (Device Filtering)

```dart
// app_provider.dart
class AppProvider extends ChangeNotifier {
  String? _userEmail;
  List<String> _assignedDevices = [];
  
  Future<void> loadUserPermissions(String email) async {
    _userEmail = email;
    
    // Load from SharedPreferences/database
    final prefs = await SharedPreferences.getInstance();
    final devices = prefs.getStringList('user_devices_$email') ?? [];
    
    setAssignedDevices(devices);
  }
  
  void setAssignedDevices(List<String> devices) {
    _assignedDevices = devices;
    notifyListeners();
  }
  
  // Filter devices based on permissions
  List<AhuUnit> get visibleAhuUnits {
    // Empty list OR admin role = see all devices
    if (_assignedDevices.isEmpty || _currentRole == UserRole.admin) {
      return _ahuUnits.values.toList();
    }
    
    // Regular user = see only assigned devices
    return _ahuUnits.values
        .where((unit) => _assignedDevices.contains(unit.id))
        .toList();
  }
}
```

---

## 🌐 Admin Web Dashboard

### Purpose

**Centralized management system** for:
1. Approving new users
2. Assigning devices to users
3. Monitoring all AHU systems
4. System configuration

### Key Features

```
Admin Web Dashboard (Flutter Web or React/Vue)
├── User Management
│   ├── Pending Approvals
│   │   ├── New user signups
│   │   ├── Click "Assign Devices"
│   │   └── Save assignment
│   │
│   └── Existing Users
│       ├── View all users
│       ├── Edit device assignments
│       └── Remove users
│
├── System Monitoring
│   ├── All devices overview
│   ├── Real-time telemetry
│   ├── Alerts & notifications
│   └── System health
│
├── Device Configuration
│   ├── Motor timings
│   ├── Setpoints
│   ├── WiFi provisioning
│   └── Firmware updates
│
└── Reports & Analytics
    ├── Usage statistics
    ├── Error logs
    └── Performance metrics
```

### Implementation Options

#### Option 1: Flutter Web (Recommended)

**Same codebase as mobile app**, but for web:

```dart
// main_web.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALMED Admin Dashboard',
      theme: ThemeData.light(),
      home: AdminDashboardScreen(),
    );
  }
}

// Deploy to web
// flutter build web
// Host on any web server or Firebase Hosting
```

#### Option 2: Separate Web App (React/Vue)

**Separate codebase**, call same MQTT broker:

```javascript
// React/Vue Web App
import { MqttClient } from 'mqtt';

const mqttClient = mqtt.connect('ws://abc123.hivemq.cloud:8884', {
  username: 'almed',
  password: 'AlMed123456',
});

mqttClient.on('connect', () => {
  mqttClient.subscribe('almed/ahu/#');
});

mqttClient.on('message', (topic, message) => {
  // Handle telemetry data
  updateDashboard(JSON.parse(message));
});
```

---

## 📱 Mobile App

### Purpose

**Staff mobile app** for monitoring and controlling **their assigned devices only**.

### Key Features

```
Mobile App (Flutter Android/iOS)
├── Login Screen
│   └── "Sign in with Google" button
│
├── Dashboard (Filtered)
│   ├── Shows only assigned devices
│   ├── Real-time telemetry
│   └── Quick actions
│
├── Device Control Screen
│   ├── Start/Stop system
│   ├── Setpoints
│   ├── Motor control
│   └── Logs viewer
│
└── Profile
    ├── User info
    ├── Assigned devices list
    └── Logout
```

### User Experience

**First-Time User:**
1. Opens app
2. Sees "Sign in with Google"
3. Authenticates
4. Sees: "Account pending approval"
5. Waits for admin to assign devices

**Approved User:**
1. Opens app
2. Signs in with Google
3. Sees only **their assigned devices**
4. Can control their assigned devices
5. Cannot see other devices

---

## 🔄 Complete Data Flow

### Scenario 1: User Monitoring Their Device

```
User (doctor@hospital.com)
    │
    ├─→ Opens Mobile App
    ├─→ Signs in with Google
    ├─→ App loads permissions: assignedDevices = ['ahu-01']
    ├─→ Connects to HiveMQ Cloud
    ├─→ Subscribes to: almed/ahu/# (all topics)
    │
    └─→ App filters: Shows only ahu-01
        │
        ├─→ Display: ICU-1 AHU status
        ├─→ Real-time: Temperature, humidity
        └─→ Control: Start/stop, setpoints
    
ESP32-AHU-01 publishes telemetry
    │
    ├─→ Raspberry Pi MQTT (local)
    ├─→ Bridge Script → HiveMQ Cloud
    └─→ Mobile App receives data
        └─→ Dashboard updates (filtered view)
```

### Scenario 2: Admin Monitoring All Devices

```
Admin (admin@hospital.com)
    │
    ├─→ Opens Admin Web Dashboard
    ├─→ Signs in with Google
    ├─→ App loads permissions: assignedDevices = [] (all)
    ├─→ Connects to HiveMQ Cloud
    ├─→ Subscribes to: almed/ahu/# (all topics)
    │
    └─→ Dashboard shows ALL devices
        │
        ├─→ ESP32-AHU-01 (ICU-1)
        ├─→ ESP32-AHU-02 (ICU-2)
        ├─→ ESP32-AHU-03 (ICU-3)
        ├─→ ESP32-AHU-04 (ER-1)
        └─→ etc.
```

### Scenario 3: Admin Assigning Devices

```
Admin assigns devices to new user
    │
    ├─→ Opens "User Management" screen
    ├─→ Sees: doctor@hospital.com (pending)
    ├─→ Clicks "Assign Devices"
    ├─→ Selects: ahu-01, ahu-02
    ├─→ Clicks "Save"
    │
    └─→ Assignment saved to SharedPreferences/database
        │
        Key: 'user_devices_doctor@hospital.com'
        Value: ['ahu-01', 'ahu-02']

Next time doctor@hospital.com logs in:
    │
    ├─→ App loads permissions
    ├─→ Gets: assignedDevices = ['ahu-01', 'ahu-02']
    └─→ Dashboard shows only those 2 devices
```

### Scenario 4: User Controlling Device

```
User wants to start ICU-1 AHU
    │
    ├─→ Opens Mobile App
    ├─→ Clicks on "ICU-1 AHU" card
    ├─→ Sees device control screen
    ├─→ Clicks "Start" button
    │
    App publishes MQTT command:
    │
    mqtt.publish('almed/ahu/hospitalA/icu1/ahu-01/cmd', 
                 '{"start":true}')
    │
    ├─→ Cloud receives command
    ├─→ Bridge forwards to Raspberry Pi
    ├─→ Raspberry Pi forwards to ESP32
    │
    ESP32 receives command:
    │
    ├─→ Starts motor sequence
    ├─→ Begins temperature/humidity control
    ├─→ Publishes state update
    │
    State flows back:
    │
    ESP32 → RPI → Cloud → Mobile App
    │
    User sees: System started, motors running ✅
```

---

## ✅ Implementation Checklist

### Phase 1: Core Infrastructure (Week 1)

**Cloud Setup:**
- [ ] Create HiveMQ Cloud account
- [ ] Create cluster
- [ ] Add credentials
- [ ] Test connection from laptop

**ESP32 Setup:**
- [ ] Update esp32_main.ino with HiveMQ credentials
- [ ] Upload to ESP32
- [ ] Verify dual-broker connection
- [ ] Test telemetry publishing

**Bridge Script:**
- [ ] Create mqtt_bridge.py on Raspberry Pi
- [ ] Set up systemd service
- [ ] Test forwarding to cloud
- [ ] Verify auto-restart on boot

**Basic Dashboard:**
- [ ] Verify existing Flutter dashboard works
- [ ] Test multi-device auto-discovery
- [ ] Confirm all devices visible

**Deliverable**: ESP32 → RPI → Cloud working! ✅

---

### Phase 2: Authentication (Week 2)

**Mobile App:**
- [ ] Add google_sign_in package
- [ ] Replace login screen with Google Sign-In button
- [ ] Implement Google OAuth flow
- [ ] Add user info display

**Device Filtering:**
- [ ] Update app_provider.dart with device filtering
- [ ] Implement assignedDevices logic
- [ ] Test with hardcoded assignments
- [ ] Verify filtering works

**Permission Storage:**
- [ ] Set up SharedPreferences for assignments
- [ ] Create save/load functions
- [ ] Test persistence across app restarts

**Deliverable**: Google Auth + device filtering working! ✅

---

### Phase 3: Admin Dashboard (Week 3)

**Admin Web App:**
- [ ] Create admin dashboard (Flutter Web or React)
- [ ] Implement user management screen
- [ ] Show pending approvals
- [ ] Device assignment dialog

**Admin Features:**
- [ ] List all users
- [ ] Assign devices to users
- [ ] Edit assignments
- [ ] Remove users

**Testing:**
- [ ] Test admin login
- [ ] Test device assignment flow
- [ ] Verify assignments saved
- [ ] Test user sees filtered devices

**Deliverable**: Admin can assign devices to users! ✅

---

### Phase 4: Polish & Deploy (Week 4)

**Mobile App:**
- [ ] Add "Pending Approval" screen
- [ ] Add device assignment notification
- [ ] Polish UI/UX
- [ ] Test on Android/iOS devices

**Admin Dashboard:**
- [ ] Add analytics/statistics
- [ ] Add error logging
- [ ] Add system health monitoring
- [ ] Deploy to web server

**Documentation:**
- [ ] Create user manuals
- [ ] Document admin procedures
- [ ] Create troubleshooting guide

**Deploy:**
- [ ] Build mobile APK/IPA
- [ ] Deploy admin dashboard
- [ ] Install on test devices
- [ ] Full system testing

**Deliverable**: Complete system deployed! 🎉

---

## 🔐 Security Considerations

### Current Setup (Phase 1-2)

**Security Level**: Basic ✅

- ✅ TLS encryption (ESP32 → Cloud)
- ✅ TLS encryption (App → Cloud)
- ✅ Username/password authentication
- ⚠️ Shared MQTT credentials
- ⚠️ Device filtering in app only

**Suitable for**: Development, testing, small deployments

---

### Production Setup (Phase 3+)

**Security Level**: Enhanced 🔒

- ✅ TLS encryption
- ✅ Google OAuth
- ✅ Per-user device filtering
- ✅ Admin approval workflow
- ⚠️ Shared MQTT credentials

**Suitable for**: Hospital deployment, medium scale

---

### Enterprise Setup (Future)

**Security Level**: Maximum 🔐

- ✅ All above features
- ✅ Per-user MQTT credentials
- ✅ HiveMQ ACL rules
- ✅ Backend API with JWT tokens
- ✅ Audit logging
- ✅ Rate limiting

**Suitable for**: Large scale, multiple hospitals

---

## 📊 Testing Scenarios

### Test 1: Add New User

```
Steps:
1. Fresh user opens mobile app
2. Clicks "Sign in with Google"
3. Authenticates with email: test@hospital.com
4. Sees "Pending approval" screen
5. Admin sees notification in web dashboard
6. Admin assigns devices: ['ahu-01']
7. User refreshes app
8. Sees only ahu-01 device

Expected: ✅ User sees only assigned device
```

### Test 2: Admin Monitoring All Devices

```
Steps:
1. Admin opens web dashboard
2. Signs in with Google
3. Sees all devices (10+ AHU units)
4. Clicks on any device
5. Sees real-time telemetry
6. Can control any device

Expected: ✅ Admin has full access to all devices
```

### Test 3: Regular User Control

```
Steps:
1. Regular user opens mobile app
2. Signs in, sees 2 assigned devices
3. Clicks "Start" on device 1
4. Command sent to cloud
5. ESP32 receives command
6. System starts
7. User sees updated status

Expected: ✅ User can control their devices
```

### Test 4: User Cannot See Other Devices

```
Steps:
1. User A signs in, assigned to ['ahu-01']
2. User B signs in, assigned to ['ahu-02']
3. Verify User A cannot see ahu-02
4. Verify User B cannot see ahu-01

Expected: ✅ Users cannot see unassigned devices
```

---

## 🚀 Quick Start Commands

### ESP32 Code Update

```bash
cd esp32_main
# Edit esp32_main.ino
# Update line 106-108 with HiveMQ credentials
# Upload to ESP32
```

### Raspberry Pi Bridge Setup

```bash
# Install Python MQTT library
pip3 install paho-mqtt

# Create bridge script
nano /home/almed/mqtt_bridge.py

# Make executable
chmod +x /home/almed/mqtt_bridge.py

# Create systemd service
sudo nano /etc/systemd/system/mqtt-bridge.service

# Enable and start
sudo systemctl enable mqtt-bridge.service
sudo systemctl start mqtt-bridge.service
sudo systemctl status mqtt-bridge.service
```

### Mobile App Setup

```bash
cd ahu_dashboard

# Add Google Sign-In
flutter pub add google_sign_in shared_preferences

# Build for mobile
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Admin Web Dashboard Setup

```bash
# Flutter Web
cd ahu_dashboard
flutter build web
# Deploy to Firebase Hosting, Netlify, or your web server

# Or React/Vue separate app
npm install mqtt
npm run build
# Deploy to web server
```

---

## 📈 Scaling Guide

### Current Scale: 10-20 Devices

**Setup:**
- HiveMQ Cloud Free tier
- Shared MQTT credentials
- App-level device filtering

**Cost**: $0/month

---

### Medium Scale: 50-100 Devices

**Setup:**
- HiveMQ Cloud Free tier (10M messages/month)
- Shared MQTT credentials
- App-level device filtering
- Consider adding backend API

**Cost**: $0-200/month (depending on message volume)

---

### Large Scale: 500+ Devices

**Setup:**
- HiveMQ Cloud Paid tier
- Per-user MQTT credentials (optional)
- Backend API with database
- HiveMQ ACL rules

**Cost**: $200-500/month

---

## 🆘 Troubleshooting

### Issue: Users see "Pending Approval" forever

**Solution**: Check admin dashboard has notification, admin needs to assign devices.

---

### Issue: User cannot see any devices

**Solution**: 
1. Verify user was assigned devices in admin dashboard
2. Check assignedDevices not empty in app
3. Verify app is subscribed to `almed/ahu/#`

---

### Issue: User sees all devices (admin not working)

**Solution**:
1. Check user is in admin list: `adminEmails.contains(email)`
2. Verify `assignedDevices` is empty for admins
3. Check role check in filtering logic

---

### Issue: ESP32 not publishing to cloud

**Solution**:
1. Check WiFi connection
2. Verify HiveMQ credentials in ESP32 code
3. Check bridge script running on RPI
4. Test cloud connection from laptop with mosquitto_pub

---

## 🎯 Next Steps

**This Week:**
1. Read this entire guide
2. Set up HiveMQ Cloud
3. Update ESP32 code
4. Test basic connectivity

**Next Week:**
1. Add Google Sign-In to mobile app
2. Implement device filtering
3. Test user flow

**Following Weeks:**
1. Build admin web dashboard
2. Implement device assignment UI
3. Deploy to production

---

## ☁️ Cloud Infrastructure

### HiveMQ Cloud Setup

**Free Tier**: 10M messages/month, unlimited devices, TLS encrypted

**Connection Details:**
- Protocol: MQTT over TLS
- Port: 8883
- Broker: `your-cluster.hivemq.cloud:8883`
- Authentication: Username/password

**What It Provides:**
- Real-time message broker
- MQTT bridge between RPI and cloud
- Connectivity for mobile apps
- Scalable infrastructure

**Limitation**: No database storage (messages are transient)

---

## 🗄️ Database & Analytics

### Current Architecture: MQTT-Only

**What you have NOW:**
```
ESP32 → MQTT → App displays real-time data → Data discarded
```

**Limitations:**
- ❌ No historical data
- ❌ No trends or analytics
- ❌ Can't generate reports

**Suitable for**: Basic real-time monitoring

---

### Recommended: Add Time-Series Database

**Phase 2: InfluxDB (Recommended)** ⭐

**Best for**: Time-series sensor data

```
ESP32 → MQTT → InfluxDB → Flutter App queries history
```

**Why InfluxDB:**
- ✅ Perfect for sensor readings
- ✅ No backend API needed
- ✅ Fast time-range queries
- ✅ Free tier available
- ✅ Run on Raspberry Pi

**Setup:**
1. Install InfluxDB (cloud or RPI)
2. Configure MQTT → InfluxDB connector
3. Flutter queries historical data

**Cost**: FREE for <1GB data

**Alternative Options:**
- **Firebase Firestore**: Easiest, no server management (FREE tier generous)
- **PostgreSQL**: Full database for complex queries ($5-50/month)

---

### 📊 Graphs & Charts for Mobile App

**Current State**: `fl_chart` package already installed ✅

**What to Display:**

1. **Real-Time Gauges** (Current values)
   ```
   Temperature:  ╱────────╲  
                 │  24.5°C │
                 ╲────────╱
   
   Humidity:     ╱────────╲
                 │  62%    │
                 ╲────────╱
   ```

2. **Line Charts** (Historical trends)
   ```
   30°C ┤           ╱─╲
        │      ╱─╲╱   ╲
   20°C ┤  ╱─╲       
        └─────────────
        0h   12h  24h
   ```

3. **Motor Activity Timeline**
   ```
   M1: ████░░░░████░░░░
   M2: ░░░░████░░░░████
   CP:  ████░░░░████░░░░
   ```

**Flutter Implementation:**

```dart
import 'package:fl_chart/fl_chart.dart';

class TemperatureChart extends StatelessWidget {
  final List<double> temps;
  final double setpoint;
  
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: temps.asMap().entries
              .map((e) => FlSpot(e.key.toDouble(), e.value))
              .toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
          ),
          LineChartBarData(
            spots: temps.asMap().entries
              .map((e) => FlSpot(e.key.toDouble(), setpoint))
              .toList(),
            isCurved: false,
            color: Colors.grey,
            dotData: FlDotData(show: false),
            dashArray: [5, 5],
          ),
        ],
      ),
    );
  }
}
```

**Quick Start**: Add to `ahu_control_screen.dart` → Done! ✅

---

### 📊 Admin Dashboard Analytics

**What Admins See:**

1. **System Overview Dashboard**
   ```
   ┌──────────────────────────────────────────┐
   │ System Health                            │
   ├──────────────────────────────────────────┤
   │ Total Devices: 20                        │
   │ Online Now: 18 (90%)                     │
   │ Active Users: 12                         │
   │ Last 24h Alerts: 3                       │
   └──────────────────────────────────────────┘
   ```

2. **Multi-Device Comparison Chart**
   ```
   Average Temperature by Device (Last 7 Days)
   
   30°C ┤
   25°C ┤  ████ ICU-1
        ┤  ████████ ICU-2
   20°C ┤  ███ ICU-3
        └─────────────────
         Mon Tue Wed Thu Fri
   ```

3. **Statistical Reports**
   ```
   📈 Device Statistics - ICU-1 AHU
   ├─ Average Temp: 24.2°C
   ├─ Min/Max: 20.1°C / 27.8°C
   ├─ Time in Range: 94%
   ├─ Motor Starts: 128/day
   └─ System Availability: 99.8%
   ```

4. **Alerts & Warnings**
   ```
   ⚠️ Recent Alerts
   ├─ Over-temperature (ICU-2): 3 occurrences
   ├─ Motor failures: 0
   └─ Network disconnects: 2
   ```

---

## 🎯 Analytics Implementation Priority

### Phase 1: Now (Week 1)
**Storage**: None  
**Graphs**: In-memory only (last 100 readings)  
**Cost**: $0

**Quick Win**: Add basic line charts using `fl_chart` (already installed!)

---

### Phase 2: Month 1 (Week 2-4)
**Storage**: InfluxDB on Raspberry Pi  
**Graphs**: Full historical charts (24h, 7d, 30d views)  
**Cost**: $0

**Benefit**: Historical data analysis, trend identification

---

### Phase 3: Later (Month 2+)
**Storage**: Firebase Firestore (if scaling)  
**Graphs**: Advanced analytics, predictive insights  
**Cost**: $0-50/month

**Benefit**: Cloud backup, unlimited history, multi-location aggregation

---

## 📚 Reference Documents

- **Detailed HiveMQ Setup**: `HIVEMQ_SETUP_QUICK_START.md`
- **Network Architecture**: `NETWORK_ARCHITECTURE_GUIDE.md`
- **Database & Analytics**: `DATABASE_AND_ANALYTICS_GUIDE.md`
- **Quick DB Summary**: `CLOUD_DB_GRAPHS_SUMMARY.md`
- **Authentication Guide**: `USER_AUTHENTICATION_GUIDE.md`
- **HiveMQ vs AWS**: `HIVE_VS_AWS_COMPARISON.md`
- **Quick Answers**: `ANSWERS_SUMMARY.md`

---

## 🎉 Summary

**Your ALMED AHU system is designed to:**

✅ **Scale** from 1 to 1000+ devices automatically  
✅ **Support** multi-user authentication with Google  
✅ **Allow** admins to assign devices to users  
✅ **Provide** real-time monitoring via mobile app  
✅ **Enable** centralized management via admin dashboard  
✅ **Work** with smart failover (PiSpot → Hospital WiFi)  
✅ **Cost** zero dollars to start (HiveMQ free tier)  
✅ **Display** graphs and analytics for insights  
✅ **Store** historical data when needed  

**Everything is documented, architecture is ready, and implementation is straightforward!** 🚀

---

**Last Updated**: December 2024  
**Status**: Complete guide ready for implementation  
**Difficulty**: Medium (step-by-step guide provided)  
**Timeline**: 4 weeks to full production deployment

