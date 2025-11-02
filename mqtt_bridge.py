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
import hashlib
import json
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

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

# INFLUXDB CONFIGURATION
INFLUXDB_URL = "https://us-east-1-1.aws.cloud2.influxdata.com/"
INFLUXDB_TOKEN = "ajBlMxmhBTC7DG3nqgdrjAFCNU5kP9SHpp1FZxy1hWKrqbNGEi1_O-v2UbXRHSAC1HTCcpyJKvlePltkhxnNrQ=="
INFLUXDB_ORG = "ALMED AHU"
INFLUXDB_BUCKET = "AHU_Telemetry"

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

# Prevent message loops (don't forward messages we just forwarded)
forward_from_local = True  # Allow forwarding from local to cloud
forward_from_cloud = True  # Allow forwarding from cloud to local

# ========== MESSAGE DEDUPLICATION ==========
# Cache to store last payload hash for each topic (reduces duplicate traffic)
message_cache = {}  # topic -> (payload_hash, timestamp)

# Maximum age for cached messages (seconds) - cleanup old entries
CACHE_MAX_AGE = 3600  # 1 hour
DUPLICATE_SKIP_WINDOW = 10  # Skip exact duplicates within 10 seconds

# ========== DEVICE AUTO-DISCOVERY ==========
# Track which devices are on THIS Raspberry Pi's local broker
local_devices = set()  # Set of device IDs (e.g., {"ahu-01", "ahu-02"})
DEVICE_TIMEOUT = 300  # Remove device if no message seen for 5 minutes
device_last_seen = {}  # device_id -> timestamp

# ========== COMMAND DEDUPLICATION (Cloud → Local) ==========
# Prevent duplicate commands from being forwarded twice
command_cache = {}  # topic -> (payload_hash, timestamp)
COMMAND_DEBOUNCE_MS = 500  # Ignore duplicate commands within 500ms

# ========== INFLUXDB CLIENT ==========
influxdb_client = None
influxdb_write_api = None

def init_influxdb():
    """Initialize InfluxDB client"""
    global influxdb_client, influxdb_write_api
    try:
        influxdb_client = InfluxDBClient(
            url=INFLUXDB_URL,
            token=INFLUXDB_TOKEN,
            org=INFLUXDB_ORG
        )
        influxdb_write_api = influxdb_client.write_api(write_options=SYNCHRONOUS)
        logger.info(f"✓ InfluxDB connected: {INFLUXDB_ORG}/{INFLUXDB_BUCKET}")
        return True
    except Exception as e:
        logger.error(f"✗ InfluxDB connection failed: {e}")
        return False

def write_telemetry_to_influxdb(topic, payload_dict):
    """Write telemetry data to InfluxDB"""
    global influxdb_write_api
    
    if influxdb_write_api is None:
        return
    
    try:
        # Extract device info from topic: almed/ahu/{site}/{room}/{device-id}/telemetry
        parts = topic.split('/')
        if len(parts) < 5:
            return
        
        device_id = parts[4]  # ahu-01, ahu-02, etc.
        site = parts[2] if len(parts) > 2 else 'hospitalA'
        room = parts[3] if len(parts) > 3 else 'room1'
        
        # Create InfluxDB point with tags and fields
        point = Point("ahu_telemetry") \
            .tag("device_id", device_id) \
            .tag("site", site) \
            .tag("room", room)
        
        # Add fields only if they exist and are not None
        if 'temp' in payload_dict and payload_dict['temp'] is not None:
            point = point.field("temperature", float(payload_dict['temp']))
        
        if 'hum' in payload_dict and payload_dict['hum'] is not None:
            point = point.field("humidity", float(payload_dict['hum']))
        
        if 'fanSpeed' in payload_dict:
            point = point.field("fan_speed", int(payload_dict.get('fanSpeed', 0)))
        
        point = point.field("fan_on", bool(payload_dict.get('fan', False))) \
            .field("m1_active", bool(payload_dict.get('m1', False))) \
            .field("m2_active", bool(payload_dict.get('m2', False))) \
            .field("cp_on", bool(payload_dict.get('cp', False))) \
            .field("heater_on", bool(payload_dict.get('heater', False))) \
            .field("system_running", bool(payload_dict.get('run', False))) \
            .field("temp_setpoint", float(payload_dict.get('tempSet', 0))) \
            .field("hum_setpoint", float(payload_dict.get('humSet', 0)))
        
        # Use current time for InfluxDB (ESP32 ts is milliseconds since boot, not Unix time)
        # InfluxDB will use server time if timestamp not specified
        point.time(time.time_ns(), WritePrecision.NS)
        
        # Write to InfluxDB
        influxdb_write_api.write(bucket=INFLUXDB_BUCKET, org=INFLUXDB_ORG, record=point)
        logger.debug(f"→ INFLUXDB: {device_id} (temp: {payload_dict.get('temp')}, hum: {payload_dict.get('hum')})")
        
    except Exception as e:
        logger.error(f"✗ InfluxDB write error: {e}")

def extract_device_id_from_topic(topic):
    """Extract device ID from topic: almed/ahu/{site}/{room}/{device-id}/{type}"""
    parts = topic.split('/')
    if len(parts) >= 5 and parts[0] == 'almed' and parts[1] == 'ahu':
        return parts[4]  # device-id (e.g., "ahu-01")
    return None

def update_local_device(topic):
    """Update device list when message received from local broker"""
    device_id = extract_device_id_from_topic(topic)
    if device_id:
        is_new = device_id not in local_devices
        local_devices.add(device_id)
        device_last_seen[device_id] = time.time()
        if is_new:
            logger.info(f"✓ Device discovered: {device_id} (on this Pi)")
        logger.debug(f"Device updated: {device_id}")

def cleanup_stale_devices():
    """Remove devices that haven't been seen recently"""
    current_time = time.time()
    stale_devices = [d for d, ts in device_last_seen.items() 
                    if current_time - ts > DEVICE_TIMEOUT]
    for device_id in stale_devices:
        local_devices.discard(device_id)
        del device_last_seen[device_id]
        logger.info(f"Removed stale device: {device_id} (no messages for {DEVICE_TIMEOUT}s)")

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
        logger.info("  Device discovery: Enabled (auto-discover from local messages)")
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
    global cloud_connected, forward_from_local
    
    topic = msg.topic
    payload = msg.payload
    qos = msg.qos
    retain = msg.retain
    current_time = time.time()
    
    # Only forward if cloud is connected and forwarding is enabled
    if not cloud_connected:
        logger.warning(f"⚠️ Cloud not connected - message dropped: {topic}")
        return
    
    if not forward_from_local:
        return
    
    # ========== DEVICE AUTO-DISCOVERY ==========
    # Discover devices from local broker messages
    update_local_device(topic)
    
    # Periodic cleanup of stale devices (every 10th message)
    if len(local_devices) > 0 and len(message_cache) % 10 == 0:
        cleanup_stale_devices()
    
    # ========== DEDUPLICATION: Only skip duplicates when sensor values unchanged ==========
    # For telemetry/log messages, ignore timestamp when comparing (timestamps always change)
    # For other messages, compare entire payload
    
    if topic.endswith('/telemetry') or topic.endswith('/log'):
        # Parse JSON and create hash excluding timestamp
        try:
            payload_dict = json.loads(payload.decode('utf-8'))
            
            # ========== WRITE TO INFLUXDB ==========
            if topic.endswith('/telemetry'):
                write_telemetry_to_influxdb(topic, payload_dict)
            
            # Remove timestamp field for comparison (always changes)
            if 'ts' in payload_dict:
                del payload_dict['ts']
            # Create hash of payload without timestamp
            payload_str = json.dumps(payload_dict, sort_keys=True)
            payload_hash = hashlib.md5(payload_str.encode('utf-8')).hexdigest()
        except (json.JSONDecodeError, UnicodeDecodeError):
            # If not JSON or can't parse, use full payload hash
            payload_hash = hashlib.md5(payload).hexdigest()
    else:
        # For non-telemetry messages (state, status), compare entire payload
        payload_hash = hashlib.md5(payload).hexdigest()
    
    # Check if this message (sensor values) was sent recently
    if topic in message_cache:
        cached_hash, cached_time = message_cache[topic]
        
        # If payload is IDENTICAL (same sensor values) = duplicate message
        if payload_hash == cached_hash:
            # Always forward retained messages (they're state updates)
            if retain:
                logger.debug(f"→ CLOUD (retained): {topic}")
            # Skip duplicate if sent within last 10 seconds (reduces spam)
            elif current_time - cached_time < DUPLICATE_SKIP_WINDOW:
                logger.info(f"⊘ SKIP (duplicate within {DUPLICATE_SKIP_WINDOW}s): {topic}")
                return
            # If duplicate but >10s old, forward anyway (periodic refresh)
            else:
                logger.info(f"→ CLOUD (refresh after {DUPLICATE_SKIP_WINDOW}s): {topic}")
        # If hash is DIFFERENT = sensor values changed (temp/humidity changed!)
        else:
            # CRITICAL: Different sensor values = immediate forward (real-time update)
            logger.info(f"→ CLOUD (CHANGED): {topic} (sensor values changed, forwarding immediately)")
    
    # Update cache with new payload hash
    message_cache[topic] = (payload_hash, current_time)
    
    # Cleanup old cache entries periodically (prevent memory leak)
    if len(message_cache) > 1000:  # Limit cache size
        old_topics = [t for t, (_, ts) in message_cache.items() 
                     if current_time - ts > CACHE_MAX_AGE]
        for old_topic in old_topics:
            del message_cache[old_topic]
            logger.debug(f"Cleaned up old cache entry: {old_topic}")
    
    try:
        # Forward message to cloud (CHANGED messages always forwarded immediately)
        result = cloud_client.publish(topic, payload, qos=qos, retain=retain)
        
        if result.rc == mqtt.MQTT_ERR_SUCCESS:
            logger.info(f"→ CLOUD: {topic} ({len(payload)} bytes, qos={qos}, retain={retain})")
        else:
            logger.error(f"✗ Forward failed: {topic}, rc={result.rc}")
    except Exception as e:
        logger.error(f"✗ Exception forwarding {topic}: {e}")

# ========== CLOUD BROKER CALLBACKS ==========
def on_cloud_message(client, userdata, msg):
    """Called when message received from cloud broker - forward to local"""
    global local_connected, forward_from_cloud
    
    topic = msg.topic
    payload = msg.payload
    qos = msg.qos
    retain = msg.retain
    
    # Only forward COMMAND topics from cloud to local (not telemetry/log)
    # Commands: almed/ahu/+/+/+/cmd
    # Provisioning: almed/ahu/+/+/+/provision/#
    if not (topic.endswith('/cmd') or '/provision/' in topic):
        # Skip telemetry, log, state, status messages (they come from local, not cloud commands)
        return
    
    # Only forward if local is connected and forwarding is enabled
    if not local_connected:
        logger.warning(f"⚠️ Local not connected - command dropped: {topic}")
        return
    
    if not forward_from_cloud:
        return
    
    # ========== DEVICE FILTERING (Multiple Raspberry Pis) ==========
    # Extract device ID from command topic
    device_id = extract_device_id_from_topic(topic)
    
    # Only forward commands for devices on THIS Raspberry Pi
    if device_id and device_id not in local_devices:
        logger.info(f"⊘ SKIP (device not local): {topic} (device {device_id} not on this Pi)")
        return
    
    # Log if forwarding for a known device
    if device_id and device_id in local_devices:
        logger.debug(f"→ Forwarding command for local device: {device_id}")
    
    # ========== COMMAND DEDUPLICATION ==========
    # Prevent duplicate commands from being forwarded within debounce window
    payload_hash = hashlib.md5(payload).hexdigest()
    current_time = time.time()
    
    # Check if this exact command was forwarded recently
    cache_key = f"{topic}_{payload_hash}"
    if cache_key in command_cache:
        cached_time = command_cache[cache_key]
        time_diff_ms = (current_time - cached_time) * 1000
        
        if time_diff_ms < COMMAND_DEBOUNCE_MS:
            logger.info(f"⊘ SKIP (duplicate command within {COMMAND_DEBOUNCE_MS}ms): {topic}")
            return
    
    # Cache this command BEFORE forwarding (prevents race condition)
    command_cache[cache_key] = current_time
    
    # Cleanup old cache entries (older than 1 minute)
    cleanup_keys = [k for k, t in command_cache.items() if current_time - t > 60]
    for k in cleanup_keys:
        del command_cache[k]
    
    try:
        # Temporarily disable local→cloud forwarding to prevent loops
        global forward_from_local
        forward_from_local = False
        
        # Forward command from cloud to local broker
        result = local_client.publish(topic, payload, qos=qos, retain=retain)
        
        # Re-enable local→cloud forwarding
        forward_from_local = True
        
        if result.rc == mqtt.MQTT_ERR_SUCCESS:
            logger.info(f"← LOCAL: {topic} ({len(payload)} bytes, qos={qos}, retain={retain}) [Command from Cloud]")
        else:
            logger.error(f"✗ Local forward failed: {topic}, rc={result.rc}")
    except Exception as e:
        forward_from_local = True  # Always re-enable on error
        logger.error(f"✗ Exception forwarding to local: {topic}: {e}")

def on_cloud_connect(client, userdata, flags, rc):
    """Called when connected to cloud broker"""
    global cloud_connected
    if rc == 0:
        cloud_connected = True
        logger.info("✓ Connected to CLOUD broker (HiveMQ)")
        logger.info("  Subscribing to command topics: almed/ahu/+/+/+/cmd and almed/ahu/+/+/+/provision/#")
        # Subscribe to command topics only (not telemetry/log - those come from local)
        client.subscribe("almed/ahu/+/+/+/cmd", qos=1)
        client.subscribe("almed/ahu/+/+/+/provision/#", qos=1)
        logger.info("  Bridge ready: LOCAL ↔ CLOUD bidirectional forwarding active")
        if local_devices:
            logger.info(f"  Local devices on this Pi: {sorted(local_devices)}")
        else:
            logger.info("  Local devices: None discovered yet (will auto-discover from messages)")
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
    
    # Close InfluxDB connections
    global influxdb_write_api, influxdb_client
    if influxdb_write_api:
        try:
            influxdb_write_api.close()
            logger.info("✓ InfluxDB write API closed")
        except:
            pass
    if influxdb_client:
        try:
            influxdb_client.close()
            logger.info("✓ InfluxDB client closed")
        except:
            pass
    
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
    
    # ========== INITIALIZE INFLUXDB ==========
    init_influxdb()
    
    # ========== LOCAL CLIENT (subscribes to Raspberry Pi broker) ==========
    local_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, "bridge_local")
    local_client.username_pw_set(LOCAL_USER, LOCAL_PASS)
    local_client.on_connect = on_local_connect
    local_client.on_disconnect = on_local_disconnect
    local_client.on_message = on_local_message
    
    # ========== CLOUD CLIENT (publishes to and subscribes from HiveMQ Cloud) ==========
    cloud_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, "bridge_cloud")
    cloud_client.username_pw_set(CLOUD_USER, CLOUD_PASS)
    cloud_client.on_connect = on_cloud_connect
    cloud_client.on_disconnect = on_cloud_disconnect
    cloud_client.on_message = on_cloud_message  # Handle incoming commands from cloud
    
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
        
        # Close InfluxDB connections
        try:
            if influxdb_write_api:
                influxdb_write_api.close()
                logger.info("✓ InfluxDB write API closed")
        except:
            pass
        try:
            if influxdb_client:
                influxdb_client.close()
                logger.info("✓ InfluxDB client closed")
        except:
            pass
        
        logger.info("Bridge stopped")

