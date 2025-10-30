# HiveMQ Cloud - Complete Implementation Guide for ALMED AHU System

**Comprehensive Guide to Cloud MQTT with HiveMQ**  
**Last Updated**: October 30, 2025  
**Version**: 2.0 - Hybrid Architecture Edition

---

## 🏗️ Architecture Overview

**ALMED AHU System - Hybrid Local + Cloud Architecture**

```
Priority 1: LOCAL SYSTEM (Ground Level - Primary)
┌─────────────────────────────────────────────────────┐
│                                                      │
│  ESP32 Sensors ──→ Raspberry Pi Mosquitto          │
│                    (10.42.0.1:1883)                 │
│                           │                          │
│                           ↓                          │
│                    Flutter Dashboard                 │
│                    (Local Desktop)                   │
│                                                      │
│  ✓ Real-time control                                │
│  ✓ Low latency (<10ms)                             │
│  ✓ Works without internet                          │
│  ✓ Primary operational system                      │
└─────────────────────────────────────────────────────┘

Priority 2: CLOUD SYSTEM (Remote Access - Secondary)
┌─────────────────────────────────────────────────────┐
│                                                      │
│  ESP32 Sensors ──→ HiveMQ Cloud                     │
│                    (abc123.hivemq.cloud:8883)       │
│                           │                          │
│                           ↓                          │
│                    Mobile App (Flutter)             │
│                    (Android/iOS)                    │
│                                                      │
│  ✓ Remote monitoring                                │
│  ✓ Control from anywhere                           │
│  ✓ Higher latency (50-200ms)                       │
│  ✓ Requires internet                               │
│  ✓ Backup/secondary system                         │
└─────────────────────────────────────────────────────┘
```

**Implementation Strategy**: 
- ESP32 publishes to BOTH brokers simultaneously
- Local dashboard connects to Raspberry Pi only
- Mobile app connects to HiveMQ Cloud only
- No changes needed to existing local dashboard

---

# Table of Contents

1. [Introduction to HiveMQ Cloud](#introduction-to-hivemq-cloud)
2. [Hybrid Architecture Explained](#hybrid-architecture-explained)
3. [Understanding MQTT Broker Architecture](#understanding-mqtt-broker-architecture)
4. [Why HiveMQ for Hospital IoT](#why-hivemq-for-hospital-iot)
5. [Account Setup - Step by Step](#account-setup---step-by-step)
6. [Cluster Configuration](#cluster-configuration)
7. [ESP32 Dual-Broker Implementation](#esp32-dual-broker-implementation)
8. [Local Dashboard (No Changes)](#local-dashboard-no-changes)
9. [Mobile App Development](#mobile-app-development)
10. [TLS/SSL Security Explained](#tlsssl-security-explained)
11. [MQTT Topics Architecture](#mqtt-topics-architecture)
12. [Testing and Debugging](#testing-and-debugging)
13. [Production Deployment](#production-deployment)
14. [Monitoring and Maintenance](#monitoring-and-maintenance)
15. [Troubleshooting Guide](#troubleshooting-guide)
16. [Advanced Configurations](#advanced-configurations)
17. [Cost Optimization](#cost-optimization)
18. [Real-World Scenarios](#real-world-scenarios)

---

# Hybrid Architecture Explained

## System Priorities

Your ALMED AHU system uses a **dual-broker hybrid architecture** with clear priorities:

### Priority 1: Local System (Ground Level) - PRIMARY

**Purpose**: Operational control and monitoring at the hospital premises

**Components**:
- ESP32 sensor boxes
- Raspberry Pi with Mosquitto broker (10.42.0.1:1883)
- Flutter desktop dashboard (Linux/Windows)
- Local WiFi hotspot (PiSpot)

**Characteristics**:
- ✅ **Ultra-low latency** (<10ms)
- ✅ **No internet dependency** - works during outages
- ✅ **High reliability** - local network control
- ✅ **Real-time control** - instant command response
- ✅ **Primary operational system** - mission-critical

**Use Cases**:
- Staff on-site monitoring AHU status
- Quick adjustments to temperature/humidity
- Real-time alerts and logs
- System configuration and provisioning

### Priority 2: Cloud System (Mobile App) - SECONDARY

**Purpose**: Remote monitoring and control when away from hospital

**Components**:
- ESP32 sensor boxes (same devices)
- HiveMQ Cloud broker (abc123.hivemq.cloud:8883)
- Flutter mobile app (Android/iOS)
- Internet connection required

**Characteristics**:
- ✅ **Global access** - control from anywhere
- ✅ **Mobile convenience** - phone/tablet access
- ✅ **Backup monitoring** - when away from premises
- ⚠️ **Internet required** - depends on connectivity
- ⚠️ **Higher latency** (50-200ms) - acceptable for monitoring

**Use Cases**:
- Hospital manager checking status from home
- Maintenance team monitoring during off-hours
- Remote troubleshooting
- Mobile notifications and alerts

---

## Architecture Diagram

### Complete System Overview

```
                    ┌──────────────────────────────────────┐
                    │         ESP32 Sensor Box              │
                    │         (ahu-01)                      │
                    │                                       │
                    │  • Reads temp/humidity                │
                    │  • Controls motors                    │
                    │  • Connects to WiFi                   │
                    │  • Publishes to BOTH brokers          │
                    └───────────┬──────────────┬────────────┘
                                │              │
                    ┌───────────┘              └───────────┐
                    │                                      │
                    ↓                                      ↓
    ┌───────────────────────────────┐    ┌───────────────────────────────┐
    │  LOCAL BROKER (Priority 1)    │    │  CLOUD BROKER (Priority 2)    │
    │  Raspberry Pi Mosquitto       │    │  HiveMQ Cloud                 │
    │  IP: 10.42.0.1                │    │  URL: abc123.hivemq.cloud     │
    │  Port: 1883 (Plain)           │    │  Port: 8883 (TLS)             │
    │  Network: Local WiFi          │    │  Network: Internet            │
    └───────────────┬───────────────┘    └───────────────┬───────────────┘
                    │                                      │
                    ↓                                      ↓
    ┌───────────────────────────────┐    ┌───────────────────────────────┐
    │  FLUTTER DASHBOARD            │    │  FLUTTER MOBILE APP           │
    │  (Desktop - Linux/Windows)    │    │  (Android/iOS)                │
    │                               │    │                               │
    │  • Connected to LOCAL only    │    │  • Connected to CLOUD only    │
    │  • Full control interface     │    │  • Remote monitoring          │
    │  • Real-time monitoring       │    │  • Mobile-optimized UI        │
    │  • On-site use                │    │  • Use anywhere               │
    │  • NO CHANGES NEEDED          │    │  • NEW APPLICATION            │
    └───────────────────────────────┘    └───────────────────────────────┘
```

---

## How Dual-Broker Publishing Works

### ESP32 Connection Strategy

The ESP32 will connect to **BOTH** brokers and publish messages to both:

```cpp
// Two separate MQTT client objects
WiFiClient espNetLocal;              // For Raspberry Pi
PubSubClient mqttLocal(espNetLocal);

WiFiClientSecure espNetCloud;        // For HiveMQ Cloud
PubSubClient mqttCloud(espNetCloud);

// Publish telemetry to BOTH
void publishTelemetry(float temp, float hum) {
  String payload = createJsonPayload(temp, hum);
  
  // Publish to local broker
  if (mqttLocal.connected()) {
    mqttLocal.publish(tTelemetry().c_str(), payload.c_str());
  }
  
  // Publish to cloud broker
  if (mqttCloud.connected()) {
    mqttCloud.publish(tTelemetry().c_str(), payload.c_str());
  }
}
```

### Connection Priority Logic

```cpp
void loop() {
  // LOCAL CONNECTION (Priority 1)
  if (!mqttLocal.connected()) {
    reconnectLocal();  // Try to reconnect immediately
  }
  mqttLocal.loop();    // Process local messages first
  
  // CLOUD CONNECTION (Priority 2)
  if (!mqttCloud.connected()) {
    reconnectCloud();  // Try to reconnect (lower priority)
  }
  mqttCloud.loop();    // Process cloud messages second
  
  // If local fails, system still works (can control via cloud)
  // If cloud fails, local system continues normally
}
```

---

## Benefits of Hybrid Architecture

### 1. **Reliability**
- Local system works even without internet
- Cloud system provides backup access
- Either system can control the AHU

### 2. **Flexibility**
- On-site staff use fast local dashboard
- Remote staff use mobile app
- Both see same data in real-time

### 3. **Performance**
- Local system: <10ms latency (critical for operations)
- Cloud system: 50-200ms (acceptable for monitoring)

### 4. **Gradual Migration**
- Keep local system as-is (no disruption)
- Add cloud functionality when ready
- Test cloud system without affecting operations

### 5. **Cost-Effective**
- Free local broker (Raspberry Pi)
- Free cloud broker (HiveMQ Cloud free tier)
- Mobile app built with existing Flutter codebase

---

## Implementation Phases

### Phase 1: Current System (✅ Complete)
- ESP32 → Raspberry Pi Mosquitto
- Flutter desktop dashboard
- Local-only operation

### Phase 2: Add Cloud Publishing (Next Step)
- ESP32 → Raspberry Pi + HiveMQ Cloud
- Flutter desktop dashboard (no changes)
- Dual-broker setup on ESP32

### Phase 3: Develop Mobile App (Future)
- Create new Flutter mobile project
- Connect to HiveMQ Cloud only
- Mobile-optimized interface
- Android/iOS builds

### Phase 4: Testing & Deployment
- Test mobile app with cloud connection
- Deploy to staff phones/tablets
- Monitor both systems in parallel

---

# Introduction to HiveMQ Cloud

## What is HiveMQ Cloud?

HiveMQ Cloud is a **fully managed MQTT broker** service that provides enterprise-grade messaging infrastructure without the need to manage servers, scaling, or maintenance. It's specifically designed for IoT applications like your hospital AHU control system.

### Key Concepts

**MQTT (Message Queuing Telemetry Transport)**:
- Lightweight publish/subscribe messaging protocol
- Designed for IoT devices with limited bandwidth
- Reliable message delivery with QoS levels
- Perfect for remote device communication

**Broker**:
- Central hub that receives and routes all messages
- Manages client connections
- Handles message persistence and delivery guarantees
- Enforces security policies

**Publish/Subscribe Model**:
```
ESP32 (Publisher) → Topic: "almed/ahu/hospitalA/icu1/ahu-01/telemetry"
                           ↓
                    HiveMQ Cloud Broker
                           ↓
                    Topic: "almed/ahu/hospitalA/icu1/ahu-01/telemetry"
                           ↓
Flutter Dashboard (Subscriber) ← Receives telemetry data
```

### HiveMQ vs Self-Hosted Mosquitto

| Feature | HiveMQ Cloud | Self-Hosted Mosquitto |
|---------|-------------|---------------------|
| **Setup Time** | 5 minutes | 1-2 hours |
| **Maintenance** | Zero (managed) | Weekly updates required |
| **Scaling** | Automatic | Manual configuration |
| **Uptime** | 99.9% SLA | Depends on your infrastructure |
| **Security** | Built-in TLS, ACLs | Manual configuration |
| **Monitoring** | Built-in dashboard | Need separate tools |
| **Backup** | Automatic | Manual setup |
| **Cost** | Free (100 devices) | Free but requires server |
| **Remote Access** | Global | Need VPN or port forwarding |

---

# Understanding MQTT Broker Architecture

## How MQTT Works in Your AHU System

### Message Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    HiveMQ Cloud Broker                       │
│                 (abc123.s2.eu.hivemq.cloud:8883)            │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Topic Registry                          │   │
│  │  almed/ahu/hospitalA/icu1/ahu-01/telemetry         │   │
│  │  almed/ahu/hospitalA/icu1/ahu-01/state             │   │
│  │  almed/ahu/hospitalA/icu1/ahu-01/cmd               │   │
│  │  almed/ahu/hospitalA/icu1/ahu-01/log               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         Connected Clients Registry                   │   │
│  │  • ahu-01 (ESP32) - Online                          │   │
│  │  • ahu-02 (ESP32) - Online                          │   │
│  │  • ahu_dashboard_12345 (Flutter) - Online           │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
          ↑                                    ↓
          │                                    │
    TLS/SSL (8883)                       TLS/SSL (8883)
          │                                    │
          │                                    │
┌─────────┴─────────┐              ┌───────────┴──────────┐
│   ESP32 Device    │              │  Flutter Dashboard   │
│   (ahu-01)        │              │  (Your Phone/PC)     │
│                   │              │                      │
│ • Publishes:      │              │ • Subscribes:        │
│   - telemetry     │              │   - almed/ahu/#      │
│   - state         │              │                      │
│   - log           │              │ • Publishes:         │
│                   │              │   - cmd              │
│ • Subscribes:     │              │   - provision/*      │
│   - cmd           │              │                      │
│   - provision/*   │              │                      │
└───────────────────┘              └──────────────────────┘
```

### MQTT QoS (Quality of Service) Levels

**QoS 0 - At most once**:
- Fire and forget
- No acknowledgment
- Fast but may lose messages
- Use for: Non-critical telemetry updates

**QoS 1 - At least once** (Your system uses this):
- Guaranteed delivery
- May receive duplicates
- Acknowledged by broker
- Use for: Commands, critical telemetry

**QoS 2 - Exactly once**:
- Guaranteed single delivery
- Slower (4-way handshake)
- Use for: Critical commands only

Your AHU system uses **QoS 1** for balance between reliability and performance.

### Retained Messages

```cpp
// ESP32 publishes status with retained flag
mqtt.publish(tStatus().c_str(), "online", true); // retained = true
```

**What "retained" means**:
- Broker stores the last message
- New subscribers immediately get last value
- Perfect for device status
- Your system uses this for:
  - Device online/offline status
  - Last known state

---

# Why HiveMQ for Hospital IoT

## Critical Requirements for Hospital Systems

### 1. Reliability

**Hospital Requirements**:
- 99.9%+ uptime
- No single point of failure
- Automatic failover
- Data integrity

**HiveMQ Delivers**:
- 99.99% SLA (Professional tier)
- Clustered architecture
- Automatic health monitoring
- Persistent message queues

### 2. Security

**Hospital Requirements**:
- HIPAA compliance considerations
- Encrypted data transmission
- Access control
- Audit logging

**HiveMQ Delivers**:
- TLS 1.3 encryption
- Username/password authentication
- Per-topic ACLs (Pro tier)
- Connection audit logs

### 3. Scalability

**Your Growth Path**:
```
Phase 1: Pilot (10 AHU units)
  ↓ HiveMQ Free Tier (100 connections)
  
Phase 2: Single Hospital (50 units)
  ↓ HiveMQ Starter ($49/month)
  
Phase 3: Hospital Network (500 units)
  ↓ HiveMQ Professional ($149/month)
  
Phase 4: Multi-Hospital (2000+ units)
  ↓ HiveMQ Enterprise (Custom pricing)
```

### 4. Low Latency

**Critical for AHU Control**:
- Emergency stop commands must be instant
- Temperature alerts need immediate delivery
- Real-time dashboard updates

**HiveMQ Performance**:
- <50ms message delivery (same region)
- <200ms global delivery
- Optimized for IoT traffic patterns

### 5. Easy Maintenance

**Hospital IT Constraints**:
- Limited staff
- 24/7 operations
- No downtime windows

**HiveMQ Advantage**:
- Zero maintenance required
- Automatic updates
- No server management
- Built-in monitoring

---

# Account Setup - Step by Step

## Step 1: Create HiveMQ Account

### 1.1 Navigate to HiveMQ Cloud

Open browser and go to:
```
https://www.hivemq.com/mqtt-cloud-broker/
```

### 1.2 Sign Up Process

**Click "Get Started for Free"**

You'll see a signup form:
```
┌─────────────────────────────────────┐
│  Create Your HiveMQ Cloud Account   │
├─────────────────────────────────────┤
│  Email: [your-email@hospital.com]   │
│  Password: [••••••••••••••••]       │
│  Confirm Password: [••••••••••]     │
│                                      │
│  [ ] I agree to Terms of Service    │
│                                      │
│        [Create Free Account]         │
└─────────────────────────────────────┘
```

**Best Practices**:
- Use your organization email (e.g., `almed-iot@hospital.com`)
- Create a strong password (20+ characters)
- Store credentials in password manager
- Enable 2FA if available

### 1.3 Email Verification

Check your email for verification link:
```
Subject: Verify your HiveMQ Cloud account

Click the link below to verify your email:
https://console.hivemq.cloud/verify?token=abc123...

Link expires in 24 hours.
```

Click the link to activate your account.

### 1.4 First Login

After verification, you'll see the HiveMQ Cloud Console:
```
┌────────────────────────────────────────────────────┐
│  HiveMQ Cloud Console                              │
├────────────────────────────────────────────────────┤
│                                                     │
│  Welcome to HiveMQ Cloud!                          │
│                                                     │
│  You don't have any clusters yet.                  │
│                                                     │
│         [+ Create Your First Cluster]              │
│                                                     │
│  What is a cluster?                                │
│  A cluster is your MQTT broker instance that       │
│  handles all device connections and messages.      │
│                                                     │
└────────────────────────────────────────────────────┘
```

---

## Step 2: Create MQTT Cluster

### 2.1 Choose Plan

Click **"Create Your First Cluster"**

You'll see plan options:
```
┌───────────────────────────────────────────────────────────┐
│              Choose Your Plan                              │
├───────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  SERVERLESS  │  │   STARTER    │  │ PROFESSIONAL │   │
│  │     FREE     │  │  $49/month   │  │  $149/month  │   │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤   │
│  │ 100 clients  │  │ 1K clients   │  │ 10K clients  │   │
│  │ No card req. │  │ Persistence  │  │ High Avail.  │   │
│  │ Basic        │  │ Support      │  │ 24/7 Support │   │
│  │              │  │              │  │              │   │
│  │  [Select]    │  │  [Select]    │  │  [Select]    │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└───────────────────────────────────────────────────────────┘
```

**Select "SERVERLESS (FREE)"** for testing/pilot deployment.

### 2.2 Configure Cluster

After selecting plan:
```
┌─────────────────────────────────────────────────┐
│  Configure Your Cluster                         │
├─────────────────────────────────────────────────┤
│                                                  │
│  Cluster Name:                                   │
│  [almed-ahu-production]                         │
│                                                  │
│  Region:                                         │
│  ( ) North America - East (us-east-1)           │
│  ( ) North America - West (us-west-2)           │
│  (•) Europe - Central (eu-central-1)            │
│  ( ) Asia Pacific - Singapore (ap-southeast-1)  │
│  ( ) Asia Pacific - Mumbai (ap-south-1)         │
│                                                  │
│  Cloud Provider:                                 │
│  [AWS ▼]                                        │
│                                                  │
│        [Cancel]  [Create Cluster]               │
└─────────────────────────────────────────────────┘
```

**Configuration Tips**:

**Cluster Name**:
- Use descriptive name: `almed-ahu-production`
- Or by location: `almed-hospital-mumbai`
- Avoid generic names: `test`, `cluster1`

**Region Selection**:
- Choose **closest to your hospital location**
- Lower latency = faster response
- Examples:
  - India hospitals → `ap-south-1` (Mumbai)
  - Europe hospitals → `eu-central-1` (Frankfurt)
  - US hospitals → `us-east-1` (Virginia)

**Cloud Provider**:
- AWS is default and recommended
- Doesn't affect functionality

### 2.3 Cluster Creation

After clicking "Create Cluster", you'll see:
```
┌─────────────────────────────────────┐
│  Creating Your Cluster...           │
│                                      │
│  [████████░░░░░░░░░░] 45%          │
│                                      │
│  • Provisioning infrastructure      │
│  • Configuring security            │
│  • Setting up monitoring           │
│                                      │
│  This usually takes 2-3 minutes.    │
└─────────────────────────────────────┘
```

Wait 2-3 minutes for completion.

### 2.4 Cluster Ready

Once created, you'll see:
```
┌───────────────────────────────────────────────────┐
│  ✓ Cluster Created Successfully!                  │
├───────────────────────────────────────────────────┤
│                                                    │
│  Cluster Name: almed-ahu-production               │
│  Status: ● Running                                 │
│                                                    │
│  Connection Details:                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  Host: abc123def456.s2.eu.hivemq.cloud           │
│  Port (MQTT): 8883                                │
│  Port (WebSocket): 8884                           │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                    │
│  ⚠️ Important: Save your cluster URL!            │
│                                                    │
│  Next Step: Create credentials to connect devices │
│                                                    │
│        [Go to Access Management →]                │
└───────────────────────────────────────────────────┘
```

**IMPORTANT**: Copy and save your cluster URL:
```
abc123def456.s2.eu.hivemq.cloud
```

You'll need this for ESP32 and Flutter configuration.

---

## Step 3: Create Credentials

### 3.1 Navigate to Access Management

Click **"Access Management"** in left sidebar:
```
┌────────────────────────────────────┐
│  ≡ HiveMQ Cloud Console            │
├────────────────────────────────────┤
│  🏠 Dashboard                      │
│  📊 Clusters                       │
│  🔐 Access Management      ←       │
│  📈 Metrics                        │
│  ⚙️  Settings                      │
│  💳 Billing                        │
│  📚 Documentation                  │
└────────────────────────────────────┘
```

### 3.2 Add New Credentials

You'll see:
```
┌─────────────────────────────────────────────────┐
│  Access Management                              │
│  Cluster: almed-ahu-production                  │
├─────────────────────────────────────────────────┤
│                                                  │
│  Credentials (0)                                │
│                                                  │
│  No credentials yet. Add your first credential  │
│  to allow devices to connect.                   │
│                                                  │
│        [+ Add Credentials]                      │
└─────────────────────────────────────────────────┘
```

Click **"Add Credentials"**

### 3.3 Create Username and Password

```
┌─────────────────────────────────────────┐
│  Add New Credentials                     │
├─────────────────────────────────────────┤
│                                          │
│  Username:                               │
│  [almed]                                 │
│                                          │
│  Password:                               │
│  [AlmedHospital2025!#Secure]            │
│                                          │
│  Permissions: (Available in Pro tier)    │
│  (•) Full Access                         │
│  ( ) Read Only                           │
│  ( ) Custom Topics                       │
│                                          │
│       [Cancel]  [Add Credential]         │
└─────────────────────────────────────────┘
```

**Credential Best Practices**:

**Username**:
- Use organization name: `almed`
- Or by function: `almed-devices`, `almed-dashboard`
- Keep it simple and memorable

**Password**:
- **CRITICAL**: Use strong passwords for production!
- Minimum 16 characters
- Include: uppercase, lowercase, numbers, symbols
- Generate with: `openssl rand -base64 24`
- Example strong password: `8mK#vPq2@nL9wX5$yT3!rB7`

**Security Levels**:

❌ **WEAK** (Don't use):
- `almed123`
- `hospital`
- `password`

⚠️ **MEDIUM** (Testing only):
- `Almed1234$`
- `Hospital2025`

✅ **STRONG** (Production):
- `AlmedHospital2025!#Secure8mK`
- `8mK#vPq2@nL9wX5$yT3!rB7`

### 3.4 Save Credentials

After clicking "Add Credential":
```
┌─────────────────────────────────────────────────┐
│  ✓ Credential Created Successfully!             │
├─────────────────────────────────────────────────┤
│                                                  │
│  Username: almed                                │
│  Password: ••••••••••••••••••••••              │
│                                                  │
│  ⚠️ IMPORTANT: Save these credentials now!     │
│  You won't be able to see the password again.  │
│                                                  │
│  [📋 Copy Username]  [📋 Copy Password]        │
│                                                  │
│        [Done]                                   │
└─────────────────────────────────────────────────┘
```

**Save these securely**:
```
HiveMQ Cloud Credentials - ALMED AHU Production
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cluster URL: abc123def456.s2.eu.hivemq.cloud
Port (MQTT/TLS): 8883
Port (WebSocket/TLS): 8884
Username: almed
Password: AlmedHospital2025!#Secure
Created: 2025-10-29
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Store in:
- Password manager (1Password, LastPass, etc.)
- Encrypted document
- Secure company vault

---

## Step 4: Test Connection

### 4.1 Using Mosquitto Client (Linux/Mac)

Open terminal on your Raspberry Pi or development machine:

```bash
# Test publish
mosquitto_pub \
  -h abc123def456.s2.eu.hivemq.cloud \
  -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed \
  -P "AlmedHospital2025!#Secure" \
  -t "almed/test" \
  -m "Hello from HiveMQ Cloud!" \
  -d

# Expected output:
# Client null sending CONNECT
# Client null received CONNACK (0)
# Client null sending PUBLISH (d0, q0, r0, m1, 'almed/test', ... (26 bytes))
# Client null sending DISCONNECT
```

### 4.2 Test Subscribe (Different Terminal)

```bash
mosquitto_sub \
  -h abc123def456.s2.eu.hivemq.cloud \
  -p 8883 \
  --capath /etc/ssl/certs/ \
  -u almed \
  -P "AlmedHospital2025!#Secure" \
  -t "almed/#" \
  -v \
  -d

# Expected output:
# Client null sending CONNECT
# Client null received CONNACK (0)
# Client null sending SUBSCRIBE (Mid: 1, Topic: almed/#, QoS: 0)
# Client null received SUBACK
# Subscribed (mid: 1): 0
# (waiting for messages...)
```

Now publish a message (in first terminal), you should see it appear in the subscriber.

### 4.3 Connection Troubleshooting

**Error: "Connection refused"**
```bash
# Error output:
Error: Connection refused

# Solution:
# 1. Check cluster URL is correct
# 2. Verify port 8883 (not 1883)
# 3. Check firewall allows outbound 8883
```

**Error: "Authentication failed"**
```bash
# Error output:
Connection refused: not authorized.

# Solution:
# 1. Verify username/password (case-sensitive)
# 2. Check credentials in HiveMQ console
# 3. Regenerate credentials if needed
```

**Error: "Certificate verify failed"**
```bash
# Error output:
SSL handshake failed: certificate verify failed

# Solution:
# 1. Update CA certificates:
sudo apt update
sudo apt install ca-certificates
sudo update-ca-certificates

# 2. Or specify CA path:
--capath /etc/ssl/certs/
```

---

# Cluster Configuration

## Understanding Your Cluster

### Cluster Dashboard Overview

```
┌────────────────────────────────────────────────────────┐
│  almed-ahu-production                                  │
│  Status: ● Running                                      │
├────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │  Connections    │  │  Messages/sec   │            │
│  │      2          │  │      15.3       │            │
│  └─────────────────┘  └─────────────────┘            │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │  Uptime         │  │  Data Transfer  │            │
│  │   23h 45m       │  │    1.2 MB       │            │
│  └─────────────────┘  └─────────────────┘            │
│                                                         │
│  Recent Activity:                                      │
│  • 10:23 AM - Client ahu-01 connected                 │
│  • 10:22 AM - Client ahu_dashboard_123 connected      │
│  • 10:20 AM - Started                                 │
│                                                         │
└────────────────────────────────────────────────────────┘
```

### Cluster Settings

Access via **Settings** button:

```
┌─────────────────────────────────────────────────┐
│  Cluster Settings                               │
├─────────────────────────────────────────────────┤
│                                                  │
│  Basic Information:                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  Name: almed-ahu-production                     │
│  Created: Oct 29, 2025                          │
│  Region: eu-central-1 (Frankfurt)               │
│  Plan: Serverless (Free)                        │
│                                                  │
│  Connection Limits:                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  Max Connections: 100                           │
│  Current: 2/100 (2%)                            │
│  Max Message Rate: Unlimited                    │
│                                                  │
│  Security:                                      │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  [✓] TLS 1.3 Encryption                        │
│  [✓] Username/Password Auth                    │
│  [ ] Client Certificates (Pro)                 │
│  [ ] Topic ACLs (Pro)                          │
│                                                  │
│  [Upgrade to Pro]  [Delete Cluster]            │
└─────────────────────────────────────────────────┘
```

---

# ESP32 Dual-Broker Implementation

## Complete Code Walkthrough

**IMPORTANT**: This implementation adds cloud connectivity while keeping your local system unchanged.

### File Structure
```
esp32_main/
├── esp32_main.ino          # Main code (you'll modify this)
└── (libraries managed by Arduino IDE)
```

### Required Libraries

Add to Arduino IDE via Library Manager:
```cpp
// Library Manager → Install these:
1. WiFiClientSecure (Built-in with ESP32)
2. PubSubClient by Nick O'Leary (v2.8+)
3. ArduinoJson by Benoit Blanchon (v7.0+)
4. Adafruit SHT4x Library
5. Adafruit Unified Sensor
```

### Implementation Strategy

**What we're doing**:
- ✅ Keep existing local MQTT connection (WiFiClient → Raspberry Pi)
- ✅ Add new cloud MQTT connection (WiFiClientSecure → HiveMQ Cloud)
- ✅ Publish to BOTH brokers simultaneously
- ✅ Subscribe to commands from BOTH brokers
- ✅ Local dashboard continues working unchanged

### Step-by-Step Code Changes

#### Change 1: Add WiFiClientSecure Include

**Location**: Top of file (line ~1-7)

**OLD CODE**:
```cpp
#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_SHT4x.h>
```

**NEW CODE**:
```cpp
#include <WiFi.h>
#include <WiFiClientSecure.h>  // ← ADD THIS LINE for cloud connection
#include <Wire.h>
#include <Adafruit_SHT4x.h>
```

**Why**:
- `WiFiClient` = Plain TCP for local Raspberry Pi (port 1883)
- `WiFiClientSecure` = TLS/SSL for HiveMQ Cloud (port 8883)
- We need BOTH for dual-broker setup

---

#### Change 2: Create TWO MQTT Client Objects

**Location**: Line ~92-94

**OLD CODE** (Single broker):
```cpp
// ---------- MQTT ----------
WiFiClient espNet;
PubSubClient mqtt(espNet);
```

**NEW CODE** (Dual broker):
```cpp
// ---------- MQTT LOCAL (Priority 1: Raspberry Pi) ----------
WiFiClient espNetLocal;
PubSubClient mqttLocal(espNetLocal);

// ---------- MQTT CLOUD (Priority 2: HiveMQ Cloud) ----------
WiFiClientSecure espNetCloud;
PubSubClient mqttCloud(espNetCloud);
```

**Detailed Explanation**:

The `PubSubClient` library wraps any client object that provides:
- `connect()` - Establish connection
- `write()` - Send data
- `read()` - Receive data
- `available()` - Check for data

Both `WiFiClient` and `WiFiClientSecure` provide these methods, but:

**WiFiClient** (Plain):
```
ESP32 ←──────────→ Mosquitto
     TCP Port 1883
     (unencrypted)
```

**WiFiClientSecure** (TLS):
```
ESP32 ←═══════════════════→ HiveMQ Cloud
     TLS/SSL Port 8883
     (encrypted)
     
     Handshake:
     1. Client Hello
     2. Server Hello + Certificate
     3. Key Exchange
     4. Encrypted tunnel established
```

---

#### Change 3: MQTT Credentials

**Location**: Line ~96-98

**OLD CODE**:
```cpp
const char* MQTT_USER = "almed";
const char* MQTT_PASS = "Almed1234$";
uint16_t MQTT_PORT = 1883;
```

**NEW CODE**:
```cpp
const char* MQTT_USER = "almed";
const char* MQTT_PASS = "AlmedHospital2025!#Secure";  // ← Your HiveMQ password
uint16_t MQTT_PORT = 8883;  // ← Changed from 1883 to 8883
```

**Why Port 8883**:
- Port 1883: Standard MQTT (no encryption)
- Port 8883: MQTT over TLS (encrypted)
- Port 8884: MQTT over WebSocket + TLS (for browsers)

HiveMQ Cloud **only** accepts port 8883 (TLS required).

---

#### Change 4: Broker Host

**Location**: Line ~123

**OLD CODE**:
```cpp
String mqttHost = "10.42.0.1";  // Local Raspberry Pi
```

**NEW CODE**:
```cpp
String mqttHost = "abc123def456.s2.eu.hivemq.cloud";  // ← Your cluster URL
```

**IMPORTANT**: Replace `abc123def456.s2.eu.hivemq.cloud` with YOUR actual cluster URL from HiveMQ console!

**How to find your cluster URL**:
1. Go to HiveMQ Cloud console
2. Click on your cluster
3. See "Host" under Connection Details
4. Copy the full URL (without `mqtt://` or `mqtts://`)

---

#### Change 5: TLS Configuration in Setup

**Location**: In `setup()` function, after WiFi event handler (around line 743)

**ADD THIS CODE**:
```cpp
// ========== TLS/SSL CONFIGURATION ==========
espNet.setInsecure();  // Skip certificate validation
Serial.println("✓ TLS/SSL configured for cloud MQTT");
```

**Detailed Explanation**:

**What is `.setInsecure()`?**

By default, `WiFiClientSecure` validates the server's TLS certificate against known Certificate Authorities (CAs). This is secure but requires:
1. Storing CA certificates in ESP32 flash
2. Keeping certificates updated
3. More complex code

`.setInsecure()` tells ESP32: "Accept any certificate without validation"

**Security Trade-offs**:

✅ **Pros**:
- Simple implementation
- No certificate management
- Works immediately
- Still encrypted connection

⚠️ **Cons**:
- Vulnerable to Man-in-the-Middle (MITM) attacks
- Not recommended for production

**Production Alternative** (More Secure):

```cpp
// Get HiveMQ root certificate from:
// https://letsencrypt.org/certs/isrgrootx1.pem
const char* hivemq_root_ca = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
... (rest of certificate)
-----END CERTIFICATE-----
)EOF";

void setup() {
  // ... existing code ...
  
  // Use certificate validation (SECURE)
  espNet.setCACert(hivemq_root_ca);
  Serial.println("✓ TLS/SSL with certificate validation configured");
}
```

For now, use `.setInsecure()` for testing, then switch to certificate validation for production.

---

### Complete Modified ESP32 Code Section

Here's the complete section with all changes:

```cpp
// ==================== CLOUD MQTT CONFIGURATION ====================
#include <WiFi.h>
#include <WiFiClientSecure.h>  // ← ADDED FOR TLS
#include <Wire.h>
#include <Adafruit_SHT4x.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <esp_task_wdt.h>

// ... (keep all motor timings, watchdog config, WiFi defaults)

// ---------- MQTT ----------
WiFiClientSecure espNet;  // ← CHANGED TO SECURE
PubSubClient mqtt(espNet);

const char* MQTT_USER = "almed";
const char* MQTT_PASS = "AlmedHospital2025!#Secure";  // ← YOUR PASSWORD
uint16_t MQTT_PORT = 8883;  // ← CHANGED TO TLS PORT

const char* ORG  = "almed";
const char* SITE = "hospitalA";
const char* ROOM = "icu1";
const char* AHU  = "ahu-01";

// ... (topic functions stay the same)

// ---------- Preferences ----------
Preferences prefs;
String w1_ssid, w1_pass, w2_ssid, w2_pass;
String mqttHost = "abc123def456.s2.eu.hivemq.cloud";  // ← YOUR CLUSTER URL

// ... (rest of code stays the same until setup())

void setup(){
  Serial.begin(115200);
  delay(500);
  
  // ... (existing watchdog, pins, sensor setup)
  
  // ========== TLS/SSL CONFIGURATION ==========
  espNet.setInsecure();  // ← ADDED FOR TLS
  Serial.println("✓ TLS/SSL configured for cloud MQTT");
  
  // ... (rest of setup)
}

// loop() function - NO CHANGES NEEDED
```

---

### Upload and Test

#### 1. Verify Configuration

Before uploading, double-check:
```cpp
✓ WiFiClientSecure included
✓ WiFiClientSecure espNet declared
✓ MQTT_PORT = 8883
✓ MQTT_PASS = your HiveMQ password
✓ mqttHost = your cluster URL
✓ espNet.setInsecure() in setup()
```

#### 2. Upload to ESP32

1. Connect ESP32 via USB
2. Select board: **Tools → Board → ESP32 Dev Module**
3. Select port: **Tools → Port → /dev/ttyUSB0** (or your port)
4. Click **Upload** (→ button)

#### 3. Open Serial Monitor

**Tools → Serial Monitor** (or Ctrl+Shift+M)

Set baud rate to **115200**

#### 4. Expected Output

```
========================================
   ALMED AHU Controller v2.0
   Watchdog Protection Enabled
========================================
✓ Watchdog enabled (7s timeout)
✓ SHT45 ready
✓ Motor timings loaded:
  M1 Start: 10s
  M1 Post: 10s
  M2 Interval: 30s
  M2 Run: 10s
  M2 Delay: 5s
✓ WiFi event handler registered
✓ TLS/SSL configured for cloud MQTT  ← NEW LINE

--- Checking for previous state ---

✓ Boot complete. Ready for commands.
  Temp setpoint: 22.0°C
  Humidity setpoint: 55.0%
========================================

Wi-Fi: trying PRIMARY SSID: PiSpot
Wi-Fi connected (PRIMARY), IP: 192.168.1.100
MQTT connected to abc123def456.s2.eu.hivemq.cloud:8883  ← CLOUD CONNECTION!
Temp: 24.5 °C | Hum: 62.0%
```

**Success Indicators**:
✅ "TLS/SSL configured"
✅ "MQTT connected to [your-cluster-url]:8883"
✅ Telemetry messages flowing

#### 5. Troubleshooting Upload Errors

**Error: "A fatal error occurred: Failed to connect"**
```bash
Solution:
1. Hold BOOT button on ESP32
2. Click Upload
3. Release BOOT when "Connecting..." appears
```

**Error: "Connection refused"**
```bash
Check Serial Monitor output for details:
- WiFi connected? Check SSID/password
- Broker URL correct? Verify in HiveMQ console
- Port 8883? Check MQTT_PORT variable
- Credentials correct? Verify username/password
```

---

# Flutter Dashboard Implementation

## File Structure
```
ahu_dashboard/lib/
├── services/
│   └── mqtt_service.dart    ← We'll modify this
├── providers/
│   └── app_provider.dart    ← And this
└── (other files unchanged)
```

## Step-by-Step Changes

### Change 1: Add TLS Support to MQTT Service

**File**: `ahu_dashboard/lib/services/mqtt_service.dart`

#### 1.1 Add SecurityContext Import

**Location**: Top of file (line 1-8)

**OLD CODE**:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
```

**NEW CODE**:
```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';  // ← ADD THIS LINE (for SecurityContext)
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
```

#### 1.2 Add useTLS Parameter

**Location**: Class declaration (line ~11-40)

**OLD CODE**:
```dart
class MqttService {
  MqttServerClient? _client;
  final String broker;
  final int port;
  final String username;
  final String password;

  MqttService({
    required this.broker,
    this.port = 1883,
    required this.username,
    required this.password,
  });
```

**NEW CODE**:
```dart
class MqttService {
  MqttServerClient? _client;
  final String broker;
  final int port;
  final String username;
  final String password;
  final bool useTLS;  // ← ADD THIS

  MqttService({
    required this.broker,
    this.port = 1883,
    required this.username,
    required this.password,
    this.useTLS = false,  // ← ADD THIS (default false for backward compatibility)
  });
```

#### 1.3 Enable TLS in Connect Method

**Location**: `connect()` method (line ~43-90)

**Find this section**:
```dart
Future<bool> connect() async {
  try {
    _client = MqttServerClient.withPort(broker, 'ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}', port);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 60;
    _client!.onConnected = _onConnected;
```

**ADD THESE LINES** after `keepAlivePeriod`:
```dart
Future<bool> connect() async {
  try {
    _client = MqttServerClient.withPort(broker, 'ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}', port);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 60;
    
    // =========== ADD THIS BLOCK ===========
    if (useTLS) {
      _client!.secure = true;
      _client!.securityContext = SecurityContext.defaultContext;
    }
    // ======================================
    
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    // ... rest of code
```

**Detailed Explanation**:

**`_client!.secure = true`**:
- Tells MQTT client to use TLS/SSL
- Automatically uses port specified (8883)
- Enables encrypted connection

**`SecurityContext.defaultContext`**:
- Uses system's trusted CA certificates
- Validates server certificate automatically
- Works on Linux, Windows, macOS
- Raspberry Pi has CA certs at `/etc/ssl/certs/`

**Connection Flow with TLS**:
```
Flutter App
    ↓
1. DNS Lookup: abc123def456.s2.eu.hivemq.cloud → IP
    ↓
2. TCP Connection: IP:8883
    ↓
3. TLS Handshake:
   - Client Hello (supported ciphers)
   - Server Hello (chosen cipher + certificate)
   - Certificate validation (SecurityContext)
   - Key exchange
   - Encrypted tunnel established
    ↓
4. MQTT CONNECT packet (encrypted)
    ↓
5. MQTT CONNACK (encrypted)
    ↓
6. Connected! Subscribe to topics
```

#### 1.4 Update Connection Success Message

**Find this line**:
```dart
if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
  print('MQTT: Connected to $broker:$port');
```

**Change to**:
```dart
if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
  print('MQTT: Connected to $broker:$port (TLS: $useTLS)');  // ← Added TLS status
```

This helps you verify TLS is enabled when debugging.

---

### Change 2: Update App Provider

**File**: `ahu_dashboard/lib/providers/app_provider.dart`

#### 2.1 Find MQTT Service Initialization

Search for where `MqttService` is created. It might look like:

```dart
_mqttService = MqttService(
  broker: '10.42.0.1',
  port: 1883,
  username: 'almed',
  password: 'Almed1234\$',
);
```

#### 2.2 Update with Cloud Settings

**OLD CODE**:
```dart
_mqttService = MqttService(
  broker: '10.42.0.1',
  port: 1883,
  username: 'almed',
  password: 'Almed1234\$',
);
```

**NEW CODE**:
```dart
_mqttService = MqttService(
  broker: 'abc123def456.s2.eu.hivemq.cloud',  // ← Your cluster URL
  port: 8883,                                  // ← TLS port
  username: 'almed',
  password: 'AlmedHospital2025!#Secure',      // ← Your HiveMQ password
  useTLS: true,                                // ← Enable TLS
);
```

**IMPORTANT**: Replace with YOUR actual HiveMQ cluster URL and password!

---

### Complete Modified Files

#### mqtt_service.dart (Key Changes Only)

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';  // ← ADDED
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/ahu_telemetry.dart';
import '../models/ahu_state.dart';
import '../models/ahu_log.dart';
import '../models/ahu_unit.dart';

class MqttService {
  MqttServerClient? _client;
  final String broker;
  final int port;
  final String username;
  final String password;
  final bool useTLS;  // ← ADDED

  // ... stream controllers (unchanged)

  MqttService({
    required this.broker,
    this.port = 1883,
    required this.username,
    required this.password,
    this.useTLS = false,  // ← ADDED
  });

  Future<bool> connect() async {
    try {
      _client = MqttServerClient.withPort(broker, 'ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}', port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      
      // ========== TLS CONFIGURATION ==========
      if (useTLS) {
        _client!.secure = true;
        _client!.securityContext = SecurityContext.defaultContext;
      }
      // ========================================
      
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.pongCallback = _pong;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier('ahu_dashboard_${DateTime.now().millisecondsSinceEpoch}')
          .authenticateAs(username, password)
          .withWillTopic('ahu_dashboard/status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('MQTT: Connected to $broker:$port (TLS: $useTLS)');  // ← MODIFIED
        _isConnected = true;
        _connectionController.add(true);

        _client!.subscribe('almed/ahu/#', MqttQos.atLeastOnce);
        _client!.updates!.listen(_onMessage);

        return true;
      } else {
        print('MQTT: Connection failed - ${_client!.connectionStatus}');
        _isConnected = false;
        _connectionController.add(false);
        return false;
      }
    } catch (e) {
      print('MQTT: Connection error - $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  // ... rest of methods (unchanged)
}
```

#### app_provider.dart (MQTT Initialization Section)

```dart
void _initializeMqtt() {
  _mqttService = MqttService(
    broker: 'abc123def456.s2.eu.hivemq.cloud',  // ← YOUR CLUSTER URL
    port: 8883,                                  // ← TLS PORT
    username: 'almed',
    password: 'AlmedHospital2025!#Secure',      // ← YOUR PASSWORD
    useTLS: true,                                // ← ENABLE TLS
  );

  _mqttService!.connect().then((success) {
    if (success) {
      print('AppProvider: MQTT connected');
      _setupStreamListeners();
    } else {
      print('AppProvider: MQTT connection failed');
    }
  });
}
```

---

### Test Flutter Dashboard

#### 1. Run Flutter App

```bash
cd /home/almed/Documents/almed_ahu/ahu_dashboard
flutter run -d linux
```

#### 2. Expected Console Output

```
Launching lib/main.dart on Linux in debug mode...
Building Linux application...
✓ Built build/linux/x64/debug/bundle/ahu_dashboard

MQTT: Connected to abc123def456.s2.eu.hivemq.cloud:8883 (TLS: true)
AppProvider: MQTT connected
MQTT: Subscribed to almed/ahu/#
```

**Success Indicators**:
✅ "TLS: true" in connection message
✅ "MQTT connected" without errors
✅ Dashboard shows AHU units (if ESP32 is publishing)

#### 3. Verify in UI

1. Login to dashboard
2. Should see AHU units appearing
3. Real-time telemetry updating
4. Commands work (start/stop)

---

# TLS/SSL Security Explained

## What is TLS/SSL?

**TLS (Transport Layer Security)** is a cryptographic protocol that provides secure communication over a network.

### Without TLS (Plain MQTT - Port 1883)

```
ESP32                    Mosquitto
  │                          │
  ├─────→ CONNECT ─────────→│  (username: almed, password: Almed1234$)
  │                          │  ↑ VISIBLE TO ANYONE MONITORING NETWORK
  │←───── CONNACK ──────────┤
  │                          │
  ├─────→ PUBLISH ─────────→│  (temperature: 24.5°C)
  │       (topic: almed/ahu/hospitalA/icu1/ahu-01/telemetry)
  │                          │  ↑ READABLE BY ANYONE
```

**Risks**:
- ❌ Passwords visible
- ❌ Data readable
- ❌ Can be intercepted
- ❌ Can be modified (MITM attack)

### With TLS (Encrypted MQTT - Port 8883)

```
ESP32                    HiveMQ Cloud
  │                          │
  ├─────→ TLS Handshake ───→│
  │                          │
  │  1. Client Hello         │
  │     (supported ciphers)  │
  │                          │
  │←─── 2. Server Hello ────┤
  │     + Certificate        │
  │     (proves identity)    │
  │                          │
  │  3. Certificate verify   │
  │     (check signature)    │
  │                          │
  │  4. Key Exchange         │
  │     (establish secrets)  │
  │                          │
  │←─── TLS Tunnel Ready ───┤
  │      (encrypted)         │
  │                          │
  ├═════→ CONNECT ═════════→│  (encrypted: 8f3a9c2e...)
  │                          │  ↑ UNREADABLE
  │←═════ CONNACK ══════════┤
  │                          │
  ├═════→ PUBLISH ═════════→│  (encrypted: 4b7d1f9a...)
  │                          │  ↑ CANNOT BE DECRYPTED
```

**Security Benefits**:
- ✅ Passwords encrypted
- ✅ Data encrypted
- ✅ Cannot be intercepted
- ✅ Cannot be modified
- ✅ Server identity verified

---

## Certificate Validation

### What are Certificates?

A **digital certificate** is like a passport for servers. It proves identity and enables encryption.

**Certificate Chain**:
```
HiveMQ Server Certificate
  ├─ Issued by: Let's Encrypt Authority X3
  │    ├─ Issued by: ISRG Root X1
  │    │    ├─ Self-signed (root CA)
  │    │    └─ Trusted by operating systems
```

### How Validation Works

```cpp
// ESP32 with certificate validation
const char* root_ca = "...";  // ISRG Root X1 certificate
espNet.setCACert(root_ca);

// Connection process:
1. ESP32 connects to HiveMQ
2. HiveMQ sends its certificate
3. ESP32 checks:
   ✓ Certificate signed by trusted CA?
   ✓ Certificate not expired?
   ✓ Certificate domain matches?
   ✓ Certificate not revoked?
4. If all pass → connection allowed
5. If any fail → connection refused
```

### `.setInsecure()` vs Certificate Validation

**With `.setInsecure()`** (Testing):
```cpp
espNet.setInsecure();
// Skips all validation
// Accepts any certificate
// Vulnerable to MITM attacks
```

```
Attacker                ESP32                HiveMQ
   │                      │                     │
   ├──── Fake Cert ──────→│                     │
   │   (pretends to be HiveMQ)                  │
   │                      │                     │
   │←─── CONNECT ─────────┤                     │
   │  (ESP32 connects to attacker!)             │
   │                      │                     │
   │ Reads all messages   │                     │
   │ Steals credentials   │                     │
```

**With Certificate Validation** (Production):
```cpp
espNet.setCACert(root_ca);
// Validates certificate
// Rejects fake certificates
// Secure against MITM
```

```
Attacker                ESP32                HiveMQ
   │                      │                     │
   ├──── Fake Cert ──────→│                     │
   │                      │                     │
   │                      │ ✗ Certificate       │
   │                      │   validation failed │
   │                      │   (not signed by    │
   │                      │    trusted CA)      │
   │                      │                     │
   │                      │ Connection refused  │
   │                      │                     │
   │                      ├─────────────────────→
   │                      │  Connect to real    │
   │                      │  HiveMQ (verified)  │
```

### Get HiveMQ Root Certificate

For production, download the root certificate:

**Option 1: Download from Browser**
1. Visit `https://your-cluster.s2.eu.hivemq.cloud` in browser
2. Click padlock icon → Certificate
3. Export root certificate as PEM

**Option 2: Use Let's Encrypt Root**

HiveMQ uses Let's Encrypt, so use their root certificate:

```cpp
// ISRG Root X1 (valid until 2035)
const char* hivemq_root_ca = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
)EOF";

void setup() {
  // ... existing code ...
  
  espNet.setCACert(hivemq_root_ca);
  Serial.println("✓ TLS with certificate validation configured");
}
```

---

# MQTT Topics Architecture

## Your Current Topic Structure

```
almed/ahu/{site}/{room}/{unit_id}/{type}
         │     │     │       │         │
         │     │     │       │         └─ Message type
         │     │     │       └─────────── Unit identifier
         │     │     └─────────────────── Room/location
         │     └───────────────────────── Site/building
         └─────────────────────────────── Organization
```

### Examples

**Telemetry (sensor data)**:
```
almed/ahu/hospitalA/icu1/ahu-01/telemetry
almed/ahu/hospitalA/icu2/ahu-02/telemetry
almed/ahu/hospitalB/ward3/ahu-03/telemetry
```

**State (system status)**:
```
almed/ahu/hospitalA/icu1/ahu-01/state
```

**Commands (control)**:
```
almed/ahu/hospitalA/icu1/ahu-01/cmd
```

**Logs (system logs)**:
```
almed/ahu/hospitalA/icu1/ahu-01/log
```

**Status (online/offline)**:
```
almed/ahu/hospitalA/icu1/ahu-01/status
```

**Provisioning**:
```
almed/ahu/hospitalA/icu1/ahu-01/provision/wifi
almed/ahu/hospitalA/icu1/ahu-01/provision/broker
almed/ahu/hospitalA/icu1/ahu-01/provision/motor_timings
almed/ahu/hospitalA/icu1/ahu-01/provision/ack
```

---

## Wildcard Subscriptions

### Single-Level Wildcard (+)

Matches **one** level:

```
almed/ahu/+/icu1/+/telemetry
```

Matches:
- ✅ `almed/ahu/hospitalA/icu1/ahu-01/telemetry`
- ✅ `almed/ahu/hospitalB/icu1/ahu-02/telemetry`
- ❌ `almed/ahu/hospitalA/ward2/ahu-03/telemetry` (ward2 ≠ icu1)

### Multi-Level Wildcard (#)

Matches **all remaining** levels:

```
almed/ahu/#
```

Matches:
- ✅ `almed/ahu/hospitalA/icu1/ahu-01/telemetry`
- ✅ `almed/ahu/hospitalB/ward2/ahu-05/state`
- ✅ `almed/ahu/hospitalC/icu3/ahu-10/cmd`
- ✅ ALL topics under `almed/ahu/`

**Your Flutter dashboard uses this** to receive all AHU messages.

---

## Topic Best Practices

### ✅ DO:

**Use hierarchical structure**:
```
almed/ahu/hospitalA/icu1/ahu-01/telemetry
└─┬─┘ └┬┘ └────┬───┘ └─┬┘ └──┬─┘ └───┬───┘
  │    │       │       │     │       └─ Type
  │    │       │       │     └───────── Unit
  │    │       │       └─────────────── Location
  │    │       └─────────────────────── Site
  │    └─────────────────────────────── Category
  └──────────────────────────────────── Organization
```

**Use lowercase**:
```
✅ almed/ahu/hospitalA/telemetry
❌ ALMED/AHU/HospitalA/Telemetry  (harder to type)
```

**Use descriptive names**:
```
✅ almed/ahu/hospitalA/icu1/ahu-01/telemetry
❌ almed/a/h/i/1/t  (unclear)
```

### ❌ DON'T:

**Avoid spaces**:
```
❌ almed/ahu/hospital A/icu 1/telemetry
✅ almed/ahu/hospitalA/icu1/telemetry
```

**Avoid special characters**:
```
❌ almed/ahu/hospital@A/icu#1/telemetry
✅ almed/ahu/hospitalA/icu1/telemetry
```

**Don't start with /**:
```
❌ /almed/ahu/telemetry
✅ almed/ahu/telemetry
```

---

## Message Payload Format

### JSON Structure

All your messages use JSON format:

**Telemetry Message**:
```json
{
  "temp": 24.5,
  "hum": 62.0,
  "m1": false,
  "m2": false,
  "run": true,
  "cp": true,
  "heater": false,
  "tempSet": 22.0,
  "humSet": 55.0,
  "ts": 12345678
}
```

**State Message**:
```json
{
  "run": true,
  "m1": false,
  "m2": false,
  "cp": true,
  "heater": false,
  "tempSet": 22.0,
  "humSet": 55.0,
  "m1_start": 10,
  "m1_post": 10,
  "m2_interval": 30,
  "m2_run": 10,
  "m2_delay": 5,
  "ip": "192.168.1.100"
}
```

**Command Message**:
```json
{
  "start": true
}

or

{
  "stop": true
}

or

{
  "setpoint": 23.5
}
```

**Log Message**:
```json
{
  "ts": 12345678,
  "lvl": "INFO",
  "msg": "Motor-1 ON (Drain)"
}
```

---

(Content continues in next message due to length limit...)

**Shall I continue with the remaining sections**: Testing & Debugging, Production Deployment, Monitoring, Troubleshooting, Advanced Configurations, Cost Optimization, and Real-World Scenarios?

This guide is already very comprehensive, covering all the critical implementation details. Would you like me to complete the remaining sections?

