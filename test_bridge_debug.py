#!/usr/bin/env python3
"""
Debug script to monitor MQTT bridge logs and verify command forwarding
"""

import paho.mqtt.client as mqtt
import time
import json

# Local Mosquitto broker
LOCAL_BROKER = "127.0.0.1"
LOCAL_PORT = 1883
LOCAL_USER = "almed"
LOCAL_PASS = "Almed1234$"

# Topics to monitor
CMD_TOPIC = "almed/ahu/hospitalA/icu1/ahu-01/cmd"
STATE_TOPIC = "almed/ahu/hospitalA/icu1/ahu-01/state"
TELEMETRY_TOPIC = "almed/ahu/hospitalA/icu1/ahu-01/telemetry"

def on_connect(client, userdata, flags, rc):
    """Called when connected"""
    if rc == 0:
        print("✓ Connected to local Mosquitto broker")
        print(f"  Subscribing to topics...")
        client.subscribe(CMD_TOPIC, qos=1)
        client.subscribe(STATE_TOPIC, qos=1)
        client.subscribe(TELEMETRY_TOPIC, qos=1)
        print(f"  Monitoring: {CMD_TOPIC}")
        print(f"  Monitoring: {STATE_TOPIC}")
        print(f"  Monitoring: {TELEMETRY_TOPIC}")
    else:
        print(f"✗ Connection failed, rc={rc}")

def on_message(client, userdata, msg):
    """Called when message received"""
    try:
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        
        # Try to parse as JSON
        try:
            data = json.loads(payload)
            payload_str = json.dumps(data, indent=2)
        except:
            payload_str = payload
        
        print(f"\n{'='*60}")
        print(f"Topic: {topic}")
        print(f"Payload:")
        print(payload_str)
        print(f"{'='*60}")
        
    except Exception as e:
        print(f"Error processing message: {e}")

# Create client
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, "bridge_debugger")
client.username_pw_set(LOCAL_USER, LOCAL_PASS)
client.on_connect = on_connect
client.on_message = on_message

# Connect
print("Connecting to local Mosquitto broker...")
client.connect(LOCAL_BROKER, LOCAL_PORT, 60)
client.loop_start()

print("\nMonitoring MQTT messages...")
print("Press Ctrl+C to stop")

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    pass

# Cleanup
client.loop_stop()
client.disconnect()
print("\nMonitoring stopped")

