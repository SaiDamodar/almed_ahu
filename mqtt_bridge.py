#!/usr/bin/env python3
"""
MQTT Bridge: Raspberry Pi → HiveMQ Cloud
Forwards all ESP32 messages from local Mosquitto broker to HiveMQ Cloud

Architecture:
- ESP32 → Local Mosquitto (10.42.0.1:1883)
- Bridge subscribes to all topics (almed/#)
- Bridge forwards all messages to HiveMQ Cloud

Requirements:
    pip3 install paho-mqtt

Usage:
    python3 /home/almed/Documents/almed_ahu/mqtt_bridge.py

Systemd Service:
    /etc/systemd/system/mqtt-bridge.service
"""

import paho.mqtt.client as mqtt
import ssl
import logging
import sys
import signal
import time

# ========== CONFIGURATION ==========
# LOCAL BROKER (Raspberry Pi Mosquitto)
LOCAL_BROKER = "127.0.0.1"  # Localhost (Raspberry Pi)
LOCAL_PORT = 1883
LOCAL_USER = "almed"
LOCAL_PASS = "Almed1234$"
LOCAL_TOPIC_PREFIX = "almed/#"  # Subscribe to all ALMED topics

# CLOUD BROKER (HiveMQ Cloud)
CLOUD_BROKER = "ec1158fe4e0941df85f0a7bf133bf117.s1.eu.hivemq.cloud"  # YOUR HiveMQ cluster URL
CLOUD_PORT = 8883
CLOUD_USER = "almed"
CLOUD_PASS = "AlMed123456"  # YOUR HiveMQ password

# LOGGING
LOG_FILE = "/var/log/mqtt_bridge.log"
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# ========== LOGGING SETUP ==========
logging.basicConfig(
    level=logging.INFO,
    format=LOG_FORMAT,
    datefmt=LOG_DATE_FORMAT,
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger(__name__)

# Global flags
bridge_running = True
local_connected = False
cloud_connected = False

# ========== LOCAL BROKER CALLBACKS ==========
def on_local_connect(client, userdata, flags, rc):
    """Called when connected to local broker"""
    global local_connected
    if rc == 0:
        local_connected = True
        logger.info("✓ Connected to LOCAL broker (Raspberry Pi)")
        logger.info("  Subscribing to: " + LOCAL_TOPIC_PREFIX)
        client.subscribe(LOCAL_TOPIC_PREFIX, qos=1)
        logger.info("  Bridge active: LOCAL → CLOUD")
    else:
        local_connected = False
        logger.error(f"✗ LOCAL broker connection failed, rc={rc}")

def on_local_disconnect(client, userdata, rc):
    """Called when disconnected from local broker"""
    global local_connected
    local_connected = False
    if rc != 0:
        logger.warning("⚠️ LOCAL broker disconnected unexpectedly (rc={})".format(rc))
    else:
        logger.info("LOCAL broker disconnected")

def on_local_message(client, userdata, msg):
    """Called when message received from local broker - forward to cloud"""
    global cloud_connected
    
    topic = msg.topic
    payload = msg.payload
    qos = msg.qos
    retain = msg.retain
    
    # Only forward if cloud is connected
    if not cloud_connected:
        logger.warning(f"⚠️ Cloud not connected - message dropped: {topic}")
        return
    
    try:
        # Forward message to cloud with same topic, payload, QoS, and retain flag
        result = cloud_client.publish(topic, payload, qos=qos, retain=retain)
        
        if result.rc == mqtt.MQTT_ERR_SUCCESS:
            logger.debug(f"→ CLOUD: {topic} ({len(payload)} bytes, qos={qos}, retain={retain})")
        else:
            logger.error(f"✗ Forward failed: {topic}, rc={result.rc}")
    except Exception as e:
        logger.error(f"✗ Exception forwarding {topic}: {e}")

# ========== CLOUD BROKER CALLBACKS ==========
def on_cloud_connect(client, userdata, flags, rc):
    """Called when connected to cloud broker"""
    global cloud_connected
    if rc == 0:
        cloud_connected = True
        logger.info("✓ Connected to CLOUD broker (HiveMQ)")
        logger.info("  Bridge ready: LOCAL → CLOUD forwarding active")
    else:
        cloud_connected = False
        logger.error(f"✗ CLOUD broker connection failed, rc={rc}")

def on_cloud_disconnect(client, userdata, rc):
    """Called when disconnected from cloud broker"""
    global cloud_connected
    cloud_connected = False
    if rc != 0:
        logger.warning("⚠️ CLOUD broker disconnected unexpectedly (rc={})".format(rc))
    else:
        logger.info("CLOUD broker disconnected")

# ========== SIGNAL HANDLERS ==========
def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    global bridge_running
    logger.info("\nShutting down bridge...")
    bridge_running = False
    local_client.disconnect()
    cloud_client.disconnect()
    logger.info("Bridge stopped")
    sys.exit(0)

# ========== MAIN ==========
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("MQTT Bridge: Raspberry Pi → HiveMQ Cloud")
    logger.info("=" * 60)
    logger.info(f"LOCAL: {LOCAL_BROKER}:{LOCAL_PORT} (user: {LOCAL_USER})")
    logger.info(f"CLOUD: {CLOUD_BROKER}:{CLOUD_PORT} (user: {CLOUD_USER})")
    logger.info(f"Topics: {LOCAL_TOPIC_PREFIX}")
    logger.info("=" * 60)
    
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # ========== LOCAL CLIENT (subscribes to Raspberry Pi broker) ==========
    local_client = mqtt.Client("bridge_local")
    local_client.username_pw_set(LOCAL_USER, LOCAL_PASS)
    local_client.on_connect = on_local_connect
    local_client.on_disconnect = on_local_disconnect
    local_client.on_message = on_local_message
    
    # ========== CLOUD CLIENT (publishes to HiveMQ Cloud) ==========
    cloud_client = mqtt.Client("bridge_cloud")
    cloud_client.username_pw_set(CLOUD_USER, CLOUD_PASS)
    cloud_client.on_connect = on_cloud_connect
    cloud_client.on_disconnect = on_cloud_disconnect
    
    # Configure TLS for cloud connection
    cloud_client.tls_set(
        ca_certs=None,
        certfile=None,
        keyfile=None,
        cert_reqs=ssl.CERT_NONE,  # Skip certificate validation (simplified)
        tls_version=ssl.PROTOCOL_TLS,
        ciphers=None
    )
    
    # Connect to both brokers
    try:
        logger.info("Connecting to LOCAL broker...")
        local_client.connect(LOCAL_BROKER, LOCAL_PORT, 60)
        
        logger.info("Connecting to CLOUD broker (TLS)...")
        cloud_client.connect(CLOUD_BROKER, CLOUD_PORT, 60)
        
        # Start network loops
        local_client.loop_start()
        cloud_client.loop_start()
        
        # Main loop
        logger.info("Bridge running... Press Ctrl+C to stop")
        while bridge_running:
            time.sleep(1)
            
            # Auto-reconnect if needed
            if not local_connected:
                try:
                    local_client.reconnect()
                except:
                    pass
            
            if not cloud_connected:
                try:
                    cloud_client.reconnect()
                except:
                    pass
    
    except KeyboardInterrupt:
        logger.info("\nShutting down bridge...")
        bridge_running = False
    except Exception as e:
        logger.error(f"Bridge error: {e}", exc_info=True)
    finally:
        local_client.loop_stop()
        cloud_client.loop_stop()
        local_client.disconnect()
        cloud_client.disconnect()
        logger.info("Bridge stopped")

