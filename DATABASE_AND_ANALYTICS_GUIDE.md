# Database & Analytics Guide for Mobile App & Admin Web Dashboard

## Complete Guide for Data Storage, Visualization & Analytics

---

## 📋 Table of Contents

1. [Cloud Storage Options](#cloud-storage)
2. [Database Architecture](#database)
3. [Graphs & Analytics](#graphs)
4. [Mobile App Features](#mobile-analytics)
5. [Admin Dashboard Features](#admin-analytics)
6. [Implementation Examples](#implementation)

---

## ☁️ Cloud Storage Options

### Current Architecture: MQTT-Only (No Database)

**What you have NOW:**
```
ESP32 → MQTT → App displays real-time data
```
- Data is **transient** (published, received, displayed, lost)
- No historical data stored
- No analytics or trends

**Limitation**: Can't see past data, trends, or statistics

---

## 🗄️ Database Architecture

### Option 1: MQTT + Time-Series Database ⭐ **RECOMMENDED FOR START**

**Best for**: Simple start, no backend complexity

```
ESP32 → MQTT → InfluxDB (Time-series DB)
                       ↓
              Flutter App queries historical data
```

**Components:**
- **MQTT**: Real-time data (current setup)
- **InfluxDB**: Historical data storage
- **Flutter App**: Displays both real-time + historical

**Pros:**
- ✅ No backend API needed
- ✅ Flutter connects directly to InfluxDB
- ✅ Perfect for time-series data (sensor readings)
- ✅ Free tier available

**Cons:**
- ⚠️ Need to run InfluxDB somewhere (cloud or Raspberry Pi)
- ⚠️ Flutter app needs InfluxDB query logic

---

### Option 2: MQTT + PostgreSQL/MySQL (Full Database)

**Best for**: Complex queries, user management, relationships

```
ESP32 → MQTT → Backend API → PostgreSQL
                            ↓
                  Flutter App (queries API)
```

**Database Schema:**

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    role VARCHAR(50),  -- 'admin', 'hospital'
    created_at TIMESTAMP DEFAULT NOW()
);

-- Device assignments
CREATE TABLE user_devices (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    device_id VARCHAR(100),  -- 'ahu-01'
    assigned_at TIMESTAMP DEFAULT NOW()
);

-- Telemetry history (time-series)
CREATE TABLE telemetry_history (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(100),
    timestamp TIMESTAMP DEFAULT NOW(),
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    m1_active BOOLEAN,
    m2_active BOOLEAN,
    cp_on BOOLEAN,
    heater_on BOOLEAN,
    run_state BOOLEAN
);

-- System logs
CREATE TABLE system_logs (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(100),
    timestamp TIMESTAMP DEFAULT NOW(),
    level VARCHAR(20),  -- 'INFO', 'WARN', 'ERROR'
    message TEXT
);

-- Motor event history
CREATE TABLE motor_events (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(100),
    timestamp TIMESTAMP DEFAULT NOW(),
    motor_type VARCHAR(10),  -- 'm1', 'm2'
    event_type VARCHAR(20),  -- 'start', 'stop'
    duration_seconds INTEGER
);
```

**Pros:**
- ✅ Rich queries (joins, aggregations, filters)
- ✅ User management in database
- ✅ Audit logging
- ✅ Relational data

**Cons:**
- ⚠️ Needs backend API server
- ⚠️ More complex setup
- ⚠️ PostgreSQL hosting required

---

### Option 3: Firebase (Google's BaaS) ⭐ **EASIEST**

**Best for**: Quick deployment, no backend management

```
ESP32 → MQTT → Cloud Functions → Firebase Firestore
                                    ↓
                          Flutter App (Firebase SDK)
```

**Components:**
- **MQTT**: Real-time data
- **Firebase Cloud Functions**: Backend logic (Node.js)
- **Firebase Firestore**: NoSQL database
- **Firebase Authentication**: User management
- **Firebase Analytics**: Built-in analytics

**Database Structure (Firestore):**

```javascript
// Firestore Collections

users/
  {userId}/
    email: "doctor@hospital.com"
    name: "Dr. Smith"
    role: "hospital"
    assignedDevices: ["ahu-01"]
    createdAt: Timestamp

devices/
  {deviceId}/
    name: "ICU-1 AHU"
    site: "hospitalA"
    room: "icu1"
    status: "online"

telemetry/
  {deviceId}/
    {timestamp}/
      temp: 24.5
      hum: 62.0
      m1: false
      m2: true
      cp: true
      heater: false
      timestamp: Timestamp

logs/
  {deviceId}/
    {logId}/
      level: "INFO"
      message: "Motor-1 started"
      timestamp: Timestamp
```

**Pros:**
- ✅ No backend server to manage
- ✅ Auto-scaling
- ✅ Real-time listeners (Socket connections)
- ✅ Google Auth built-in
- ✅ Free tier generous

**Cons:**
- ⚠️ Vendor lock-in (Google)
- ⚠️ Costs scale with usage
- ⚠️ Less flexible than custom backend

---

### Option 4: Hybrid (Start Simple, Scale Later) ⭐ **RECOMMENDED**

**Phase 1: No Database** (Current)
- MQTT only
- Real-time data only
- Suitable for basic monitoring

**Phase 2: Add Simple Storage** (When needed)
- Cloud Functions + Firestore
- Store last 7 days of data
- Basic analytics

**Phase 3: Full Database** (When scaling)
- Backend API + PostgreSQL
- Unlimited history
- Advanced analytics

---

## 📊 Graphs & Analytics

### Mobile App Graphs

**What to display:**

#### 1. Real-Time Gauge Charts

```
Temperature Gauge (Current Value)
        ┌─────────────────┐
        │                 │
        │   24.5 °C       │
        │      ╱│╲        │
        │    ╱  │  ╲      │
        │   ╱   │   ╲     │
        │  ╱____│____╲    │
        │                 │
        │  Setpoint: 22°C │
        └─────────────────┘
```

**Flutter Implementation:**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TemperatureGauge extends StatelessWidget {
  final double currentTemp;
  final double setpointTemp;
  
  @override
  Widget build(BuildContext context) {
    final percentage = (currentTemp / 30) * 100; // Scale to 30°C max
    
    return Container(
      height: 200,
      width: 200,
      child: CircularChart(
        chartType: CircularChartType.Radial,
        data: [
          CircularChartData(
            label: 'Temp',
            value: percentage,
            color: _getTempColor(currentTemp),
          ),
        ],
        annotations: [
          CircularChartAnnotation(
            position: 'center',
            widget: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currentTemp.toStringAsFixed(1)}°C',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Set: ${setpointTemp}°C',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getTempColor(double temp) {
    if (temp > 28) return Colors.red;
    if (temp > 25) return Colors.orange;
    return Colors.green;
  }
}
```

#### 2. Line Charts (Historical Data)

```
Last 24 Hours Temperature Trend
          
         30°C │                    ╱─╲
              │               ╱─╲╱  ╲
         25°C │          ╱─╲╱
              │     ╱─╲╱
         20°C └────────────────────────────
              0h   6h   12h  18h   24h
    
    Humidity Trend
         70%  │         ╱───╲
              │    ╱───╲    ╲───╲
         50%  │╱──╲
              │
         30%  └────────────────────────────
              0h   6h   12h  18h   24h
```

**Flutter Implementation:**

```dart
import 'package:fl_chart/fl_chart.dart';

class TemperatureChart extends StatelessWidget {
  final List<TelemetryDataPoint> dataPoints;  // Last 24 hours
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: dataPoints.map((point) => 
                FlSpot(point.hoursAgo.toDouble(), point.temp)
              ).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true),
            ),
            LineChartBarData(
              spots: dataPoints.map((point) => 
                FlSpot(point.hoursAgo.toDouble(), point.setpoint)
              ).toList(),
              isCurved: false,
              color: Colors.grey,
              barWidth: 2,
              dotData: FlDotData(show: false),
              dashArray: [5, 5],
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3. Motor Activity Timeline

```
Motor Activity (Last Hour)
M1: ████████░░░░████░░░░░░████
M2: ░░░░████░░░░░░░░████░░░░░░
CP: ░░░░████████░░░░████████░░
    
   10m  20m  30m  40m  50m  60m
```

**Flutter Implementation:**

```dart
class MotorTimelineChart extends StatelessWidget {
  final List<MotorEvent> events;  // Motor start/stop events
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      child: BarChart(
        BarChartData(
          barGroups: _generateBarGroups(events),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                getTitlesWidget: (value, meta) {
                  String motor = '';
                  if (value == 1) motor = 'M1';
                  else if (value == 2) motor = 'M2';
                  else if (value == 3) motor = 'CP';
                  return Text(motor, style: TextStyle(fontSize: 12));
                },
                showTitles: true,
                reservedSize: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  List<BarChartGroupData> _generateBarGroups(List<MotorEvent> events) {
    // Group motor events by 5-minute intervals
    // Return bar chart groups
    return [];
  }
}
```

---

### Admin Web Dashboard Analytics

**Advanced analytics for admins:**

#### 1. System Health Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│                   System Overview (All Devices)              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  📊 Device Status:                                           │
│  ├─ Online:  ████████████████░  18/20 (90%)                │
│  ├─ Offline: ██░░░░░░░░░░░░░░   2/20 (10%)                 │
│  └─ Errors:  ░░░░░░░░░░░░░░░░   0/20 (0%)                  │
│                                                              │
│  🌡️ Average Temperature:                                    │
│  ├─ ICU-1:  24.2°C ████████████  Within range ✅            │
│  ├─ ICU-2:  25.8°C █████████████ Out of range ⚠️           │
│  ├─ ER-1:   22.1°C ███████████   Within range ✅            │
│  └─ OR-1:   23.5°C █████████████ Within range ✅            │
│                                                              │
│  ⚙️ Motor Activity (Last 24h):                               │
│  ├─ M1 Starts: 128 times                                    │
│  ├─ M2 Starts: 256 times                                    │
│  └─ Avg runtime: 12.5 seconds per start                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### 2. Historical Trend Analysis

**Multi-Device Comparison Chart:**

```dart
class AdminTrendChart extends StatelessWidget {
  final List<DeviceData> devices;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      child: LineChart(
        LineChartData(
          lineBarsData: devices.map((device) => 
            LineChartBarData(
              spots: device.historicalData.map((d) => 
                FlSpot(d.time.toDouble(), d.temp)
              ).toList(),
              color: device.color,
              label: device.name,
            )
          ).toList(),
          legend: Legend(
            show: true,
            position: LegendPosition.top,
          ),
        ),
      ),
    );
  }
}
```

#### 3. Statistical Reports

**Daily/Weekly/Monthly summaries:**

```
┌──────────────────────────────────────────────────────────┐
│               Statistical Report - ICU-1 AHU              │
│                    December 2024                          │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Temperature Statistics:                                  │
│  ├─ Average: 24.2°C                                       │
│  ├─ Min: 20.1°C                                           │
│  ├─ Max: 27.8°C                                           │
│  ├─ Std Dev: 1.2°C                                        │
│  └─ Time in range: 94%                                   │
│                                                           │
│  Humidity Statistics:                                     │
│  ├─ Average: 58.3%                                        │
│  ├─ Min: 42.1%                                            │
│  ├─ Max: 72.5%                                            │
│  └─ Time in range: 89%                                   │
│                                                           │
│  Motor Usage:                                             │
│  ├─ M1 total runtime: 2.3 hours                          │
│  ├─ M2 total runtime: 4.1 hours                          │
│  ├─ CP total runtime: 15.2 hours                         │
│  └─ Heater total runtime: 3.7 hours                      │
│                                                           │
│  System Availability:                                     │
│  ├─ Uptime: 99.8%                                         │
│  ├─ Total runtime: 720 hours                             │
│  └─ Downtime: 1.2 hours                                  │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 📱 Mobile App Analytics Features

### What Mobile Users See

#### Dashboard View (Cards)
```
┌─────────────────────────────────────┐
│       ICU-1 AHU                     │
│                                     │
│  🌡️  24.5°C                         │
│  💧  62%                             │
│                                     │
│  Status: Running ✅                 │
│  └─ Tap to view details             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│       ICU-2 AHU                     │
│                                     │
│  🌡️  25.8°C                         │
│  💧  58%                             │
│                                     │
│  Status: Running ✅                 │
│  └─ Tap to view details             │
└─────────────────────────────────────┘
```

#### Detail View (with Historical Chart)

```
┌─────────────────────────────────────┐
│ ← Back    ICU-1 AHU                 │
├─────────────────────────────────────┤
│                                     │
│  Current Reading:                   │
│  🌡️ Temp: 24.5°C (Set: 22°C)       │
│  💧 Hum: 62% (Set: 55%)             │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    Temperature Trend        │    │
│  │    Last 24 Hours            │    │
│  │                             │    │
│  │    30°C ┤   ╱─╲             │    │
│  │    25°C ┤╱─╲   ╲─╲           │    │
│  │    20°C ┼─────────────────┤    │
│  │         └─────────────────┘    │
│  └─────────────────────────────┘    │
│                                     │
│  [Show Last 7 Days ▾]               │
│                                     │
│  Motor Status:                      │
│  ├─ M1 (Drain): Off                │
│  ├─ M2 (Filter): Off               │
│  ├─ CP: On  ████████████           │
│  └─ Heater: Off                    │
│                                     │
│  [Start]  [Stop]  [Settings ⚙️]    │
└─────────────────────────────────────┘
```

---

## 🌐 Admin Dashboard Analytics Features

### What Admins See

#### Overview Screen

```
┌──────────────────────────────────────────────────────────────────┐
│  ADMIN DASHBOARD                    [User Management] [Logout]   │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  📊 System Overview                                              │
│  ├─ Total Devices: 20                                            │
│  ├─ Online Now: 18 (90%)                                         │
│  ├─ Active Users: 12                                             │
│  └─ Last 24h Alerts: 3                                           │
│                                                                    │
│  🏥 Locations                                                     │
│  ├─ Hospital A: 12 devices (all online)                          │
│  ├─ Hospital B: 8 devices (6 online, 2 offline)                 │
│  └─ Total Sites: 2                                               │
│                                                                    │
│  📈 Average Conditions (Last Hour)                               │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Device      │ Temp │ Hum │ M1 │ M2 │ CP │ Heat │ Status  │    │
│  ├─────────────┼──────┼─────┼────┼────┼────┼──────┼─────────┤    │
│  │ ICU-1       │ 24.2 │ 62% │ ✓  │ ✗  │ ✓  │ ✗   │ ✅      │    │
│  │ ICU-2       │ 25.8 │ 58% │ ✓  │ ✓  │ ✓  │ ✗   │ ⚠️      │    │
│  │ ICU-3       │ 23.1 │ 61% │ ✗  │ ✓  │ ✗  │ ✗   │ ✅      │    │
│  │ ER-1        │ 22.5 │ 59% │ ✗  │ ✗  │ ✗  │ ✗   │ ✅      │    │
│  │ OR-1        │ 23.8 │ 57% │ ✓  │ ✗  │ ✓  │ ✓   │ ✅      │    │
│  │ ... (15 more)                                                │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                    │
│  [View Detailed Reports →]                                        │
└──────────────────────────────────────────────────────────────────┘
```

#### Analytics & Reports Screen

```
┌──────────────────────────────────────────────────────────────────┐
│  Reports & Analytics                          [← Back]           │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  📅 Time Period: [Last 7 Days ▾]  [Export PDF]                   │
│                                                                    │
│  📊 Device Comparison                                             │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Average Temperature by Device (Last 7 Days)              │    │
│  │                                                           │    │
│  │    30°C ┤                                                 │    │
│  │    25°C ┤  ████████████████████████████ ICU-1            │    │
│  │         ┤  █████████████████████████████████ ICU-2       │    │
│  │    20°C ┤  ██████████████████████ ICU-3                  │    │
│  │    15°C ┤───────────────────────────────┤                │    │
│  │           Mon Tue Wed Thu Fri Sat Sun                     │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                    │
│  ⚙️ Motor Usage Statistics                                        │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ Motor Starts per Day (Average)                           │    │
│  │                                                           │    │
│  │ M1: ████████████████████ 64 starts/day                   │    │
│  │ M2: ████████████████████████████████ 128 starts/day      │    │
│  │ CP: █████████████████████████████████████████████ 192    │    │
│  │ Heat: █████████████████████ 96 starts/day               │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                    │
│  🎯 Performance Metrics                                           │
│  ├─ System Availability: 99.8%                                   │
│  ├─ Avg Response Time: 45ms                                      │
│  ├─ Data Points Collected: 432,000                               │
│  └─ Network Uptime: 100%                                         │
│                                                                    │
│  ⚠️ Alerts & Warnings                                             │
│  ├─ Over-temperature (ICU-2): 3 occurrences                      │
│  ├─ Motor failures: 0                                            │
│  ├─ Network disconnects: 2                                       │
│  └─ [View All Alerts →]                                          │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Recommended Database Architecture

### For Your Hospital AHU System

**Recommended: Start with InfluxDB, migrate to Firebase later**

#### Phase 1: InfluxDB (Simple Start)

**Why InfluxDB?**
- ✅ Perfect for time-series data (sensor readings)
- ✅ No backend API needed (Flutter connects directly)
- ✅ Free tier: Unlimited data
- ✅ Fast queries for time ranges
- ✅ Built-in aggregations (avg, min, max, sum)

**Data Structure:**

```javascript
// InfluxDB Measurement: telemetry

telemetry,tag_device_id=ahu-01,tag_site=hospitalA,tag_room=icu1 
  temp=24.5,
  hum=62.0,
  m1=false,
  m2=false,
  cp=true,
  heater=false,
  run=true
  timestamp=1703123456789
```

**Flutter Integration:**

```dart
// pubspec.yaml
dependencies:
  influxdb_client: ^1.0.0

// Query historical data
Future<List<TelemetryDataPoint>> getHistoricalData(
  String deviceId, 
  int hoursBack
) async {
  final client = InfluxDBClient(
    url: 'https://your-influxdb-instance.com',
    token: 'your-token',
  );
  
  final query = '''
    from(bucket: "almed_ahu")
      |> range(start: -${hoursBack}h)
      |> filter(fn: (r) => r["_measurement"] == "telemetry")
      |> filter(fn: (r) => r["device_id"] == "$deviceId")
      |> aggregateWindow(every: 1m, fn: mean)
  ''';
  
  final result = await client.query(query);
  return result.toTelemetryDataPoints();
}
```

#### Phase 2: Migrate to Firebase (When Scaling)

**Why Firebase?**
- ✅ No database server management
- ✅ Auto-scaling
- ✅ Real-time listeners
- ✅ Google Auth built-in
- ✅ Cloud Functions for MQTT → DB

**Architecture:**

```
ESP32 → MQTT → Cloud Function (Node.js)
                      ↓
              Firebase Firestore
                      ↓
              Flutter App (Real-time + Historical)
```

---

## 📊 Implementation Priority

### Week 1: Real-Time Only (Current)

**What users see**: Current values only
- No historical data
- No trends
- No analytics

**Suitable for**: Basic monitoring

---

### Week 2: Add Simple Historical Data

**Add to Flutter App:**
- Store last 100 readings in memory
- Display simple line chart
- No database needed

```dart
class AppProvider extends ChangeNotifier {
  final Map<String, List<TelemetryPoint>> _history = {};
  
  void addTelemetryPoint(String deviceId, TelemetryPoint point) {
    if (!_history.containsKey(deviceId)) {
      _history[deviceId] = [];
    }
    _history[deviceId]!.add(point);
    
    // Keep only last 100 points
    if (_history[deviceId]!.length > 100) {
      _history[deviceId]!.removeAt(0);
    }
    
    notifyListeners();
  }
  
  List<TelemetryPoint> getHistory(String deviceId) {
    return _history[deviceId] ?? [];
  }
}
```

---

### Week 3: Add Database (InfluxDB)

**Setup:**
1. Install InfluxDB on Raspberry Pi or cloud
2. Configure MQTT → InfluxDB connector
3. Update Flutter app to query historical data

**Result**: Full historical analytics!

---

## 🛠️ Quick Implementation Guide

### Add Charts to Your Existing Dashboard

**Step 1: Update pubspec.yaml**

Already has `fl_chart: ^0.70.1` ✅

**Step 2: Create Chart Widget**

```dart
// lib/widgets/temperature_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TemperatureChart extends StatelessWidget {
  final List<double> temperatures;
  final double setpoint;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey, width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: temperatures.asMap().entries.map((entry) => 
                FlSpot(entry.key.toDouble(), entry.value)
              ).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: temperatures.asMap().entries.map((entry) => 
                FlSpot(entry.key.toDouble(), setpoint)
              ).toList(),
              isCurved: false,
              color: Colors.grey,
              barWidth: 1,
              dotData: FlDotData(show: false),
              dashArray: [5, 5],
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 3: Add to Control Screen**

```dart
// In ahu_control_screen.dart
Column(
  children: [
    // Current reading
    Text('${temp}°C'),
    
    // Historical chart
    TemperatureChart(
      temperatures: history.map((h) => h.temp).toList(),
      setpoint: setpoint,
    ),
  ],
)
```

---

## 📊 Analytics Features for Admin

### Reports to Generate

#### Daily Report
- Average temperature/humidity per device
- Motor usage statistics
- Energy consumption estimates
- Alerts count

#### Weekly Report
- Temperature/humidity trends
- Device availability
- Performance comparisons
- Maintenance recommendations

#### Monthly Report
- Overall system health
- Cost analysis (if applicable)
- Upgrade recommendations
- Compliance status

---

## 🎯 Recommended Setup for Your System

### Phase 1: Start Simple (Week 1-2)

**Storage**: None (MQTT only)
- Real-time data display
- No historical data
- Basic monitoring

**Charts**: In-memory only
- Last 100 readings
- Simple line charts
- Current values + recent trend

---

### Phase 2: Add Storage (Week 3-4)

**Storage**: InfluxDB on Raspberry Pi
- Local historical data
- Last 30 days
- Fast queries

**Charts**: Full historical
- Last 24h, 7d, 30d views
- Statistical analysis
- Temperature/humidity trends

---

### Phase 3: Cloud Analytics (Month 2+)

**Storage**: Firebase Firestore
- Unlimited history
- Cloud backup
- Multi-location aggregation

**Charts**: Advanced
- Multi-device comparison
- Statistical reports
- Predictive analytics

---

## 📊 Complete Analytics Examples

### Mobile App - Device Detail Screen

```dart
class DeviceDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Current reading
          _CurrentReading(),
          
          // Historical chart
          _TemperatureChart(),
          
          // Controls
          _ControlButtons(),
          
          // Statistics
          _StatisticsCard(),
        ],
      ),
    );
  }
}

class _CurrentReading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: GaugeChart(
              value: 24.5,
              min: 15,
              max: 35,
              label: 'Temperature',
              unit: '°C',
            ),
          ),
          Expanded(
            child: GaugeChart(
              value: 62,
              min: 30,
              max: 100,
              label: 'Humidity',
              unit: '%',
            ),
          ),
        ],
      ),
    );
  }
}

class _TemperatureChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: LineChart(...),  // Historical temperature
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text('Last 24 Hours'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatItem('Avg Temp', '24.2°C'),
              StatItem('Min Temp', '22.1°C'),
              StatItem('Max Temp', '27.8°C'),
              StatItem('In Range', '94%'),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

### Admin Dashboard - Analytics Screen

```dart
class AdminAnalyticsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Analytics')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // System overview cards
            _OverviewCards(),
            
            // Multi-device comparison chart
            _ComparisonChart(),
            
            // Statistical reports
            _StatisticsTable(),
            
            // Alerts list
            _AlertsList(),
          ],
        ),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      children: [
        StatCard('Total Devices', '20', Colors.blue),
        StatCard('Online Now', '18 (90%)', Colors.green),
        StatCard('Active Users', '12', Colors.purple),
        StatCard('Today Alerts', '3', Colors.orange),
      ],
    );
  }
}
```

---

## 🔗 Next Steps

**For Now:**
- Keep MQTT-only setup (works fine!)
- Add in-memory charts (last 100 readings)

**When Ready (Optional):**
- Set up InfluxDB on Raspberry Pi
- Store historical data
- Add advanced analytics

**Much Later:**
- Migrate to Firebase
- Add predictive analytics
- Generate automated reports

---

**Summary**: Your system works great without a database! Add charts first (in-memory), then storage (InfluxDB) when you need historical data!

