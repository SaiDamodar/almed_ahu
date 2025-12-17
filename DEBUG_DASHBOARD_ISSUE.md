# Dashboard Issues - Debug Guide

## Issues Reported

1. **System auto-shuts down after starting from dashboard**
   - Symptoms: Motor 1 ON → OFF, Motor 2 ON → OFF, System OFF
   - Works fine from serial monitor

2. **Fan speed can't be controlled from dashboard**
   - Fan control commands not working

## Changes Made to Fix

### 1. Added Extensive Debug Logging

**MQTT Commands:**
```cpp
motorLogMsg("MQTT CMD: " + cmdStr);  // Shows full JSON received
motorLogMsg("→ START");              // Shows which command is executed
motorLogMsg("→ STOP");
motorLogMsg("→ TOGGLE");
```

**Fan Commands:**
```cpp
motorLogMsg("Fan CMD: " + String(fanCmd));
motorLogMsg("→ Fan speed: " + String(fanCmd));
motorLogMsg("→ Fan rejected: system not running");
```

**Running Sequence:**
```cpp
motorLogMsg("[RUN] STARTED");
motorLogMsg("[RUN] M1 boot done, M2 in 5s");
motorLogMsg("[RUN] First M2 cycle (10s), next in 30s");
motorLogMsg("[RUN] Periodic M2 (10s)");
```

**Shutdown Sequence:**
```cpp
motorLogMsg("[SHUTDOWN] Starting shutdown sequence");
motorLogMsg("[SHUTDOWN] M1 post-drain (10s)");
motorLogMsg("[SHUTDOWN] M1 done, M2 in 5s");
motorLogMsg("[SHUTDOWN] M2 final clean (10s)");
motorLogMsg("[SHUTDOWN] Complete - System OFF");
```

### 2. Fixed Command Processing Logic

**Before:**
```cpp
if (doc["start"])  startSystem();
if (doc["stop"])   stopSystem();
if (doc["toggle"]) toggleSystem();
```

**Problem:** Multiple commands could execute if JSON had multiple keys

**After:**
```cpp
if (doc.containsKey("start") && doc["start"] == true)  { motorLogMsg("→ START"); startSystem(); }
else if (doc.containsKey("stop") && doc["stop"] == true)   { motorLogMsg("→ STOP"); stopSystem(); }
else if (doc.containsKey("toggle") && doc["toggle"] == true) { motorLogMsg("→ TOGGLE"); toggleSystem(); }
```

**Fixed:** Using `else if` ensures only ONE command executes

### 3. Added Shutdown Flag Clearing

**In startSystem():**
```cpp
runState = true;
shuttingDown = false;  // ← NEW: Clear shutdown flag
shutdownStarted = false;
shutdownM2Pending = false;
```

**Prevents:** System from being stuck in shutdown mode

### 4. Added State Validation

**In startSystem():**
```cpp
if (shuttingDown) {
  motorLogMsg("[RUN] Cannot start - system is shutting down");
  return;
}
if (!runState){
  // ... start logic
} else {
  motorLogMsg("[RUN] Already running");
}
```

**In stopSystem():**
```cpp
if (!runState) {
  motorLogMsg("[RUN] Already stopped");
  return;
}
```

## Testing Instructions

### Upload New Code
```bash
cd esp32_main
# Upload esp32_main.ino to ESP32
```

### Test 1: Start from Dashboard

**Steps:**
1. Open serial monitor (115200 baud)
2. Click "START SYSTEM" on dashboard
3. Watch serial output

**Expected Output (NORMAL):**
```
MQTT CMD: {"start":true}
→ START
[RUN] STARTED
Motor-1 ON (Drain)
Fan speed: LOW (5V)
[RUN] M1 boot done, M2 in 5s
Motor-1 OFF
... (5 seconds) ...
Motor-2 ON (Filter Clean)
[RUN] First M2 cycle (10s), next in 30s
... (10 seconds) ...
Motor-2 OFF
... (30 seconds) ...
Motor-2 ON (Filter Clean)
[RUN] Periodic M2 (10s)
```

**If BUG STILL EXISTS:**
```
MQTT CMD: {"start":true}
→ START
[RUN] STARTED
Motor-1 ON (Drain)
... then see [SHUTDOWN] messages ...
[SHUTDOWN] Starting shutdown sequence
[SHUTDOWN] M1 post-drain (10s)
...
```

### Test 2: Fan Control from Dashboard

**Steps:**
1. System must be running first
2. Click fan speed buttons (LOW, MED, HIGH, OFF)
3. Watch serial output

**Expected Output (NORMAL):**
```
MQTT CMD: {"fan":1}
Fan CMD: 1
→ Fan speed: 1
Fan speed: LOW (5V)
```

**Expected Output (REJECTED - system not running):**
```
MQTT CMD: {"fan":1}
Fan CMD: 1
→ Fan rejected: system not running
```

**If NOT WORKING:**
```
MQTT CMD: {"fan":1}
Fan CMD: 1
→ Invalid fan speed: 1
```
OR no MQTT CMD message at all (dashboard not sending)

### Test 3: Serial Monitor (Known Working)

**Steps:**
1. Type `start` in serial monitor
2. Watch output

**Expected Output:**
```
[RUN] STARTED
Motor-1 ON (Drain)
Fan speed: LOW (5V)
... (normal sequence continues) ...
```

## Possible Causes

### Issue 1: Auto-Shutdown

**Cause A: Dashboard sending STOP after START**
- Look for: `MQTT CMD: {"stop":true}` right after start
- Fix: Dashboard UI issue, button triggering twice

**Cause B: System entering shutdown mode unexpectedly**
- Look for: `[SHUTDOWN]` messages without `→ STOP` command
- Fix: Logic bug in code (check conditionals)

**Cause C: WiFi/MQTT disconnecting**
- Look for: WiFi disconnect messages
- Fix: Network stability issue

### Issue 2: Fan Control

**Cause A: Dashboard not sending commands**
- Look for: No `MQTT CMD:` message when clicking fan buttons
- Fix: Dashboard UI not connected to MQTT service

**Cause B: Wrong MQTT format**
- Look for: `MQTT CMD:` with wrong JSON structure
- Fix: Dashboard sending wrong format

**Cause C: System not running**
- Look for: `→ Fan rejected: system not running`
- Expected: This is correct behavior - fix by starting system first

## Dashboard MQTT Message Formats

**Correct formats the ESP32 expects:**

```json
{"start": true}     // Start system
{"stop": true}      // Stop system
{"toggle": true}    // Toggle system
{"fan": 0}          // Fan OFF
{"fan": 1}          // Fan LOW (5V)
{"fan": 2}          // Fan MED (7V)
{"fan": 3}          // Fan HIGH (9V)
{"setpoint": 22.0}  // Set temperature
{"humset": 55.0}    // Set humidity
```

## Next Steps

1. **Upload the fixed code**
2. **Test from dashboard** and capture serial output
3. **Look for debug messages** to identify the problem:
   - `MQTT CMD:` - shows what dashboard is sending
   - `→ START/STOP/TOGGLE` - shows which command executed
   - `[RUN]` vs `[SHUTDOWN]` - shows which mode system is in
4. **Share serial output** if issue persists

---

**Last Updated:** November 6, 2024  
**Code Version:** esp32_main.ino (with debug logging)

