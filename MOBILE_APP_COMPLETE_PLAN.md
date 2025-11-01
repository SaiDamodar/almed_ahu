# ALMED AHU Mobile App - Complete System Plan

## 📱 App Overview

**Mobile app for hospital staff to monitor and control AHU units remotely**
- Real-time monitoring from anywhere
- Receive alerts when issues occur
- Request maintenance via tickets
- View historical data and graphs
- OTA firmware updates for ESP32 devices

---

## 🏗️ System Architecture

```
Mobile App (Flutter)
       ↓
HiveMQ Cloud (MQTT)
       ↓
MQTT Bridge (Python)
       ↓
Raspberry Pi (Mosquitto)
       ↓
ESP32 (AHU Control Unit)
       ↓
Hardware (Sensors, Motors, Relays)

      ↓
InfluxDB Cloud (Historical Data)
Firebase (User Auth, Tickets, Notifications)
```

---

## 🔐 1. Authentication & User Management

### Firebase Authentication

**How it works:**
1. User opens app → Firebase login screen
2. Staff enters email/password → Firebase verifies
3. Firebase returns JWT token → App stores token locally
4. All API calls include JWT token → Firebase validates

**User Roles:**
- **Admin**: Full control (all units, provisioning, OTA updates)
- **Hospital Staff**: Monitor assigned units, raise tickets
- **Maintenance**: View all units, respond to tickets

**Device Assignment:**
- Admin assigns specific AHU units to each staff member
- Stored in Firebase Firestore:
  ```json
  {
    "userId": "user123",
    "assignedDevices": ["ahu-01", "ahu-02", "ahu-05"],
    "role": "hospital_staff"
  }
  ```

**Login Flow:**
```
App → Firebase Auth → Get Token → Store in App
                                ↓
                          Load user profile
                                ↓
                    Filter devices by assignment
                                ↓
                        Show dashboard
```

---

## 📊 2. Data Flow Architecture

### Real-time Monitoring Flow

**Path: ESP32 → RPI → Cloud → Mobile App**

```
ESP32 (sensors read temp/humidity)
   ↓ (publishes every 10 seconds)
Raspberry Pi Mosquitto MQTT Broker
   ↓
MQTT Bridge (Python script)
   ↓ (forwards all messages)
HiveMQ Cloud (secure TLS)
   ↓
Mobile App (subscribes to topics)
   ↓
Display on dashboard + store in local cache
```

**MQTT Topics:**
```
Telemetry:  almed/ahu/{site}/{room}/{device-id}/telemetry
State:      almed/ahu/{site}/{room}/{device-id}/state
Commands:   almed/ahu/{site}/{room}/{device-id}/cmd
Logs:       almed/ahu/{site}/{room}/{device-id}/log
Status:     almed/ahu/{site}/{room}/{device-id}/status
```

**Code Example (Flutter MQTT):**
```dart
mqttClient.subscribe('almed/ahu/+/+/+/telemetry', MqttQos.atLeastOnce);
mqttClient.updates!.listen((messages) {
  for (var message in messages) {
    String topic = message.topic;
    String payload = utf8.decode(message.payload);
    // Parse JSON and update UI
  }
});
```

---

### Historical Data Storage

**Path: Cloud → InfluxDB**

```
MQTT Bridge receives message from RPI
   ↓
Bridge forwards to HiveMQ Cloud
   ↓
Bridge also writes to InfluxDB Cloud
   ↓
InfluxDB stores time-series data
   ↓
Mobile app queries InfluxDB for graphs
```

**InfluxDB Schema:**
- **Measurement**: `ahu_sensors`
- **Tags**: `device_id`, `site`, `room`, `unit_type`
- **Fields**: `temperature`, `humidity`, `motor1_status`, `motor2_status`, `compressor`, `heater`
- **Timestamp**: auto-generated

**Flux Query Example:**
```python
# Get last 24 hours of temperature data
query = '''
from(bucket: "ahu_telemetry")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "ahu_sensors")
  |> filter(fn: (r) => r["device_id"] == "ahu-01")
  |> filter(fn: (r) => r["_field"] == "temperature")
  |> aggregateWindow(every: 1h, fn: mean)
'''
```

---

## 🎛️ 3. Control Commands Flow

### Mobile → ESP32 Control Path

**Path: Mobile App → Cloud → RPI → ESP32**

```
User taps "Start System" button
   ↓
App publishes JSON command to HiveMQ Cloud
   ↓
MQTT Bridge receives command from cloud
   ↓
Bridge forwards to Raspberry Pi Mosquitto
   ↓
ESP32 subscribed to command topic receives message
   ↓
ESP32 parses JSON and executes command
   ↓
ESP32 publishes confirmation back
   ↓
Mobile app receives confirmation and updates UI
```

**Command Format:**
```json
{
  "start": true,
  "timestamp": "2025-01-01T12:00:00Z"
}
```

**Available Commands:**
- `start` / `stop` - Control system on/off
- `setpoint` - Change temperature setpoint (e.g., `{"setpoint": 23.5}`)
- `humiditySetpoint` - Change humidity setpoint (e.g., `{"humiditySetpoint": 55}`)
- `motorTimings` - Adjust motor timings (admin only)
- `provision` - WiFi/network provisioning (admin only)

**Flow Diagram:**
```
Mobile App
  ├─→ Publish command to: almed/ahu/hospitalA/icu1/ahu-01/cmd
  │   Message: {"start": true}
  │
  ↓ Cloud MQTT Bridge
  │   ├─→ Forwards to RPI Mosquitto
  │   │
  │   ↓ ESP32 receives
  │   │   ├─→ Starts system
  │   │   └─→ Publishes state update
  │   │
  │   ↓ ESP32 publishes confirmation
  │       almed/ahu/hospitalA/icu1/ahu-01/state
  │       {"run": true, "cp": true, "heater": false, ...}
  │
  ↓ Mobile App receives state
      Updates UI with new status
```

---

## 📈 4. Graphs & Historical Data

### Data Visualization

**InfluxDB Query → Display Charts**

**Graph Types:**
1. **Temperature Timeline**: Last 24h / 7d / 30d
2. **Humidity Timeline**: Last 24h / 7d / 30d
3. **Motor Runtime**: Daily/weekly usage
4. **Compressor Cycles**: On/off cycles over time
5. **Energy Consumption**: Estimated based on runtime

**Flutter Chart Implementation:**
```dart
// Using fl_chart package
LineChart(
  data: LineChartData(
    gridData: FlGridData(show: true),
    titlesData: FlTitlesData(show: true),
    lineBarsData: [
      LineChartBarData(
        spots: dataPoints.map((dp) => 
          FlSpot(dp.timestamp, dp.temperature)).toList(),
        isCurved: true,
        dotData: FlDotData(show: false),
      ),
    ],
  ),
)
```

**Data Retrieval:**
```python
# Mobile app calls backend API
GET /api/data/historical?device=ahu-01&metric=temperature&duration=24h

# Backend queries InfluxDB
result = query_api.query(query)

# Returns JSON array
[
  {"timestamp": "2025-01-01T12:00:00Z", "value": 24.5},
  {"timestamp": "2025-01-01T13:00:00Z", "value": 24.7},
  ...
]

# Mobile app displays in chart
```

---

## 🔔 5. Notifications System

### Push Notifications Architecture

**Firebase Cloud Messaging (FCM) Integration**

**Alert Conditions:**
1. **Temperature Out of Range**: >27°C or <18°C
2. **Humidity Out of Range**: >70% or <40%
3. **System Failure**: ESP32 watchdog reset, sensor failure
4. **Maintenance Due**: Device needs service
5. **Ticket Updates**: New response to your ticket

**Backend Notification Service:**
```python
# MQTT Bridge monitors all telemetry
def on_message_received(msg):
    data = json.loads(msg.payload)
    
    # Check for alerts
    if data['temperature'] > 27.0:
        send_push_notification(
            user_id=user_id,
            title="High Temperature Alert",
            message=f"Device {device_id} temperature is {data['temperature']}°C",
            data={"device_id": device_id, "type": "temperature_high"}
        )
```

**Mobile App FCM Setup:**
```dart
// Firebase Messaging
FirebaseMessaging messaging = FirebaseMessaging.instance;

// Request permission
await messaging.requestPermission();

// Get FCM token
String? token = await messaging.getToken();
// Send token to backend to associate with user

// Listen for notifications
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Notification: ${message.notification?.title}');
  // Update badge, show snackbar, navigate to device detail
});
```

**Notification Delivery Flow:**
```
ESP32 detects high temperature → Publishes telemetry
   ↓
MQTT Bridge receives data
   ↓
Bridge checks thresholds → Triggers alert
   ↓
Backend queries Firebase for assigned users
   ↓
Backend sends push via FCM
   ↓
Firebase delivers to user's device
   ↓
Mobile app displays notification
   ↓
User taps notification → Opens device detail screen
```

---

## 🎫 6. Ticket Management System

### Issue Reporting & Maintenance Requests

**Ticket Creation Flow:**

```
Staff notices issue (e.g., "Device making noise")
   ↓
Opens app → Device detail screen
   ↓
Taps "Report Issue" button
   ↓
Ticket form appears:
   - Device ID (auto-filled)
   - Category (Hardware/Software/Other)
   - Description (text + photo optional)
   - Priority (Low/Medium/High/Critical)
   ↓
Submit ticket → Stored in Firebase Firestore
   ↓
Notification sent to admin/maintenance team
   ↓
Ticket appears in admin dashboard
```

**Ticket Data Structure (Firestore):**
```json
{
  "ticket_id": "TKT-2025-001",
  "device_id": "ahu-01",
  "site": "hospitalA",
  "room": "icu1",
  "created_by": "user123",
  "created_at": "2025-01-01T12:00:00Z",
  "category": "Hardware",
  "priority": "High",
  "description": "Device making loud noise",
  "status": "Open",
  "assigned_to": "maintenance_team_1",
  "attachments": ["photo_url_1.jpg"],
  "responses": [
    {
      "from": "maintenance_team_1",
      "message": "Scheduled maintenance for 2 PM today",
      "timestamp": "2025-01-01T12:30:00Z"
    }
  ]
}
```

**Ticket States:**
- **Open**: Just created
- **Assigned**: Maintenance team assigned
- **In Progress**: Being worked on
- **Resolved**: Issue fixed
- **Closed**: Verified and closed

**Mobile App Ticket Features:**
- View all tickets (filtered by status, device, date)
- Create new ticket with photo attachment
- Reply to ticket messages
- Receive push notifications for responses
- View ticket history for device

---

## 🔄 7. OTA Firmware Updates

### Over-the-Air ESP32 Updates

**Architecture:**

```
Admin uploads new firmware to backend
   ↓
Backend generates signed binary + metadata
   ↓
Metadata published to MQTT topic
   ↓
ESP32 subscribes to firmware topic
   ↓
ESP32 downloads firmware via HTTPS
   ↓
ESP32 verifies signature
   ↓
ESP32 installs update + reboots
   ↓
ESP32 reports update status
   ↓
Mobile app shows update progress/status
```

**OTA Update Flow:**

**Step 1: Admin Initiates Update**
```dart
// Admin screens uploads firmware file
FirebaseStorage.upload(file, path: 'firmware/ahu_v2.0.bin');

// Backend creates update metadata
{
  "version": "2.0.0",
  "file_url": "https://storage.googleapis.com/...",
  "file_size": 1258291,
  "checksum": "abc123...",
  "target_devices": ["ahu-01", "ahu-02"],
  "rollout_percentage": 50,  // Deploy to 50% first
  "force_update": false
}
```

**Step 2: Publish Update to ESP32**
```python
# Backend publishes to MQTT
mqtt_client.publish(
    "almed/ahu/+/+/+/firmware/update",
    json.dumps({
        "version": "2.0.0",
        "url": "https://storage.googleapis.com/...",
        "checksum": "abc123...",
        "size": 1258291
    })
)
```

**Step 3: ESP32 Downloads & Installs**
```cpp
// ESP32 listens for updates
client.onMessage = [](String topic, String payload) {
    if (topic.endsWith("/firmware/update")) {
        DynamicJsonDocument doc(1024);
        deserializeJson(doc, payload);
        
        String url = doc["url"];
        String version = doc["version"];
        
        // Start OTA update
        httpUpdate.setLedPin(LED_BUILTIN, LOW);
        t_httpUpdate_return ret = httpUpdate.update(client, url);
        
        switch(ret) {
            case HTTP_UPDATE_FAILED:
                publishStatus("update_failed");
                break;
            case HTTP_UPDATE_OK:
                publishStatus("update_success");
                ESP.restart();
                break;
        }
    }
};
```

**Step 4: Mobile App Shows Progress**
```dart
// App subscribes to firmware status
mqttClient.subscribe('almed/ahu/+/+/+/firmware/status');

// Receive progress updates
{
  "device_id": "ahu-01",
  "status": "downloading",
  "progress": 45,  // percentage
  "version": "2.0.0"
}

// UI updates
LinearProgressIndicator(value: 0.45),
Text('Downloading firmware 2.0.0... 45%'),
```

**Update Strategies:**
- **Staged Rollout**: Deploy to 10% → 50% → 100% of devices
- **Schedule Updates**: Schedule for off-peak hours
- **Rollback**: Automatic rollback if update fails on >5% of devices
- **Test Group**: Test on specific devices first

---

## 🗄️ 8. Backend Services

### Required Backend APIs

**1. User Management API**
```
POST /api/auth/login          → Firebase JWT
GET  /api/user/profile        → User info, assigned devices
PUT  /api/user/profile        → Update user settings
GET  /api/users               → List users (admin)
```

**2. Device Management API**
```
GET  /api/devices             → List all devices (filtered by user)
GET  /api/devices/:id         → Device details
GET  /api/devices/:id/history → Historical data (InfluxDB)
POST /api/devices/:id/command → Send MQTT command
GET  /api/devices/:id/status  → Current status
```

**3. Analytics API**
```
GET  /api/analytics/overview  → Dashboard summary
GET  /api/analytics/trends    → Temperature/humidity trends
GET  /api/analytics/energy    → Estimated energy usage
GET  /api/analytics/health    → Device health scores
```

**4. Tickets API**
```
GET    /api/tickets           → List tickets (filtered)
POST   /api/tickets           → Create ticket
GET    /api/tickets/:id       → Ticket details
POST   /api/tickets/:id/reply → Reply to ticket
PUT    /api/tickets/:id       → Update status
DELETE /api/tickets/:id       → Close ticket (admin)
```

**5. Firmware API**
```
GET    /api/firmware          → List available versions
POST   /api/firmware          → Upload new version (admin)
POST   /api/firmware/deploy   → Deploy to devices (admin)
GET    /api/firmware/status   → Update status per device
```

**6. Notifications API**
```
POST /api/notifications/push  → Send manual notification
GET  /api/notifications       → List notification history
PUT  /api/notifications/:id   → Mark as read
```

---

## 🔧 9. Backend Implementation

### Technology Stack

**Option A: Python (Recommended)**
```python
# Flask/FastAPI backend
- FastAPI for REST APIs
- paho-mqtt for MQTT bridge
- influxdb-client for time-series data
- firebase-admin for auth & Firestore
- Firebase Cloud Messaging for push notifications
```

**Option B: Node.js**
```javascript
// Express.js backend
- Express for REST APIs
- mqtt.js for MQTT bridge
- @influxdata/influxdb-client for time-series
- firebase-admin for auth & Firestore
- Firebase Cloud Messaging for push
```

**Core Services:**

**1. MQTT Bridge Service**
```python
# Already exists: mqtt_bridge.py
# Forwards messages between RPI and HiveMQ Cloud
# Also writes to InfluxDB

local_client.subscribe("almed/#")
# → Forwards to cloud
# → Writes to InfluxDB
```

**2. Alert Service**
```python
def check_alerts(device_id, telemetry):
    thresholds = get_thresholds(device_id)
    
    if telemetry['temperature'] > thresholds['temp_max']:
        send_alert(device_id, 'temperature_high', telemetry['temperature'])
    if telemetry['humidity'] > thresholds['humidity_max']:
        send_alert(device_id, 'humidity_high', telemetry['humidity'])
```

**3. Notification Service**
```python
def send_notification(user_id, title, message, data):
    # Get user's FCM token from Firestore
    token = get_user_fcm_token(user_id)
    
    # Send via Firebase
    response = messaging.send({
        "token": token,
        "notification": {"title": title, "body": message},
        "data": data
    })
```

**4. API Gateway**
```python
@app.get("/api/devices")
async def list_devices(current_user: User):
    # Check Firebase auth
    verify_token(current_user.token)
    
    # Get user's assigned devices
    devices = get_assigned_devices(current_user.user_id)
    
    # Return filtered list
    return {"devices": devices}
```

---

## 📱 10. Mobile App Architecture (Flutter)

### App Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── user.dart
│   ├── device.dart
│   ├── telemetry.dart
│   ├── ticket.dart
│   └── notification.dart
├── services/
│   ├── auth_service.dart        # Firebase Auth
│   ├── mqtt_service.dart        # HiveMQ Cloud
│   ├── api_service.dart         # Backend REST
│   ├── influx_service.dart      # InfluxDB queries
│   └── notification_service.dart # FCM
├── screens/
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── device_detail_screen.dart
│   ├── graphs_screen.dart
│   ├── tickets_screen.dart
│   └── admin_screen.dart
├── widgets/
│   ├── device_card.dart
│   ├── sensor_display.dart
│   ├── chart_widget.dart
│   └── ticket_card.dart
└── providers/
    ├── auth_provider.dart
    ├── device_provider.dart
    └── ticket_provider.dart
```

### Key Features Implementation

**1. Dashboard Screen**
```dart
- Grid of assigned AHU devices
- Real-time status indicators
- Tap device to open detail screen
- Pull to refresh
- Quick actions (Start/Stop)
```

**2. Device Detail Screen**
```dart
- Current sensor readings (large display)
- Historical graphs (temp/humidity over time)
- Control buttons (setpoint, start/stop)
- Motor status indicators
- Recent logs
- Report issue button
```

**3. Graphs Screen**
```dart
- Line charts for temperature/humidity
- Bar charts for motor runtime
- Time range selector (24h/7d/30d)
- Multiple device overlay
- Export data as CSV
```

**4. Tickets Screen**
```dart
- List of all tickets (user's tickets)
- Filter by status/device/date
- Create new ticket
- View ticket thread
- Upload photos
- Push notification for responses
```

**5. Admin Screen**
```dart
- User management
- Device management
- OTA firmware deployment
- Analytics dashboard
- System health overview
```

---

## 🔐 11. Security Architecture

### Multi-Layer Security

**1. Authentication**
- Firebase JWT tokens
- Token refresh every 24 hours
- Biometric login (fingerprint/face)

**2. Authorization**
- Role-based access control
- Device assignment restrictions
- API endpoints check permissions

**3. Data Encryption**
- TLS 1.3 for MQTT (HiveMQ Cloud)
- HTTPS for all REST APIs
- Encrypted local storage for tokens

**4. Device Security**
- ESP32 firmware signatures
- MQTT client certificates (optional)
- Rate limiting on commands

**5. Network Security**
- VPN option for hospital networks
- Firewall rules on RPI
- Denial of service protection

---

## 🚀 12. Deployment Architecture

### Production Setup

**Backend Services (Cloud)**
```
Google Cloud / AWS
├── Backend API (Cloud Run / ECS)
├── MQTT Bridge (Cloud Functions / Lambda)
├── Alert Service (Cloud Functions / Lambda)
└── Notification Service (Firebase Cloud Messaging)
```

**Databases**
```
InfluxDB Cloud  → Time-series sensor data
Firebase Firestore → Users, tickets, device metadata
Firebase Auth → User authentication
```

**MQTT Broker**
```
HiveMQ Cloud → Production MQTT broker
```

**Mobile App**
```
Flutter app → Android/iOS builds
           → Published to Google Play / App Store
           → Push via FCM
```

---

## 📊 13. Data Flow Examples

### Example 1: Staff Monitors Device

```
1. Staff opens app → Login via Firebase
2. App loads assigned devices from Firestore
3. App connects to HiveMQ Cloud via MQTT
4. App subscribes to: almed/ahu/+/+/+/telemetry
5. ESP32 publishes every 10 seconds
6. App receives data → Updates UI in real-time
7. Data also written to InfluxDB by bridge
8. App queries InfluxDB for historical graphs
```

### Example 2: Staff Raises Ticket

```
1. Staff notices issue on device detail screen
2. Taps "Report Issue" button
3. Fills form: Device, Category, Description, Photo
4. App calls POST /api/tickets
5. Backend stores in Firestore
6. Backend sends push notification to admin
7. Admin sees ticket in dashboard
8. Admin assigns to maintenance team
9. Maintenance team responds
10. Staff receives push notification
11. App updates ticket thread
```

### Example 3: Admin Deploys OTA Update

```
1. Admin uploads firmware via admin screen
2. Firmware stored in Firebase Storage
3. Admin selects target devices
4. Admin clicks "Deploy" button
5. Backend publishes to MQTT: almed/ahu/+/+/+/firmware/update
6. ESP32 devices receive update notification
7. ESP32 downloads firmware via HTTPS
8. ESP32 verifies checksum
9. ESP32 installs update + reboots
10. ESP32 publishes status: "update_success"
11. Mobile app shows update progress
12. Admin sees deployment status in dashboard
```

### Example 4: Temperature Alert

```
1. ESP32 reads temperature: 28°C
2. ESP32 publishes telemetry to RPI MQTT
3. Bridge receives data → Forwards to cloud
4. Bridge also writes to InfluxDB
5. Alert service checks threshold (max: 27°C)
6. Alert service triggers notification
7. Backend queries Firestore for assigned users
8. Backend sends FCM push to users
9. Staff receives notification on mobile
10. Staff taps notification → Opens device detail
11. Staff sees high temperature alert
12. Staff can raise ticket if needed
```

---

## 🧪 14. Testing Strategy

### Mobile App Testing

**Unit Tests**
- Authentication service
- MQTT message parsing
- Data model validation
- Chart data processing

**Integration Tests**
- MQTT connection/disconnection
- API calls to backend
- Firebase Auth flows
- Push notification handling

**UI Tests**
- Widget rendering
- Navigation flows
- User interactions
- Error states

**End-to-End Tests**
- Complete user journeys
- Real device testing
- Network conditions
- Battery impact

---

## 📱 15. Mobile App Features Checklist

### Core Features ✅
- [x] Firebase authentication (email/password + Google)
- [x] Device list dashboard
- [x] Real-time sensor readings
- [x] Control commands (start/stop, setpoints)
- [x] Historical graphs (temp/humidity)
- [x] Push notifications
- [x] Ticket creation and management
- [x] Device detail screen
- [x] User profile and settings
- [x] OTA update deployment (admin)

### Admin Features ✅
- [x] User management
- [x] Device provisioning
- [x] Firmware deployment
- [x] System analytics
- [x] Alert configuration
- [x] Ticket assignment

### Advanced Features 🚀
- [ ] Offline mode (cache last data)
- [ ] Data export (CSV/PDF)
- [ ] Multi-language support
- [ ] Dark mode
- [ ] Widgets for home screen
- [ ] Voice commands
- [ ] AI-powered alerts

---

## 🎯 16. Implementation Priority

### Phase 1: MVP (Weeks 1-2)
1. Firebase Auth setup
2. Basic MQTT connection
3. Device list and detail screens
4. Real-time telemetry display
5. Basic control commands

### Phase 2: Core Features (Weeks 3-4)
1. Historical graphs
2. Push notifications
3. Ticket system
4. Device assignment
5. Admin features

### Phase 3: Advanced (Weeks 5-6)
1. OTA updates
2. Advanced analytics
3. Offline mode
4. Data export
5. Performance optimization

### Phase 4: Polish (Weeks 7-8)
1. UI/UX improvements
2. Comprehensive testing
3. Documentation
4. App store submission
5. Production deployment

---

## 📋 17. Technical Specifications

### Mobile App Requirements
- **Platform**: Flutter (iOS + Android)
- **Min iOS**: 13.0
- **Min Android**: API 21 (Android 5.0)
- **Architecture**: Provider state management
- **Charts**: fl_chart package
- **Networking**: dio for REST, mqtt_client for MQTT
- **Storage**: shared_preferences, sqflite
- **Push**: firebase_messaging

### Backend Requirements
- **Language**: Python 3.9+
- **Framework**: FastAPI
- **MQTT**: paho-mqtt
- **Database**: InfluxDB, Firebase Firestore
- **Hosting**: Google Cloud Run or AWS Lambda
- **Container**: Docker

### Infrastructure Requirements
- **HiveMQ Cloud**: Minimum 10 connections
- **InfluxDB Cloud**: Starter plan (sufficient for initial deployment)
- **Firebase**: Blaze plan (pay as you go)
- **Storage**: 100GB+ for firmware and logs

---

## 🎉 Summary

**Complete System Flow:**

```
User → Mobile App → Firebase Auth → HiveMQ Cloud
                                              ↓
                                  MQTT Bridge → Raspberry Pi → ESP32
                                              ↓
                                        InfluxDB (graphs)
                                              ↓
Firebase Firestore (users, tickets) → Push Notifications → User
```

**Key Technologies:**
- **Authentication**: Firebase Auth
- **Real-time**: HiveMQ Cloud MQTT
- **Database**: InfluxDB (time-series) + Firestore (users/tickets)
- **Backend**: Python FastAPI
- **Mobile**: Flutter
- **Notifications**: Firebase Cloud Messaging
- **Firmware**: OTA via MQTT + HTTPS

**Everything is integrated and ready to build!** 🚀

