# ALMED AHU Admin Web Dashboard - Complete System Plan

## 🌐 Dashboard Overview

**Comprehensive web admin panel for complete system management**
- User management and device assignments
- Real-time monitoring and control
- Ticket management and support
- OTA deployment (ESP32, RPI, Mobile)
- Analytics and reporting
- System health monitoring
- Notification management
- Configuration and provisioning

---

## 🏗️ System Architecture

```
Admin Web Dashboard (React/Vue)
       ↓
Backend API (FastAPI/Express)
       ↓
Databases:
  ├─ InfluxDB (analytics)
  ├─ Firebase (users, tickets, configs)
  └─ PostgreSQL (optional, advanced analytics)
       ↓
External Services:
  ├─ HiveMQ Cloud (MQTT)
  ├─ Firebase Auth (authentication)
  ├─ Firebase Storage (firmware)
  └─ Email Service (notifications)
```

---

## 🎨 Dashboard Sections

### 1. **Overview Dashboard**
- System health summary
- Active devices count
- Open tickets count
- Alert summary
- Key metrics charts
- Recent activity feed

### 2. **User Management**
- User CRUD operations
- Role assignment
- Device assignment
- Activity logs
- Permission management

### 3. **Device Management**
- Device registry
- Real-time monitoring
- Remote control
- Configuration management
- Provisioning tools

### 4. **Ticket Management**
- Ticket system
- Assignment workflow
- Response tracking
- SLA monitoring
- Resolution analytics

### 5. **Analytics & Reports**
- Historical data analysis
- Energy consumption reports
- Device health scores
- Performance metrics
- Custom report builder

### 6. **OTA Deployment**
- Firmware management
- Staged rollouts
- Update tracking
- Rollback capabilities

### 7. **Notifications**
- Alert configuration
- Push notification sender
- Email templates
- Notification history

### 8. **System Settings**
- Global configuration
- Threshold management
- Network settings
- Integration settings

---

## 👥 1. User Management Module

### User CRUD Interface

**Create User:**
```javascript
POST /api/admin/users
{
  "email": "staff@hospital.com",
  "name": "John Doe",
  "role": "hospital_staff",
  "phone": "+1234567890",
  "organization": "Hospital A"
}
```

**Update User:**
```javascript
PUT /api/admin/users/:userId
{
  "name": "Jane Doe",
  "phone": "+9876543210",
  "status": "active"
}
```

**List Users:**
```javascript
GET /api/admin/users?role=hospital_staff&status=active
```

**User Data Model:**
```json
{
  "userId": "user_abc123",
  "email": "staff@hospital.com",
  "name": "John Doe",
  "role": "hospital_staff",
  "status": "active",
  "assignedDevices": ["ahu-01", "ahu-02"],
  "permissions": ["view_devices", "raise_tickets"],
  "createdAt": "2025-01-01T00:00:00Z",
  "lastLogin": "2025-01-15T10:30:00Z",
  "metadata": {
    "organization": "Hospital A",
    "department": "ICU",
    "phone": "+1234567890"
  }
}
```

### Role Management

**Roles:**
- **Super Admin**: Full system access
- **Admin**: User management, device control, reports
- **Hospital Staff**: View assigned devices, raise tickets
- **Maintenance**: All devices, respond to tickets
- **Viewer**: Read-only access

**Permissions:**
```json
{
  "super_admin": ["*"],
  "admin": [
    "users.*",
    "devices.*",
    "tickets.*",
    "reports.*",
    "ota.deploy",
    "notifications.send"
  ],
  "hospital_staff": [
    "devices.read.assigned",
    "devices.control.assigned",
    "tickets.create",
    "tickets.read.own"
  ],
  "maintenance": [
    "devices.read.*",
    "devices.control.*",
    "tickets.read.*",
    "tickets.update.status"
  ],
  "viewer": ["devices.read.*", "reports.read.*"]
}
```

### Device Assignment Interface

**Bulk Assignment:**
```
Select Devices: [ahu-01] [ahu-02] [ahu-05] [ahu-07]
Assign To: [Staff Dropdown ▼]
Priority: [High/Medium/Low]
Notes: [Enter assignment reason]

[Assign] [Cancel]
```

**Assignment Logic:**
```python
def assign_devices(user_id, device_ids, priority="medium"):
    for device_id in device_ids:
        assignment = {
            "userId": user_id,
            "deviceId": device_id,
            "assignedAt": datetime.utcnow(),
            "priority": priority,
            "status": "active"
        }
        firestore.collection('assignments').add(assignment)
        
        # Update device metadata
        firestore.collection('devices').document(device_id).update({
            'assignedTo': user_id,
            'assignedAt': datetime.utcnow()
        })
        
        # Send notification
        send_notification(user_id, "devices_assigned", {
            "devices": device_ids,
            "count": len(device_ids)
        })
```

**Assignment History:**
- Track all assignments
- View assignment timeline
- Audit trail
- Export to CSV

---

## 🖥️ 2. Device Management Module

### Device Registry

**Device List View:**
```
| Device ID | Site | Room | Status | Last Seen | Assigned To | Actions |
|-----------|------|------|--------|-----------|-------------|---------|
| ahu-01    | HA   | ICU1 | Online | 2m ago    | John Doe    | [View] [Control] |
| ahu-02    | HA   | ICU2 | Offline| 1h ago    | Jane Doe    | [View] [Control] |
```

**Device Details Page:**
- Current sensor readings
- Configuration settings
- Historical graphs
- Command log
- Error history
- Provisioning info

**Device Data Model:**
```json
{
  "deviceId": "ahu-01",
  "site": "Hospital A",
  "room": "ICU1",
  "type": "AHU",
  "status": "online",
  "lastSeen": "2025-01-15T10:30:00Z",
  "assignedTo": "user_123",
  "currentState": {
    "temperature": 24.5,
    "humidity": 60,
    "setpointTemp": 22.0,
    "setpointHumidity": 55,
    "systemRunning": true,
    "motor1": false,
    "motor2": false,
    "compressor": true,
    "heater": false,
    "fanOn": true,
    "fanSpeed": 1
  },
  "configuration": {
    "motorTimings": {
      "m1_start": 10,
      "m1_post": 10,
      "m2_interval": 30,
      "m2_run": 10
    },
    "thresholds": {
      "temp_min": 18,
      "temp_max": 27,
      "humidity_min": 40,
      "humidity_max": 70
    }
  },
  "metadata": {
    "firmware": "2.0.0",
    "installDate": "2024-12-01",
    "location": "Ground Floor",
    "manufacturer": "ALMED"
  }
}
```

### Real-time Monitoring

**Live Dashboard:**
```javascript
// WebSocket connection for real-time updates
const ws = new WebSocket('wss://api.almed.com/ws/devices');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  
  if (data.type === 'telemetry') {
    updateDeviceReading(data.deviceId, data);
    updateChart(data.deviceId, data);
  }
  
  if (data.type === 'alert') {
    showAlertNotification(data);
    logAlert(data);
  }
};
```

**Multi-device Monitoring:**
- Grid view of all devices
- Map view (if locations available)
- Filter by site, room, status
- Search functionality
- Custom grouping

### Remote Control Interface

**Control Panel:**
```html
<div class="device-control">
  <h3>Device Control: ahu-01</h3>
  
  <!-- System Controls -->
  <button onclick="sendCommand('ahu-01', {start: true})">Start System</button>
  <button onclick="sendCommand('ahu-01', {stop: true})">Stop System</button>
  
  <!-- Setpoint Controls -->
  <div>
    Temperature: <input type="range" min="18" max="30" value="22" 
                       onchange="updateSetpoint('ahu-01', 'temp', this.value)">
    <span>22.0°C</span>
  </div>
  
  <div>
    Humidity: <input type="range" min="40" max="70" value="55"
                     onchange="updateSetpoint('ahu-01', 'humidity', this.value)">
    <span>55%</span>
  </div>
  
  <!-- Fan Speed Controls -->
  <div>
    Fan Speed: 
    <button onclick="sendCommand('ahu-01', {fanToggle: true})">Toggle Speed</button>
    <select onchange="sendCommand('ahu-01', {fanSpeed: parseInt(this.value)})">
      <option value="0">OFF</option>
      <option value="1">LOW (5V)</option>
      <option value="2">MID (9V)</option>
      <option value="3">HIGH (12V)</option>
    </select>
  </div>
  
  <!-- Motor Timing Controls (Admin Only) -->
  <div class="admin-only">
    <label>M1 Start Time (s):</label>
    <input type="number" value="10" id="m1_start">
    <button onclick="updateMotorTimings('ahu-01')">Update Timings</button>
  </div>
</div>
```

**Command Execution:**
```python
async def send_device_command(device_id: str, command: dict):
    # Verify admin permission
    if not verify_permission(current_user, 'devices.control.*'):
        raise PermissionError("Not authorized to control devices")
    
    # Publish to MQTT
    topic = f"almed/ahu/+/+/{device_id}/cmd"
    mqtt_client.publish(topic, json.dumps({
        **command,
        "timestamp": datetime.utcnow().isoformat(),
        "sent_by": current_user.user_id
    }))
    
    # Log command
    log_command(device_id, current_user.user_id, command)
    
    # Return success
    return {"status": "sent", "command": command}
```

---

## 🎫 3. Ticket Management Module

### Ticket Dashboard

**Ticket List:**
```
| ID      | Device  | Category | Priority | Status   | Created | Assigned | Actions     |
|---------|---------|----------|----------|----------|---------|----------|-------------|
| TKT-001 | ahu-01  | Hardware | High     | Open     | 1h ago  | -        | [View][Assign] |
| TKT-002 | ahu-05  | Software | Medium   | In Progress | 3h ago | John D.  | [View]      |
```

**Filters:**
- Status: Open, Assigned, In Progress, Resolved, Closed
- Priority: Critical, High, Medium, Low
- Category: Hardware, Software, General
- Date range
- Assigned to
- Site/Room

### Ticket Detail View

**Ticket Thread:**
```
═══════════════════════════════════════════════════════
Ticket #TKT-001 - Device ahu-01
Priority: High | Status: In Progress | Category: Hardware
Created: 2h ago | By: Jane Doe | Assigned: John Smith
═══════════════════════════════════════════════════════

[jane.doe] 2h ago:
Device making loud noise in ICU1. Please check urgently.
[Attached: noise_recording.mp3] [Attached: photo.jpg]

───────────────────────────────────────────────────────

[john.smith] 1h ago:
Scheduled maintenance for 3 PM today. Will investigate motor bearings.

───────────────────────────────────────────────────────

Reply: [___________________] [Attach] [Send]
```

**Ticket Actions:**
- Update status
- Assign to staff
- Add response
- Escalate priority
- Attach files
- Close ticket
- View history

**Ticket Analytics:**
- Average resolution time
- Tickets by category
- Tickets by priority
- Staff performance
- SLA compliance

---

## 📊 4. Analytics & Reports Module

### Dashboard Metrics

**Key Performance Indicators:**
- Total devices
- Online devices
- Alert count
- Average uptime
- Energy consumption
- Ticket resolution rate

**Real-time Charts:**
- Temperature distribution
- Humidity distribution
- Fan speed usage
- Device status pie chart
- Alert timeline
- Energy usage graph

### Historical Analytics

**Time-series Analysis:**
```python
# Query InfluxDB for historical data
query = f'''
from(bucket: "ahu_telemetry")
  |> range(start: -30d)
  |> filter(fn: (r) => r["_measurement"] == "ahu_sensors")
  |> filter(fn: (r) => r["site"] == "{site}")
  |> aggregateWindow(every: 1h, fn: mean)
  |> group(columns: ["device_id"])
'''

# Generate insights
insights = analyze_data(query_result)
```

**Report Types:**
1. **Device Health Report**
   - Uptime percentage
   - Error frequency
   - Maintenance schedule
   - Predictions

2. **Energy Consumption Report**
   - Daily/weekly/monthly usage
   - Cost estimates
   - Efficiency metrics
   - Comparative analysis

3. **Performance Report**
   - Temperature control accuracy
   - Humidity control accuracy
   - Response times
   - Optimization opportunities

4. **Usage Report**
   - Operating hours
   - Peak usage periods
   - Idle time analysis
   - Capacity utilization

**Custom Report Builder:**
- Select time range
- Choose metrics
- Filter devices/sites
- Group by dimensions
- Export (PDF, CSV, Excel)

---

## 🔄 5. OTA Deployment Module

### Firmware Management

**Firmware Repository:**
```
Firmware Library
├─ ESP32 Firmware
│  ├─ v2.0.0 (stable) - 1.2 MB
│  ├─ v2.1.0 (beta) - 1.3 MB
│  └─ v2.2.0 (alpha) - 1.4 MB
├─ Raspberry Pi Scripts
│  ├─ system-setup.sh - 50 KB
│  └─ mqtt-bridge v1.5 - 30 KB
└─ Mobile App Updates
   └─ Android/iOS builds
```

**Firmware Upload:**
```python
@app.post("/api/admin/ota/upload")
async def upload_firmware(
    file: UploadFile,
    version: str,
    device_type: str,
    release_notes: str
):
    # Validate file
    if not validate_firmware(file):
        raise ValueError("Invalid firmware file")
    
    # Generate checksum
    checksum = generate_checksum(file.content)
    
    # Upload to Firebase Storage
    url = upload_to_storage(file, f"firmware/{device_type}/v{version}.bin")
    
    # Store metadata
    firestore.collection('firmware').add({
        "version": version,
        "device_type": device_type,
        "file_url": url,
        "file_size": file.size,
        "checksum": checksum,
        "release_notes": release_notes,
        "uploaded_at": datetime.utcnow(),
        "uploaded_by": current_user.email,
        "status": "pending"
    })
    
    return {"status": "uploaded", "version": version}
```

### Deployment Interface

**Deployment Wizard:**
```
Step 1: Select Firmware
[Dropdown: Available versions ▼] v2.0.0

Step 2: Select Target Devices
○ All devices
○ By site: [Hospital A ▼]
○ By room: [ICU1 ▼]
● Specific devices: [ahu-01, ahu-03, ahu-05]
○ Custom filter: [_______]

Step 3: Deployment Strategy
○ Immediate deployment
● Staged rollout (recommended)
  Stage 1: 10% of devices
  Stage 2: 50% of devices (if Stage 1 success)
  Stage 3: 100% of devices

Step 4: Schedule
○ Deploy now
● Schedule deployment
  Date: [2025-01-16]
  Time: [02:00] (off-peak hours)

Step 5: Review
Firmware: v2.0.0
Devices: 50 devices
Strategy: Staged rollout
Schedule: 2025-01-16 02:00

[Deploy] [Cancel]
```

**Deployment Progress:**
```
OTA Deployment: v2.0.0 → 50 devices
═══════════════════════════════════════
Stage 1 (10 devices): ████████████ 100% Complete
├─ ahu-01: ✓ Success
├─ ahu-02: ✓ Success
└─ ...

Stage 2 (25 devices): ████░░░░░░░░ 40% In Progress
├─ ahu-11: ⏳ Downloading...
├─ ahu-12: ⏳ Installing...
└─ ...

Stage 3 (15 devices): ⏸ Pending
Waiting for Stage 2 completion...
```

**Deployment Tracking:**
```json
{
  "deployment_id": "DEP-2025-001",
  "firmware": "v2.0.0",
  "device_type": "ESP32",
  "target_devices": 50,
  "status": "in_progress",
  "stages": [
    {
      "stage": 1,
      "devices": 10,
      "success": 10,
      "failed": 0,
      "progress": 100,
      "started_at": "2025-01-15T02:00:00Z",
      "completed_at": "2025-01-15T02:15:00Z"
    },
    {
      "stage": 2,
      "devices": 25,
      "success": 8,
      "failed": 2,
      "progress": 40,
      "started_at": "2025-01-15T02:20:00Z",
      "completed_at": null
    }
  ],
  "rollback_threshold": 5,
  "auto_rollback": true
}
```

### OTA for Different Platforms

**ESP32 Updates:**
```python
# Publish update notification
mqtt_client.publish(
    f"almed/ahu/+/+/{device_id}/firmware/update",
    json.dumps({
        "version": "2.0.0",
        "url": firmware_url,
        "checksum": checksum,
        "size": file_size,
        "force": False
    })
)
```

**Raspberry Pi Updates:**
```bash
# SSH into RPI
# Pull latest scripts
git pull origin main

# Restart services
sudo systemctl restart mqtt-bridge
sudo systemctl restart mosquitto

# Verify
sudo systemctl status mqtt-bridge
```

**Mobile App Updates:**
- Push via app stores
- In-app update notifications
- Force update for critical versions

---

## 🔔 6. Notification Management Module

### Alert Configuration

**Alert Rules:**
```
Alert Rule #1: High Temperature
────────────────────────────────
Condition: temperature > 27°C
Duration: > 5 minutes
Devices: All devices
Severity: High
Actions:
  ✓ Send push notification
  ✓ Send email to assigned staff
  ✓ Create ticket
  ✓ Log alert

Alert Rule #2: Device Offline
──────────────────────────────
Condition: last_seen > 60 minutes
Devices: All devices
Severity: Critical
Actions:
  ✓ Send push notification to admin
  ✓ Send email to maintenance
  ✓ Create critical ticket

[Create New Alert Rule]
```

**Alert Configuration UI:**
```javascript
const alertConfig = {
  name: "High Temperature Alert",
  condition: {
    field: "temperature",
    operator: ">",
    value: 27,
    duration: 300  // 5 minutes
  },
  targets: ["all"],  // or specific device IDs
  severity: "high",
  actions: {
    push: true,
    email: true,
    ticket: true,
    webhook: false
  },
  recipients: {
    push: ["user_id_1", "user_id_2"],
    email: ["admin@hospital.com"],
    ticket_assignment: "maintenance_team"
  }
};
```

### Notification Sender

**Manual Push Notification:**
```
Send Notification
─────────────────
Recipients:
○ All users
○ Specific users: [John Doe] [Jane Doe] [+ Add]
○ By role: [Admin ▼]
○ By device assignment: [ahu-01 ▼]

Message:
Title: [System Maintenance Notice]
Body: [System will be under maintenance for 2 hours...]

Priority: [Low ▼]
Schedule: [Send now] [Schedule: 2025-01-16 09:00]

[Send Notification]
```

**Email Templates:**
- Alert notifications
- Ticket updates
- Weekly reports
- Maintenance reminders

**Notification History:**
- All sent notifications
- Delivery status
- Open rates
- Filter by type, date, recipient

---

## ⚙️ 7. System Settings Module

### Global Configuration

**System Settings:**
```json
{
  "general": {
    "site_name": "Hospital A",
    "timezone": "America/New_York",
    "language": "en",
    "maintenance_mode": false
  },
  "mqtt": {
    "broker_url": "hivemq.cloud",
    "port": 8883,
    "tls_enabled": true,
    "reconnect_interval": 10
  },
  "thresholds": {
    "default_temp_min": 18,
    "default_temp_max": 27,
    "default_humidity_min": 40,
    "default_humidity_max": 70,
    "alert_cooldown": 300
  },
  "notifications": {
    "email_enabled": true,
    "push_enabled": true,
    "smtp_server": "smtp.example.com",
    "from_email": "noreply@almed.com"
  },
  "integrity": {
    "backup_enabled": true,
    "backup_schedule": "0 2 * * *",
    "retention_days": 90,
    "encryption_enabled": true
  }
}
```

### Network Configuration

**Connection Settings:**
- MQTT broker configuration
- InfluxDB connection settings
- Firebase project settings
- SMTP configuration
- Webhook endpoints

**Security Settings:**
- API key management
- SSL/TLS certificates
- IP whitelist
- Rate limiting
- Audit logging

---

## 🔒 8. Security & Access Control

### Authentication

**Admin Login:**
```javascript
POST /api/admin/auth/login
{
  "email": "admin@almed.com",
  "password": "secure_password"
}

// Returns JWT token + permissions
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "userId": "admin_123",
    "email": "admin@almed.com",
    "role": "super_admin",
    "permissions": ["*"],
    "lastLogin": "2025-01-15T10:00:00Z"
  }
}
```

**Session Management:**
- JWT tokens
- Refresh tokens
- Session timeout
- Multi-factor authentication (optional)

### Audit Logging

**Activity Log:**
```
User Action Log
══════════════════════════════════════════════════════
2025-01-15 10:30:00 - admin@almed.com
Action: Update device configuration (ahu-01)
Details: Changed temperature setpoint from 22°C to 23°C

2025-01-15 10:25:00 - admin@almed.com
Action: Assign devices to user (John Doe)
Details: Assigned 3 devices (ahu-01, ahu-02, ahu-03)

2025-01-15 10:20:00 - admin@almed.com
Action: Deploy firmware (v2.0.0)
Details: Deployed to 50 devices via staged rollout

[Export Log] [Filter] [Search]
```

---

## 📈 9. Advanced Features

### Multi-site Management

**Site Configuration:**
- Multiple hospital sites
- Site-specific settings
- Cross-site reporting
- Site-level permissions

### Maintenance Scheduling

**Preventive Maintenance:**
```
Schedule Maintenance Task
──────────────────────────
Device: ahu-01
Task: Replace filters
Frequency: Every 3 months
Next Due: 2025-04-15
Assigned: Maintenance Team 1
Auto-create ticket: Yes

[Schedule]
```

### Custom Dashboard Builder

**Drag-and-drop Interface:**
- Custom widget placement
- Real-time data widgets
- Chart widgets
- KPI widgets
- Save multiple dashboards

### Data Export

**Export Options:**
- CSV
- Excel
- PDF reports
- JSON
- API access

### API Access

**REST API:**
```python
# External integrations
GET  /api/v1/devices/:id
POST /api/v1/devices/:id/commands
GET  /api/v1/analytics/:metric
```

---

## 🛠️ 10. Technology Stack

### Frontend

**Framework Options:**
1. **React** (Recommended)
   - Material-UI / Ant Design
   - Recharts / Chart.js
   - React Query
   - Realtime via Socket.io

2. **Vue.js**
   - Vuetify / Element Plus
   - Vue Chart.js
   - Vuex / Pinia
   - WebSocket

3. **Angular**
   - Angular Material
   - Chart.js wrapper
   - NgRx
   - WebSocket

### Backend

**API Framework:**
- Python: FastAPI
- Node.js: Express.js
- Go: Gin
- Java: Spring Boot

**Recommended:**
```
Backend: FastAPI (Python)
├─ Database: InfluxDB + Firestore + PostgreSQL
├─ MQTT: paho-mqtt
├─ WebSocket: FastAPI WebSockets
├─ Auth: JWT + Firebase
├─ Email: SendGrid / AWS SES
└─ File Storage: Firebase Storage
```

### Deployment

**Infrastructure:**
- Frontend: Netlify / Vercel / AWS S3 + CloudFront
- Backend: Google Cloud Run / AWS Lambda
- Database: Cloud-hosted
- Monitoring: Grafana / DataDog

---

## 🎯 11. Implementation Phases

### Phase 1: Core Dashboard (Weeks 1-3)
- [x] Admin authentication
- [x] User management
- [x] Device list and monitoring
- [x] Basic controls
- [x] Ticket list

### Phase 2: Advanced Features (Weeks 4-6)
- [x] Analytics and reports
- [x] OTA deployment
- [x] Alert configuration
- [x] Notification sender
- [x] Device assignment

### Phase 3: Enterprise (Weeks 7-9)
- [x] Multi-site management
- [x] Custom dashboards
- [x] API access
- [x] Maintenance scheduling
- [x] Data export

### Phase 4: Polish & Production (Weeks 10-12)
- [x] Security hardening
- [x] Performance optimization
- [x] Comprehensive testing
- [x] Documentation
- [x] Deployment

---

## ✅ Feature Checklist

### Must Have ✅
- [x] User authentication and authorization
- [x] User management (CRUD)
- [x] Device monitoring (real-time)
- [x] Device control (commands)
- [x] Ticket management system
- [x] Analytics dashboard
- [x] OTA deployment
- [x] Alert configuration
- [x] Notification system
- [x] Audit logging

### Nice to Have 🚀
- [ ] Custom dashboard builder
- [ ] Advanced reporting
- [ ] Multi-language support
- [ ] Mobile responsive design
- [ ] Dark mode
- [ ] Multi-factor authentication
- [ ] Webhook integrations
- [ ] AI-powered insights

---

## 🎉 Summary

**Admin Web Dashboard provides complete system control:**

✅ **User Management** - Assign devices, manage roles  
✅ **Device Monitoring** - Real-time status, historical data  
✅ **Remote Control** - Send commands, configure devices  
✅ **Ticket System** - Manage support requests  
✅ **OTA Deployment** - Update ESP32, RPI, Mobile  
✅ **Analytics** - Reports, insights, predictions  
✅ **Notifications** - Configure alerts, send messages  
✅ **Security** - Access control, audit logs  

**Complete administrative control over the entire ALMED AHU system!** 🚀

