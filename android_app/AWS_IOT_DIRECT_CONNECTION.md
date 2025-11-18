# Direct AWS IoT Core Connection

## Current Implementation

The Android app now supports **both** connection methods:

1. **Direct AWS IoT Core** (via MQTT) - Attempts direct connection
2. **Flask Web App API** (fallback) - Uses HTTP REST API

## How It Works

### On Login:
1. User logs in via Flask API (for authentication)
2. App automatically attempts to connect to AWS IoT Core directly
3. If direct connection succeeds → uses MQTT for real-time updates
4. If direct connection fails → falls back to Flask API polling

### Data Flow:

**Direct AWS IoT (when connected):**
```
ESP32 → AWS IoT Core (esp32/pub) → Android App (MQTT)
Android App → AWS IoT Core (esp32/sub) → ESP32
```

**Flask API (fallback):**
```
ESP32 → AWS IoT Core → Flask Web App → Android App (HTTP)
Android App → Flask Web App → AWS IoT Core → ESP32
```

## Current Limitations

The `mqtt_client` Flutter package has limitations with AWS IoT Core's WebSocket authentication:

- AWS IoT Core requires SigV4-signed query parameters in the WebSocket URL
- The `mqtt_client` package doesn't support custom WebSocket paths with query parameters
- Direct connection may fail, but the app gracefully falls back to Flask API

## Future Improvements

For full direct AWS IoT Core support, consider:

1. **AWS Amplify for Flutter** (Recommended)
   - Official AWS SDK with full IoT Core support
   - Handles authentication automatically
   - Better WebSocket support

2. **X.509 Certificates**
   - Use certificate-based authentication instead of WebSocket
   - More secure and reliable
   - Requires certificate provisioning

3. **Custom WebSocket Implementation**
   - Implement custom WebSocket client with SigV4 signing
   - Full control over connection parameters
   - More complex but most flexible

## Current Status

✅ **Hybrid Approach Working:**
- App attempts direct AWS IoT connection
- Falls back to Flask API if needed
- Seamless user experience
- No functionality loss

## Testing

To test direct connection:
1. Check logs for "AWS IoT: Connected successfully"
2. If you see "Failed to connect to AWS IoT Core, using Flask API" → fallback is working
3. App functionality remains the same regardless of connection method

