# Admin Web Dashboard Quick Reference

## 🌐 Dashboard Sections

**Overview** → System health, metrics, recent activity  
**Users** → Manage users, roles, device assignments  
**Devices** → Monitor and control all devices  
**Tickets** → Support management  
**Analytics** → Reports and insights  
**OTA** → Firmware deployments  
**Notifications** → Alert configuration, push sender  
**Settings** → System configuration  

---

## 👥 User Management

**Create User:** Email, Name, Role, Phone → Assign devices

**Roles:**
- Super Admin: Full access
- Admin: User/device management, reports
- Hospital Staff: Assigned devices, tickets
- Maintenance: All devices, respond to tickets
- Viewer: Read-only

**Device Assignment:** Select devices → Choose user → Assign

---

## 🖥️ Device Management

**Monitor:** Real-time readings, status, last seen  
**Control:** Start/stop, setpoints, fan speed, motor timings  
**Configure:** Thresholds, provisioning, metadata  

**Commands:**
```json
{"start": true}, {"stop": true}
{"setpoint": 23.5}, {"humiditySetpoint": 55}
{"fanToggle": true}, {"fanSpeed": 1}
{"motorTimings": {...}}
```

---

## 🎫 Ticket Management

**List:** Filter by status, priority, category, date  
**View:** Ticket thread, attachments, history  
**Actions:** Assign, respond, update status, close  

**Status:** Open → Assigned → In Progress → Resolved → Closed

---

## 📊 Analytics

**Metrics:** Uptime, alerts, energy usage, ticket resolution  
**Charts:** Temperature/humidity/fan speed trends, device health  
**Reports:** Daily/weekly/monthly, custom date ranges  

**Export:** CSV, Excel, PDF

---

## 🔄 OTA Deployment

**Upload Firmware:** Version, file, release notes → Firebase Storage  
**Deploy:** Select firmware → Target devices → Strategy  

**Strategies:**
- Immediate deployment
- Staged rollout (10% → 50% → 100%)

**Track:** Real-time progress, success/failure, auto-rollback

---

## 🔔 Notifications

**Alert Rules:** Condition → Severity → Actions  
**Send Push:** Recipients → Message → Priority → Schedule  

**Actions:** Push, email, create ticket, webhook

---

## ⚙️ Settings

**Global:** Site name, timezone, thresholds  
**Network:** MQTT, InfluxDB, Firebase, SMTP  
**Security:** API keys, certificates, audit logs  

---

## 🔒 Security

**Auth:** JWT tokens, refresh, MFA  
**Permissions:** Role-based access control  
**Audit:** Activity logs, export  

---

## 📡 API Endpoints

**Users:** `/api/admin/users` (GET, POST, PUT, DELETE)  
**Devices:** `/api/admin/devices` (GET, POST, PUT)  
**Commands:** `/api/admin/devices/:id/command` (POST)  
**Tickets:** `/api/admin/tickets` (GET, POST, PUT)  
**Analytics:** `/api/admin/analytics/:metric` (GET)  
**OTA:** `/api/admin/ota/upload` (POST), `/api/admin/ota/deploy` (POST)  
**Notifications:** `/api/admin/notifications/send` (POST)  
**Settings:** `/api/admin/settings` (GET, PUT)  

---

## 🎯 Quick Actions

**Assign Devices:** Users → Select → Devices → Assign  
**Deploy Firmware:** OTA → Upload → Select → Deploy  
**Send Notification:** Notifications → New → Recipients → Message → Send  
**Create Ticket:** Tickets → New → Device → Category → Submit  
**View Analytics:** Analytics → Select metric → Time range → Export  

---

## ✅ Implementation Phases

**Phase 1 (Weeks 1-3):** Auth, Users, Devices, Tickets  
**Phase 2 (Weeks 4-6):** Analytics, OTA, Alerts  
**Phase 3 (Weeks 7-9):** Multi-site, API, Schedules  
**Phase 4 (Weeks 10-12):** Security, Polish, Deploy  

---

**See `ADMIN_WEB_COMPLETE_PLAN.md` for detailed implementation.**

