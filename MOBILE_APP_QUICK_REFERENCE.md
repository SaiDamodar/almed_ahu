# Mobile App Quick Reference

## 🔐 Authentication
**Firebase Auth** → Email/Password → JWT Token → Store locally

**Roles:**
- **Admin**: All units, OTA updates, provisioning
- **Staff**: Assigned units, raise tickets
- **Maintenance**: All units, respond tickets

---

## 📊 Data Flow

```
ESP32 → RPI MQTT → Bridge → HiveMQ Cloud → Mobile App
                               ↓
                         InfluxDB (graphs)
                               ↓
                    Firebase (users, tickets, push)
```

**MQTT Topics:**
- `almed/ahu/{site}/{room}/{device-id}/telemetry` - Sensor data (every 10s)
- `almed/ahu/{site}/{room}/{device-id}/cmd` - Commands from mobile
- `almed/ahu/{site}/{room}/{device-id}/state` - Status updates
- `almed/ahu/{site}/{room}/{device-id}/log` - Device logs

---

## 🎛️ Controls

**Commands:**
```json
{"start": true}           // Start system
{"stop": true}            // Stop system
{"setpoint": 23.5}        // Change temp setpoint
{"humiditySetpoint": 55}  // Change humidity setpoint
```

**Flow:** Mobile → Cloud → Bridge → RPI → ESP32 → Execute → Reply

---

## 📈 Graphs (InfluxDB)

**Queries:** Temperature, Humidity, Motor runtime, Energy usage

**Time ranges:** 24h / 7d / 30d

**Charts:** Line charts, Bar charts, Multi-device overlay

---

## 🔔 Notifications (FCM)

**Alerts:**
- Temperature out of range (>27°C or <18°C)
- Humidity out of range (>70% or <40%)
- System failure, Sensor error
- Maintenance due
- Ticket responses

**Flow:** ESP32 detects → Bridge checks → Backend queries users → FCM push → Mobile app

---

## 🎫 Tickets (Firebase Firestore)

**Create:** Device → Report Issue → Category, Description, Photo → Submit

**Track:** Open → Assigned → In Progress → Resolved → Closed

**Notify:** Push notification for responses

**Data:**
```json
{
  "ticket_id": "TKT-2025-001",
  "device_id": "ahu-01",
  "created_by": "user123",
  "status": "Open",
  "description": "Device making noise",
  "responses": [...]
}
```

---

## 🔄 OTA Updates

**Flow:**
1. Admin uploads firmware → Firebase Storage
2. Backend publishes to MQTT → ESP32 receives
3. ESP32 downloads via HTTPS → Verifies checksum
4. ESP32 installs + reboots → Publishes status
5. Mobile app shows progress

**Deploy:** Admin selects devices → Staged rollout (10% → 50% → 100%)

---

## 🗄️ Databases

**InfluxDB Cloud:**
- Time-series sensor data
- Queries for historical graphs
- Retention: 30 days

**Firebase Firestore:**
- Users, device assignments
- Tickets, responses
- Device metadata
- OTA update logs

**Firebase Auth:**
- User authentication
- JWT tokens
- Session management

---

## 📡 Backend APIs

**Auth:** `/api/auth/login`, `/api/user/profile`

**Devices:** `/api/devices`, `/api/devices/:id/history`, `/api/devices/:id/command`

**Tickets:** `/api/tickets`, `/api/tickets/:id`, `/api/tickets/:id/reply`

**Firmware:** `/api/firmware`, `/api/firmware/deploy`

**Analytics:** `/api/analytics/overview`, `/api/analytics/trends`

**Notifications:** `/api/notifications/push`

---

## 🏗️ Architecture

**Mobile:** Flutter → Provider state → MQTT client + REST API

**Backend:** Python FastAPI → MQTT Bridge → InfluxDB + Firestore

**MQTT:** HiveMQ Cloud (secure TLS) ↔ Raspberry Pi (Mosquitto)

**Databases:** InfluxDB + Firebase Firestore + Firebase Auth

**Notifications:** Firebase Cloud Messaging

**Storage:** Firebase Storage (firmware)

---

## 🚀 Deployment

**Phase 1 (Weeks 1-2):** Auth, Basic MQTT, Device list, Real-time display, Commands

**Phase 2 (Weeks 3-4):** Graphs, Push notifications, Tickets, Admin features

**Phase 3 (Weeks 5-6):** OTA updates, Analytics, Offline mode, Export

**Phase 4 (Weeks 7-8):** Polish, Testing, App store submission

---

## 🔒 Security

**Auth:** Firebase JWT, Token refresh, Biometric login

**Authorization:** Role-based, Device assignment restrictions

**Encryption:** TLS 1.3 (MQTT), HTTPS (APIs), Encrypted storage

**Device:** Firmware signatures, Rate limiting, Client certs (optional)

---

## ⚡ Quick Commands

**Test MQTT:**
```bash
mosquitto_pub -h YOUR_HIVEMQ_URL -u USER -P PASS -t "almed/ahu/+/+/+/cmd" -m '{"start": true}'
mosquitto_sub -h YOUR_HIVEMQ_URL -u USER -P PASS -t "almed/ahu/+/+/+/telemetry" -v
```

**InfluxDB Query:**
```flux
from(bucket: "ahu_telemetry")
  |> range(start: -24h)
  |> filter(fn: (r) => r["device_id"] == "ahu-01")
  |> filter(fn: (r) => r["_field"] == "temperature")
```

**Create Ticket (API):**
```bash
POST /api/tickets
{
  "device_id": "ahu-01",
  "category": "Hardware",
  "priority": "High",
  "description": "Issue description"
}
```

---

## 📱 App Screens

**Dashboard:** Grid of devices, Status indicators, Quick actions

**Device Detail:** Current readings, Control buttons, Graphs, Logs

**Graphs:** Line/Bar charts, Time range selector, Export CSV

**Tickets:** List, Create, View thread, Upload photos, Filter

**Admin:** Users, Devices, OTA deployment, Analytics, System health

---

## 🔑 Key Files

**Mobile:** `lib/services/{auth,mqtt,api}_service.dart`, `lib/providers/{auth,device}_provider.dart`

**Backend:** `mqtt_bridge.py`, `alert_service.py`, `api_server.py`, `notification_service.py`

**Config:** `.env` (credentials), `firebase_config.json`, `influxdb_config.json`

---

## ✅ Checklist

- [ ] Firebase Auth setup
- [ ] MQTT connection (HiveMQ)
- [ ] InfluxDB bucket created
- [ ] Firestore collections setup
- [ ] Push notifications (FCM)
- [ ] Device assignment system
- [ ] Ticket system
- [ ] OTA update mechanism
- [ ] Backend APIs deployed
- [ ] Mobile app built
- [ ] Testing completed
- [ ] App store approval

---

**See `MOBILE_APP_COMPLETE_PLAN.md` for detailed implementation.**

