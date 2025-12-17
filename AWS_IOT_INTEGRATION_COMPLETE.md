# AWS IoT Core Integration - Complete

## ✅ What Was Done

Integrated AWS IoT Core into `esp32_main.ino` using the **exact working pattern** from `ahu_aws_sequence_test.ino` that successfully connected.

## 🔑 Key Changes

### 1. Added AWS Certificates & Config
- Endpoint: `al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com`
- Client ID: `AHU_ESP1_CTRL`
- Subscribe Topic: `esp32/sub`
- Certificates: Amazon Root CA + Device Cert + Private Key (from working test)

### 2. AWS MQTT Client
```cpp
WiFiClientSecure awsNet = WiFiClientSecure();
PubSubClient awsMqtt(awsNet);
bool awsMqttConnected = false;
```

### 3. AWS Message Handler
```cpp
void awsMessageHandler(char* topic, byte* payload, unsigned int length)
```
- Receives messages from AWS IoT
- Logs to serial and local MQTT
- Ready for command processing

### 4. Setup() Integration
- Configures TLS certificates
- Sets AWS endpoint and callback
- No NTP sync (matches working test pattern)

### 5. Loop() Integration
- Connects to AWS IoT after local MQTT
- Uses simple `while (!awsMqtt.connect())` pattern (same as working test)
- Subscribes to `esp32/sub`
- Runs `awsMqtt.loop()` when connected

## 📡 How It Works

1. **Boot**: ESP32 connects to WiFi (PiSpot or configured SSID)
2. **Local MQTT**: Connects to Raspberry Pi broker (10.42.0.1:1883)
3. **AWS IoT**: Connects to AWS IoT Core (port 8883, TLS)
4. **Dual Operation**: Both MQTT connections run in parallel
5. **Messages**: 
   - Local: `almed/ahu/hospitalA/icu1/ahu-01/*`
   - AWS: `esp32/sub` (subscribe)

## 🧪 Testing

### Serial Monitor Output
You should see:
```
✓ AWS IoT client configured
[AWS] Connecting to AWS IOT
...
[AWS] AWS IoT Connected!
[AWS] Connected to AWS IoT Core
```

### AWS IoT MQTT Test Client
1. Subscribe to: `esp32/sub`
2. Publish to: `esp32/sub` with payload like `{"test": "hello"}`
3. ESP32 will receive and log the message

## 🔧 Policy Required

Attach this policy to the certificate in AWS IoT Core:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Connect",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["iot:Publish", "iot:Receive"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iot:Subscribe",
      "Resource": "*"
    }
  ]
}
```

## ✨ Why This Works

### Differences from Previous Failed Attempts

1. **No NTP Sync**: The working test doesn't use NTP, so we removed it
2. **Simple Connect**: Uses `while (!awsMqtt.connect())` pattern
3. **No LWT**: No Last Will and Testament in connect call
4. **Direct Setup**: All AWS config in `setup()`, not deferred
5. **Same Certificates**: Uses the exact certs that worked in test

### Pattern Copied From Working Test
- WiFiClientSecure initialization: `WiFiClientSecure()`
- Certificate loading in `setup()`
- Simple connection loop without timeout logic
- Direct subscribe after connect
- Clean `loop()` handling

## 📝 Next Steps

1. **Test Connection**: Flash and verify AWS connection in serial monitor
2. **Add Telemetry**: Publish AHU data to AWS topics
3. **Command Processing**: Handle AWS commands in `awsMessageHandler()`
4. **Error Handling**: Add reconnection logic if needed

## 🎯 Current Status

- ✅ AWS certificates embedded
- ✅ TLS client configured
- ✅ Message handler implemented
- ✅ Connection logic in loop
- ✅ Subscribe to `esp32/sub`
- ⏳ Ready for testing

## 📌 Important Notes

- **Client ID**: `AHU_ESP1_CTRL` (must match AWS policy)
- **Topic**: `esp32/sub` (can be changed as needed)
- **Local MQTT**: Still works independently
- **Dual Operation**: Both brokers run simultaneously
- **No Breaking Changes**: All existing functionality preserved

---

**The integration is complete and ready for testing!** 🚀

