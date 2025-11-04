#!/usr/bin/env python3
"""
AWS IoT Bridge: Raspberry Pi → AWS IoT Core
Replaces HiveMQ Cloud connection with AWS IoT Core

Architecture:
- ESP32 → Local Mosquitto (127.0.0.1:1883)
- Bridge subscribes to all topics (almed/#)
- Bridge forwards all messages to AWS IoT Core
- Bridge writes telemetry to Timestream (backup)
- Bridge updates DynamoDB with device state

Requirements:
    pip3 install paho-mqtt boto3

Usage:
    python3 mqtt_bridge_aws.py

Systemd Service:
    /etc/systemd/system/mqtt-bridge-aws.service
"""

import paho.mqtt.client as mqtt
import ssl
import logging
import sys
import signal
import time
import hashlib
import json
import boto3
from datetime import datetime

# ========== CONFIGURATION ==========
# LOCAL BROKER (Raspberry Pi Mosquitto)
LOCAL_BROKER = "127.0.0.1"
LOCAL_PORT = 1883
LOCAL_USER = "almed"
LOCAL_PASS = "Almed1234$"
LOCAL_TOPIC_PREFIX = "almed/#"

# AWS IOT CORE CONFIGURATION
AWS_IOT_ENDPOINT = "al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com"  # AWS IoT Core endpoint
AWS_REGION = "ap-south-1"
AWS_IOT_PORT = 8883

# AWS IoT Certificate paths (download from AWS Console)
AWS_IOT_ROOT_CA = "/home/almed/aws-certs/AmazonRootCA1.pem"
AWS_IOT_CERT = "/home/almed/aws-certs/bridge-cert.pem"
AWS_IOT_KEY = "/home/almed/aws-certs/bridge-private-key.pem"

# AWS Services
TIMESTREAM_DATABASE = "ahu_telemetry"
TIMESTREAM_TABLE = "sensor_data"
DYNAMODB_STATE_TABLE = "ahu-device-state"

# LOGGING
LOG_FILE = "/var/log/mqtt_bridge_aws.log"
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
aws_connected = False

# AWS Clients
timestream = None
dynamodb = None

# Message cache for deduplication
message_cache = {}
DUPLICATE_SKIP_WINDOW = 10  # Skip exact duplicates within 10 seconds

# ========== AWS CLIENTS INITIALIZATION ==========
def init_aws_clients():
    """Initialize AWS service clients"""
    global timestream, dynamodb
    try:
        timestream = boto3.client('timestream-write', region_name=AWS_REGION)
        dynamodb = boto3.client('dynamodb', region_name=AWS_REGION)
        logger.info("✓ AWS clients initialized")
        return True
    except Exception as e:
        logger.error(f"✗ AWS client initialization failed: {e}")
        return False

# ========== WRITE TO TIMESTREAM ==========
def write_telemetry_to_timestream(topic, payload_dict):
    """Write telemetry data to Amazon Timestream"""
    global timestream
    
    if timestream is None:
        return
    
    try:
        # Extract device info from topic: almed/ahu/{site}/{room}/{device-id}/telemetry
        parts = topic.split('/')
        if len(parts) < 5:
            return
        
        device_id = parts[4]  # ahu-01, ahu-02, etc.
        site = parts[2] if len(parts) > 2 else 'hospitalA'
        room = parts[3] if len(parts) > 3 else 'room1'
        
        # Current time in milliseconds
        current_time_ms = int(time.time() * 1000)
        
        records = []
        
        # Temperature record
        if 'temp' in payload_dict and payload_dict['temp'] is not None:
            records.append({
                'Dimensions': [
                    {'Name': 'device_id', 'Value': device_id},
                    {'Name': 'site', 'Value': site},
                    {'Name': 'room', 'Value': room},
                ],
                'MeasureName': 'temperature',
                'MeasureValue': str(float(payload_dict['temp'])),
                'MeasureValueType': 'DOUBLE',
                'Time': str(current_time_ms),
            })
        
        # Humidity record
        if 'hum' in payload_dict and payload_dict['hum'] is not None:
            records.append({
                'Dimensions': [
                    {'Name': 'device_id', 'Value': device_id},
                    {'Name': 'site', 'Value': site},
                    {'Name': 'room', 'Value': room},
                ],
                'MeasureName': 'humidity',
                'MeasureValue': str(float(payload_dict['hum'])),
                'MeasureValueType': 'DOUBLE',
                'Time': str(current_time_ms),
            })
        
        # Write records if any
        if records:
            timestream.write_records(
                DatabaseName=TIMESTREAM_DATABASE,
                TableName=TIMESTREAM_TABLE,
                Records=records
            )
            logger.debug(f"→ TIMESTREAM: {device_id} (temp: {payload_dict.get('temp')}, hum: {payload_dict.get('hum')})")
    except Exception as e:
        logger.error(f"✗ Timestream write error: {e}")

# ========== UPDATE DYNAMODB STATE ==========
def update_dynamodb_state(topic, payload_dict):
    """Update device state in DynamoDB"""
    global dynamodb
    
    if dynamodb is None:
        return
    
    try:
        parts = topic.split('/')
        if len(parts) < 5:
            return
        
        device_id = parts[4]
        site = parts[2] if len(parts) > 2 else 'hospitalA'
        room = parts[3] if len(parts) > 3 else 'room1'
        
        # Convert payload to DynamoDB format
        item = {
            'device_id': {'S': device_id},
            'site': {'S': site},
            'room': {'S': room},
            'state': {'S': json.dumps(payload_dict)},
            'timestamp': {'S': datetime.utcnow().isoformat()},
        }
        
        dynamodb.put_item(
            TableName=DYNAMODB_STATE_TABLE,
            Item=item
        )
        logger.debug(f"→ DYNAMODB: {device_id} state updated")
    except Exception as e:
        logger.error(f"✗ DynamoDB update error: {e}")

# ========== LOCAL BROKER CALLBACKS ==========
def on_local_connect(client, userdata, flags, rc):
    """Called when connected to local broker"""
    global local_connected
    if rc == 0:
        local_connected = True
        logger.info("✓ Connected to LOCAL broker (Raspberry Pi)")
        logger.info("  Subscribing to: " + LOCAL_TOPIC_PREFIX)
        client.subscribe(LOCAL_TOPIC_PREFIX, qos=1)
        logger.info("  Bridge active: LOCAL → AWS IoT Core")
    else:
        local_connected = False
        logger.error(f"✗ LOCAL broker connection failed, rc={rc}")

def on_local_disconnect(client, userdata, rc):
    """Called when disconnected from local broker"""
    global local_connected
    local_connected = False
    if rc != 0:
        logger.warning(f"⚠️ LOCAL broker disconnected unexpectedly (rc={rc})")
    else:
        logger.info("LOCAL broker disconnected")

def on_local_message(client, userdata, msg):
    """Called when message received from local broker - forward to AWS IoT Core"""
    global aws_connected
    
    topic = msg.topic
    payload = msg.payload
    qos = msg.qos
    retain = msg.retain
    current_time = time.time()
    
    # Only forward if AWS IoT is connected
    if not aws_connected:
        logger.warning(f"⚠️ AWS IoT not connected - message dropped: {topic}")
        return
    
    # ========== DEDUPLICATION ==========
    # For telemetry/log messages, ignore timestamp when comparing
    if topic.endswith('/telemetry') or topic.endswith('/log'):
        try:
            payload_dict = json.loads(payload.decode('utf-8'))
            
            # Write telemetry to Timestream
            if topic.endswith('/telemetry'):
                write_telemetry_to_timestream(topic, payload_dict)
            
            # Remove timestamp for comparison
            if 'ts' in payload_dict:
                del payload_dict['ts']
            payload_str = json.dumps(payload_dict, sort_keys=True)
            payload_hash = hashlib.md5(payload_str.encode('utf-8')).hexdigest()
        except (json.JSONDecodeError, UnicodeDecodeError):
            payload_hash = hashlib.md5(payload).hexdigest()
    else:
        payload_hash = hashlib.md5(payload).hexdigest()
    
    # Check for duplicates
    if topic in message_cache:
        cached_hash, cached_time = message_cache[topic]
        if payload_hash == cached_hash:
            if retain:
                logger.debug(f"→ AWS IoT (retained): {topic}")
            elif current_time - cached_time < DUPLICATE_SKIP_WINDOW:
                logger.debug(f"⊘ SKIP (duplicate): {topic}")
                return
    
    message_cache[topic] = (payload_hash, current_time)
    
    # Update DynamoDB for state messages
    if topic.endswith('/state'):
        try:
            payload_dict = json.loads(payload.decode('utf-8'))
            update_dynamodb_state(topic, payload_dict)
        except:
            pass
    
    # Forward to AWS IoT Core
    try:
        result = aws_client.publish(topic, payload, qos=qos, retain=retain)
        if result.rc == mqtt.MQTT_ERR_SUCCESS:
            logger.info(f"→ AWS IoT: {topic} ({len(payload)} bytes)")
        else:
            logger.error(f"✗ Forward failed: {topic}, rc={result.rc}")
    except Exception as e:
        logger.error(f"✗ Exception forwarding {topic}: {e}")

# ========== AWS IOT CALLBACKS ==========
def on_aws_connect(client, userdata, flags, rc):
    """Called when connected to AWS IoT Core"""
    global aws_connected
    if rc == 0:
        aws_connected = True
        logger.info("✓ Connected to AWS IoT Core")
        logger.info("  Subscribing to command topics: almed/ahu/+/+/+/cmd")
        client.subscribe("almed/ahu/+/+/+/cmd", qos=1)
        client.subscribe("almed/ahu/+/+/+/provision/#", qos=1)
        logger.info("  Bridge ready: LOCAL ↔ AWS IoT Core bidirectional forwarding active")
    else:
        aws_connected = False
        logger.error(f"✗ AWS IoT Core connection failed, rc={rc}")

def on_aws_disconnect(client, userdata, rc):
    """Called when disconnected from AWS IoT Core"""
    global aws_connected
    aws_connected = False
    if rc != 0:
        logger.warning(f"⚠️ AWS IoT Core disconnected unexpectedly (rc={rc})")
    else:
        logger.info("AWS IoT Core disconnected")

def on_aws_message(client, userdata, msg):
    """Called when message received from AWS IoT Core - forward to local"""
    global local_connected
    
    topic = msg.topic
    payload = msg.payload
    qos = msg.qos
    retain = msg.retain
    
    # Only forward COMMAND topics from AWS to local
    if not (topic.endswith('/cmd') or '/provision/' in topic):
        return
    
    # Only forward if local is connected
    if not local_connected:
        logger.warning(f"⚠️ Local not connected - command dropped: {topic}")
        return
    
    try:
        result = local_client.publish(topic, payload, qos=qos, retain=retain)
        if result.rc == mqtt.MQTT_ERR_SUCCESS:
            logger.info(f"← LOCAL: {topic} ({len(payload)} bytes) [Command from AWS]")
        else:
            logger.error(f"✗ Local forward failed: {topic}, rc={result.rc}")
    except Exception as e:
        logger.error(f"✗ Exception forwarding to local: {topic}: {e}")

# ========== SIGNAL HANDLERS ==========
def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    global bridge_running
    logger.info("\nShutting down bridge...")
    bridge_running = False
    local_client.disconnect()
    aws_client.disconnect()
    logger.info("Bridge stopped")
    sys.exit(0)

# ========== MAIN ==========
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("MQTT Bridge: Raspberry Pi → AWS IoT Core")
    logger.info("=" * 60)
    logger.info(f"LOCAL: {LOCAL_BROKER}:{LOCAL_PORT} (user: {LOCAL_USER})")
    logger.info(f"AWS IoT: {AWS_IOT_ENDPOINT}:{AWS_IOT_PORT}")
    logger.info(f"Topics: {LOCAL_TOPIC_PREFIX}")
    logger.info("=" * 60)
    
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Initialize AWS clients
    if not init_aws_clients():
        logger.error("Failed to initialize AWS clients. Exiting.")
        sys.exit(1)
    
    # ========== LOCAL CLIENT ==========
    local_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, "bridge_local")
    local_client.username_pw_set(LOCAL_USER, LOCAL_PASS)
    local_client.on_connect = on_local_connect
    local_client.on_disconnect = on_local_disconnect
    local_client.on_message = on_local_message
    
    # ========== AWS IOT CLIENT ==========
    aws_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, "bridge_aws")
    aws_client.on_connect = on_aws_connect
    aws_client.on_disconnect = on_aws_disconnect
    aws_client.on_message = on_aws_message
    
    # Configure TLS for AWS IoT Core
    aws_client.tls_set(
        ca_certs=AWS_IOT_ROOT_CA,
        certfile=AWS_IOT_CERT,
        keyfile=AWS_IOT_KEY,
        cert_reqs=ssl.CERT_REQUIRED,
        tls_version=ssl.PROTOCOL_TLSv1_2,
        ciphers=None
    )
    
    # Connect to both brokers
    try:
        logger.info("Connecting to LOCAL broker...")
        local_client.connect(LOCAL_BROKER, LOCAL_PORT, 60)
        
        logger.info("Connecting to AWS IoT Core (TLS)...")
        aws_client.connect(AWS_IOT_ENDPOINT, AWS_IOT_PORT, 60)
        
        # Start network loops
        local_client.loop_start()
        aws_client.loop_start()
        
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
            
            if not aws_connected:
                try:
                    aws_client.reconnect()
                except:
                    pass
    
    except KeyboardInterrupt:
        logger.info("\nShutting down bridge...")
        bridge_running = False
    except Exception as e:
        logger.error(f"Bridge error: {e}", exc_info=True)
    finally:
        local_client.loop_stop()
        aws_client.loop_stop()
        local_client.disconnect()
        aws_client.disconnect()
        logger.info("Bridge stopped")

