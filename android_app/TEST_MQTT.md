# MQTT Connection Test

## Testing ESP32 Detection and MQTT Communication

The Android app communicates with ESP32 devices through the web dashboard API, which uses AWS IoT Core MQTT.

### How It Works:

1. **ESP32 publishes** telemetry data to `esp32/pub` topic
2. **Web dashboard subscribes** to `esp32/pub` to receive data
3. **Web dashboard publishes** commands to `esp32/sub` topic
4. **ESP32 subscribes** to `esp32/sub` to receive commands

### Testing Steps:

1. **Check Web Dashboard API:**
   - Open: `http://YOUR_PC_IP:5000/api/devices`
   - Should return list of hospitals and devices
   - Check if devices have `last_seen` timestamps

2. **Check Device Status:**
   - Open: `http://YOUR_PC_IP:5000/api/device/ESP2/status`
   - Should return device status with `last_update` timestamp
   - Status is "online" if `last_update` is within 5 minutes

3. **Test Command Sending:**
   - POST to: `http://YOUR_PC_IP:5000/api/device/ESP2/command`
   - Body: `{"command": {"run": true}}`
   - Should return `{"success": true}`

4. **Verify in Android App:**
   - Login as admin
   - Navigate to hospitals → select hospital → view AHUs
   - Check if devices show "Online" status
   - Try to send Start/Stop command
   - Check if status updates

### Troubleshooting:

- **Device shows offline:**
  - Check if ESP32 is publishing to `esp32/pub`
  - Check web dashboard logs for MQTT messages
  - Verify `last_update` timestamp in API response
  - Ensure ESP32 device ID matches (e.g., "ESP2")

- **Commands not working:**
  - Verify AWS IoT Core connection in web dashboard
  - Check if ESP32 is subscribed to `esp32/sub`
  - Check web dashboard logs for command publish errors

- **No data displayed:**
  - Check if web dashboard is receiving MQTT messages
  - Verify MongoDB connection (for historical data)
  - Check API endpoint URLs in app config

