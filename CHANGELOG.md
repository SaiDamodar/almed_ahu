# Changelog - ALMED AHU System

## [2.0.0] - 2025-10-27

### 🛡️ ESP32 Watchdog System (MAJOR UPDATE)
**Added comprehensive watchdog protection to ESP32 firmware**

#### New Features
- **Hardware Watchdog Timer (30s timeout)**
  - Automatic reset on system freeze/hang
  - Loop execution monitoring
  - "Feed watchdog" every cycle

- **WiFi Failure Recovery**
  - Detects WiFi association errors (fixes "snorlax" network issue)
  - Auto-reset after 60s of WiFi downtime
  - Consecutive failure tracking (3 strikes)

- **State Persistence & Recovery**
  - Saves system state to flash every 10s
  - Restores state after watchdog reset
  - Preserves: runState, cpOn, heatOn
  - Motors follow safe boot sequence

- **Loop Hang Detection**
  - 25-second max loop time
  - Automatic reset if exceeded
  - Protects against soft lockups

#### Configuration Constants
```cpp
WDT_TIMEOUT = 30          // Watchdog timeout (seconds)
LOOP_TIMEOUT_MS = 25000   // Max loop time (ms)
WIFI_FAIL_RESET_MS = 60000 // WiFi fail threshold (ms)
```

#### Safety Features
- ✅ Motors always OFF at boot (safety first)
- ✅ CP/Heater restored after crash
- ✅ State cleared on intentional STOP
- ✅ Only crash scenarios restore state

#### Modified Files
- `esp32_main/esp32_main.ino`
  - Added `<esp_task_wdt.h>` library
  - Added watchdog configuration
  - Added state save/restore functions
  - Added WiFi failure detection
  - Added loop monitoring
  - Enhanced setup() with watchdog init
  - Enhanced loop() with watchdog feeding

#### Documentation
- Created `WATCHDOG_SYSTEM.md` - Complete guide
- Serial output enhanced with status indicators

---

## [1.2.0] - 2025-10-27

### 🔄 Multi-Device Auto-Discovery
**Flutter dashboard now supports unlimited ESP32 devices automatically**

#### New Features
- **Automatic AHU Discovery**
  - No manual registration needed
  - Listens to wildcard MQTT topic (`almed/ahu/#`)
  - Auto-creates AHU units from telemetry
  - Extracts site/room from topic structure

- **Topic Metadata Parsing**
  - Format: `almed/ahu/<site>/<room>/<ahu-id>/<type>`
  - Preserves location information
  - Unique identification per device

#### Modified Files
- `ahu_dashboard/lib/services/mqtt_service.dart`
  - Parse topic metadata: `"ahuId|site|room"`
  - Pass location info to AppProvider

- `ahu_dashboard/lib/providers/app_provider.dart`
  - Added `_ensureAhuRegistered()` method
  - Auto-discover on telemetry/state/log/status
  - Extract site/room from stream keys

#### Benefits
- ✅ Support unlimited ESP32 devices
- ✅ Zero configuration for new devices
- ✅ Real-time discovery on boot
- ✅ Independent data per device

---

## [1.1.0] - 2025-10-27

### 🎨 UI/UX Improvements
**Complete UI revamp with professional theme and branding**

#### New Features
- **Custom Branding**
  - ALMED logo integration (light/dark variants)
  - Custom Vendura font for branding
  - Theme-aware logo switching

- **Refined Color Scheme**
  - Blue/black/white palette
  - Gradient backgrounds
  - Status indicators (red/green only)

- **Enhanced Navigation**
  - Logout button on all pages
  - Back to login from AHU pages
  - Consistent top bar layout

#### Modified Files
- `ahu_dashboard/lib/screens/login_screen.dart`
- `ahu_dashboard/lib/screens/dashboard_screen.dart`
- `ahu_dashboard/lib/screens/ahu_control_screen.dart`
- `ahu_dashboard/lib/screens/admin_screen.dart`
- `ahu_dashboard/lib/theme/app_theme.dart`
- `ahu_dashboard/pubspec.yaml` - Added assets/fonts

#### Assets
- `assets/images/logo_dark.png` - Dark text logo
- `assets/images/logo_light.png` - Light text logo
- `assets/fonts/Vendura-SemiBold-Demo.otf` - Custom font

---

## [1.0.0] - 2025-10-27

### 🚀 Initial Release
**Hospital AHU Control System with Flutter Dashboard**

#### Core Features
- **ESP32 Firmware**
  - Temperature/humidity control (SHT45)
  - Motor sequencing (M1 drain, M2 filter)
  - CP (compressor) & Heater control
  - MQTT communication
  - WiFi provisioning
  - Dual network support

- **Flutter Dashboard**
  - Login (Admin/Hospital roles)
  - Multi-AHU grid view
  - Individual AHU control
  - Real-time telemetry
  - Setpoint adjustment
  - System logs
  - Admin provisioning

#### Tech Stack
- ESP32 (Arduino framework)
- Flutter (Linux/Pi support)
- MQTT (Mosquitto broker)
- Provider pattern (state management)

---

## Upcoming Features

### Planned
- [ ] Fan speed control (user requested)
- [ ] Historical data graphing
- [ ] Alert notifications
- [ ] Maintenance scheduling
- [ ] Energy consumption tracking

### Under Consideration
- [ ] Dynamic room/site renaming
- [ ] Automatic device removal when offline
- [ ] Device grouping by location
- [ ] Mobile app (Android/iOS)
- [ ] Web dashboard

---

**Project:** ALMED AHU Controller  
**Repository:** `almed_ahu`  
**Platform:** ESP32 + Raspberry Pi + Flutter  
**License:** Proprietary  
**Maintained by:** ALMED Team

