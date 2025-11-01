#!/usr/bin/env python3
"""
Test script to debug HiveMQ command flow
Tests publishing commands from cloud and verifies they reach ESP32
"""

import paho.mqtt.client as mqtt
import ssl
import time
import json

# HiveMQ Cloud Configuration
CLOUD_BROKER = "ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud"
CLOUD_PORT = 8883
CLOUD_USER = "almed"
CLOUD_PASS = "AlMed123456"

# Topic structure
CMD_TOPIC = "almed/ahu/hospitalA/icu1/ahu-01/cmd"

def on_connect(client, userdata, flags, rc):
    """Called when connected to HiveMQ"""
    if rc == 0:
        print(f"✓ Connected to HiveMQ Cloud")
        print(f"  Broker: {CLOUD_BROKER}:{CLOUD_PORT}")
        print(f"  User: {CLOUD_USER}")
    else:
        print(f"✗ Connection failed, rc={rc}")

def on_message(client, userdata, msg):
    """Called when message received"""
    print(f"Received: {msg.topic} = {msg.payload.decode()}")

def on_publish(client, userdata, mid):
    """Called when message published"""
    print(f"✓ Message published (mid={mid})")

# Create MQTT client
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, "test_command_sender")
client.username_pw_set(CLOUD_USER, CLOUD_PASS)
client.on_connect = on_connect
client.on_message = on_message
client.on_publish = on_publish

# Configure TLS
client.tls_set(ca_certs=None, certfile=None, keyfile=None,
               cert_reqs=ssl.CERT_NONE, tls_version=ssl.PROTOCOL_TLS, ciphers=None)

# Connect to HiveMQ Cloud
print("Connecting to HiveMQ Cloud...")
client.connect(CLOUD_BROKER, CLOUD_PORT, 60)

# Start network loop
client.loop_start()

# Wait for connection
time.sleep(2)

# Test commands
test_commands = [
    {"start": True},
    {"fanSpeed": 2},
    {"fanToggle": True},
]

print("\n" + "="*60)
print("Testing HiveMQ Command Flow")
print("="*60)
print(f"\nCommand Topic: {CMD_TOPIC}")
print("\nAvailable commands:")
print("  1. {'start': True} - Start system")
print("  2. {'stop': True} - Stop system")
print("  3. {'fanSpeed': 1} - Set fan to LOW")
print("  4. {'fanSpeed': 2} - Set fan to MID")
print("  5. {'fanSpeed': 3} - Set fan to HIGH")
print("  6. {'fanToggle': True} - Toggle fan speed")
print("  7. {'setpoint': 23.5} - Set temperature")
print("  8. {'humiditySetpoint': 60} - Set humidity")

print("\n" + "="*60)
print("Ready to send commands. Type command number or 'quit':")
print("="*60)

try:
    while True:
        try:
            cmd = input("\n> ")
            
            if cmd.lower() == 'quit':
                break
            
            # Parse command
            if cmd == '1':
                command = {"start": True}
            elif cmd == '2':
                command = {"stop": True}
            elif cmd == '3':
                command = {"fanSpeed": 1}
            elif cmd == '4':
                command = {"fanSpeed": 2}
            elif cmd == '5':
                command = {"fanSpeed": 3}
            elif cmd == '6':
                command = {"fanToggle": True}
            elif cmd == '7':
                temp = input("Temperature: ")
                command = {"setpoint": float(temp)}
            elif cmd == '8':
                hum = input("Humidity: ")
                command = {"humiditySetpoint": int(hum)}
            else:
                print("Invalid command")
                continue
            
            # Publish command
            payload = json.dumps(command)
            result = client.publish(CMD_TOPIC, payload, qos=1)
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                print(f"✓ Command sent: {command}")
            else:
                print(f"✗ Failed to send command, rc={result.rc}")
                
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")

except KeyboardInterrupt:
    pass

# Cleanup
print("\nDisconnecting...")
client.loop_stop()
client.disconnect()
print("Done!")

