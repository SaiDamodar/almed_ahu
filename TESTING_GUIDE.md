# MQTT Command Testing Guide

## Quick Debug Session

### Issue: HiveMQ commands not reaching ESP32

---

## Step 1: Check MQTT Bridge Status

**On Raspberry Pi:**

```bash
# Check if bridge is running
sudo systemctl status mqtt-bridge.service

# View live logs
sudo journalctl -u mqtt-bridge.service -f
```

**Look for:**
- `✓ Connected to CLOUD broker (HiveMQ)`
- `✓ Connected to LOCAL broker (Raspberry Pi)`
- `Subscribing to command topics: almed/ahu/+/+/+/cmd`
- Device discovery: `✓ Device discovered: ahu-01`

---

## Step 2: Monitor Bridge Activity

**On Raspberry Pi, run:**
```bash
# Run debug monitor
python3 test_bridge_debug.py
```

This will show all MQTT messages on local broker.

---

## Step 3: Send Test Command from Cloud

**From your development machine:**
```bash
# Run command tester
python3 test_hivemq_command.py
```

**Then:**
1. Type `1` for start command
2. Watch ESP32 serial monitor for response
3. Watch bridge logs for forwarding

---

## Step 4: Verify Device Discovery

**Check if ESP32 is discovered by bridge:**

In bridge logs, you should see:
```
✓ Device discovered: ahu-01 (on this Pi)
```

**If not seen:**
- ESP32 might not be publishing telemetry
- Check ESP32 Serial Monitor
- Restart ESP32
- Verify ESP32 connected to Pi hotspot

---

## Common Issues & Fixes

### Issue 1: Device Not Discovered

**Symptoms:**
- Bridge logs show: `⊘ SKIP (device not local): ... (device ahu-01 not on this Pi)`
- Commands published but never forwarded

**Fix:**
1. Ensure ESP32 publishes telemetry first (triggers auto-discovery)
2. Check ESP32 is on PiSpot network
3. Verify ESP32 local MQTT connection is active
4. Restart bridge: `sudo systemctl restart mqtt-bridge`

### Issue 2: Topic Mismatch

**Symptoms:**
- ESP32 receives nothing
- Bridge forwards but ESP32 doesn't respond

**Fix:**
1. ESP32 topic: `almed/ahu/hospitalA/icu1/ahu-01/cmd`
2. Verify exact topic match
3. Check site/room/AHU values in ESP32 code match

### Issue 3: Bridge Not Forwarding

**Symptoms:**
- Commands reach HiveMQ
- Bridge logs show command received
- But no `← LOCAL:` message

**Fix:**
1. Check device discovery in bridge logs
2. Verify `local_connected` is true
3. Check for "Local not connected" warnings
4. Restart Mosquitto: `sudo systemctl restart mosquitto`

### Issue 4: ESP32 Not Responding

**Symptoms:**
- Command reaches ESP32 (visible in Serial Monitor)
- But no action taken

**Fix:**
1. Check ESP32 JSON parsing
2. Verify command format matches ESP32 expectations
3. Check if system is running (for fan commands)
4. Verify MQTT message callback is registered

---

## Testing Checklist

Run through these tests in order:

- [ ] Bridge connected to both brokers (check logs)
- [ ] ESP32 device discovered (check bridge logs)
- [ ] Start command works: `{"start": true}`
- [ ] Stop command works: `{"stop": true}`
- [ ] Fan LOW works: `{"fanSpeed": 1}` (system must be running)
- [ ] Fan MID works: `{"fanSpeed": 2}`
- [ ] Fan HIGH works: `{"fanSpeed": 3}`
- [ ] Fan toggle works: `{"fanToggle": true}`
- [ ] Temperature setpoint works: `{"setpoint": 23.5}`
- [ ] Humidity setpoint works: `{"humiditySetpoint": 60}`

---

## Expected Flow

```
Your Dev Machine
  ↓ Publish command to HiveMQ Cloud
HiveMQ Cloud (port 8883, TLS)
  ↓ Bridge subscribes to /cmd topics
MQTT Bridge (mqtt_bridge.py)
  ↓ Extracts device ID, checks if local
  ↓ Forward to local Mosquitto
Raspberry Pi Mosquitto (port 1883)
  ↓ ESP32 subscribed to /cmd topic
ESP32
  ↓ Receives command, parses JSON
  ↓ Executes action (e.g., setFanSpeed())
  ↓ Publishes state update
ESP32 publishes state
  ↓ State forwarded by bridge
HiveMQ Cloud
  ↓ State available for mobile app
```

---

## Quick Commands

**Check bridge status:**
```bash
sudo systemctl status mqtt-bridge
```

**Watch bridge logs:**
```bash
sudo journalctl -u mqtt-bridge.service -f
```

**Restart bridge:**
```bash
sudo systemctl restart mqtt-bridge
```

**Test command from terminal:**
```bash
mosquitto_pub -h ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud \
  -p 8883 --capath /etc/ssl/certs/ \
  -u almed -P 'AlMed123456' \
  -t "almed/ahu/hospitalA/icu1/ahu-01/cmd" \
  -m '{"fanSpeed": 2}'
```

**Monitor ESP32:**
```bash
# Arduino IDE Serial Monitor at 115200 baud
# Or use PlatformIO monitor
```

---

## Debugging Tips

1. **Always check bridge logs first** - they show exactly what's happening
2. **Watch both sides** - serial monitor AND bridge logs simultaneously  
3. **Start with simple commands** - test "start" before fan speed
4. **Verify discovery** - device must be discovered before commands work
5. **Check topic exact match** - one typo breaks everything

---

Good luck! You've got this! 🚀

