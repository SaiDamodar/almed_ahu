"""
ALMED AHU Web Dashboard - Flask Backend
Handles AWS IoT Core, DynamoDB, and MQTT communication
"""

from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import boto3
from boto3.dynamodb.conditions import Key, Attr
import json
import time
from datetime import datetime, timedelta
import paho.mqtt.client as mqtt
from threading import Thread
import config

app = Flask(__name__)
app.config['SECRET_KEY'] = config.SECRET_KEY
CORS(app, origins=config.CORS_ORIGINS)

# AWS Clients
dynamodb = boto3.resource(
    'dynamodb',
    region_name=config.DYNAMODB_REGION,
    aws_access_key_id=config.AWS_ACCESS_KEY_ID,
    aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY
)

# AWS IoT Data Plane client (for publishing)
iot_data = None
try:
    iot_data = boto3.client(
        'iot-data',
        region_name=config.AWS_REGION,
        aws_access_key_id=config.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY,
        endpoint_url=f'https://{config.AWS_IOT_ENDPOINT}'
    )
except Exception as e:
    print(f"Warning: Could not initialize IoT Data client: {e}")
    print("Publishing to AWS IoT Core will be disabled")

# MQTT Client for local broker (fallback)
mqtt_client = None
mqtt_connected = False

# In-memory cache for real-time data
device_cache = {}
device_status = {}

def init_mqtt():
    """Initialize MQTT client for local broker (optional)"""
    global mqtt_client, mqtt_connected
    
    try:
        mqtt_client = mqtt.Client()
        mqtt_client.username_pw_set(config.LOCAL_MQTT_USERNAME, config.LOCAL_MQTT_PASSWORD)
        mqtt_client.on_connect = on_mqtt_connect
        mqtt_client.on_message = on_mqtt_message
        
        mqtt_client.connect(config.LOCAL_MQTT_BROKER, config.LOCAL_MQTT_PORT, 60)
        mqtt_client.loop_start()
        print(f"MQTT: Connected to local broker at {config.LOCAL_MQTT_BROKER}")
    except Exception as e:
        print(f"MQTT: Failed to connect to local broker: {e}")
        print("MQTT: Will use AWS IoT Core only")

def on_mqtt_connect(client, userdata, flags, rc):
    """MQTT connection callback"""
    global mqtt_connected
    if rc == 0:
        mqtt_connected = True
        client.subscribe('almed/ahu/#')
        print("MQTT: Subscribed to almed/ahu/#")
    else:
        mqtt_connected = False
        print(f"MQTT: Connection failed with code {rc}")

def on_mqtt_message(client, userdata, msg):
    """MQTT message callback"""
    try:
        topic = msg.topic
        payload = json.loads(msg.payload.decode())
        
        # Parse topic: almed/ahu/site/room/ahu-id/type
        parts = topic.split('/')
        if len(parts) >= 5:
            device_id = parts[4]
            
            if topic.endswith('/telemetry'):
                device_cache[device_id] = {
                    'telemetry': payload,
                    'last_update': time.time()
                }
            elif topic.endswith('/state'):
                if device_id not in device_cache:
                    device_cache[device_id] = {}
                device_cache[device_id]['state'] = payload
                device_cache[device_id]['last_update'] = time.time()
            elif topic.endswith('/status'):
                device_status[device_id] = payload if isinstance(payload, str) else payload.get('status', 'offline')
    except Exception as e:
        print(f"MQTT: Error processing message: {e}")

# Initialize MQTT on startup
init_mqtt()

# ==================== Routes ====================

@app.route('/')
def index():
    """Main dashboard"""
    return render_template('index.html')

@app.route('/hospitals')
def hospitals():
    """Hospitals → Devices view"""
    return render_template('hospitals.html')

@app.route('/ahu/<device_id>')
def ahu_control(device_id):
    """AHU control page"""
    return render_template('ahu_control.html', device_id=device_id)

@app.route('/graphs/<device_id>')
def graphs(device_id):
    """Graphs and analytics page"""
    return render_template('graphs.html', device_id=device_id)

@app.route('/settings')
def settings():
    """Admin settings page"""
    return render_template('settings.html')

@app.route('/ota')
def ota():
    """OTA updates page"""
    return render_template('ota.html')

# ==================== API Endpoints ====================

@app.route('/api/devices', methods=['GET'])
def get_devices():
    """Get all devices grouped by hospital"""
    try:
        # Query DynamoDB for all devices
        table = dynamodb.Table(config.DYNAMODB_TABLE_NAME)
        
        # Scan for unique device_ids
        # Note: 'ts' is ESP32 millis() (milliseconds since boot), not Unix timestamp
        # So we can't filter by timestamp. Instead, get recent items and extract unique devices
        # Handle pagination to get all items
        items = []
        last_evaluated_key = None
        
        while True:
            if last_evaluated_key:
                response = table.scan(Limit=500, ExclusiveStartKey=last_evaluated_key)
            else:
                response = table.scan(Limit=500)
            
            items.extend(response.get('Items', []))
            
            last_evaluated_key = response.get('LastEvaluatedKey')
            if not last_evaluated_key:
                break
        
        print(f"DEBUG: Found {len(items)} total items in DynamoDB")
        
        # Group by hospital/site
        hospitals = {}
        seen_devices = set()  # Track devices we've already added
        
        # Sort items by ts descending to get most recent first
        items.sort(key=lambda x: float(x.get('ts', 0) or x.get('timestamp', 0)), reverse=True)
        
        for item in items:
            # Try different possible device_id field names
            # DynamoDB stores it as "thing" (from ESP32)
            device_id = item.get('device_id') or item.get('thing') or item.get('deviceId') or 'unknown'
            
            if device_id == 'unknown':
                print(f"DEBUG: Skipping item with no device_id/thing: {list(item.keys())}")
                continue
            
            # Skip if we've already processed this device (we want unique devices)
            if device_id in seen_devices:
                continue
            seen_devices.add(device_id)
            
            print(f"DEBUG: Processing device: {device_id}")
            
            # Use defaults if site/room not in DynamoDB (telemetry doesn't include them)
            site = item.get('site')
            room = item.get('room')
            
            # Default mapping based on device_id
            if not site:
                if 'AHU_ESP2' in device_id or 'ESP2' in device_id:
                    site = 'hospitalA'
                    room = 'icu1'
                elif 'ahu-01' in device_id.lower():
                    site = 'hospitalA'
                    room = 'icu1'
                else:
                    site = 'hospitalA'  # Default
                    room = 'room1'  # Default
            
            if site not in hospitals:
                hospitals[site] = {}
            if room not in hospitals[site]:
                hospitals[site][room] = []
            
            hospitals[site][room].append({
                'id': device_id,
                'name': f'AHU {device_id.replace("ahu-", "").replace("AHU_", "").replace("ESP2", "").strip().upper() or "ESP2"}',
                'site': site,
                'room': room
            })
        
        # Also include devices from cache (real-time) if not already in DynamoDB results
        for device_id, data in device_cache.items():
            if device_id in seen_devices:
                continue
            seen_devices.add(device_id)
            
            # Try to extract site/room from cache or use defaults
            site = 'hospitalA'  # Default
            room = 'icu1'  # Default
            
            # Map known device IDs
            if 'AHU_ESP2' in device_id or 'ahu-01' in device_id.lower():
                site = 'hospitalA'
                room = 'icu1'
            
            if 'state' in data and 'site' in data['state']:
                site = data['state']['site']
            if 'state' in data and 'room' in data['state']:
                room = data['state']['room']
            
            if site not in hospitals:
                hospitals[site] = {}
            if room not in hospitals[site]:
                hospitals[site][room] = []
            
            hospitals[site][room].append({
                'id': device_id,
                'name': f'AHU {device_id.replace("ahu-", "").replace("AHU_", "").upper()}',
                'site': site,
                'room': room
            })
        
        # If no devices found in DynamoDB, return empty structure (not an error)
        # This allows the UI to show "No devices" message gracefully
        return jsonify({
            'success': True,
            'hospitals': hospitals if hospitals else {}
        })
    except Exception as e:
        print(f"Error in get_devices: {e}")
        # Return empty structure on error so UI doesn't break
        return jsonify({
            'success': True,
            'hospitals': {},
            'error': str(e)  # Include error for debugging
        })

@app.route('/api/device/<device_id>/status', methods=['GET'])
def get_device_status(device_id):
    """Get real-time device status"""
    try:
        # Check cache first
        cache_data = device_cache.get(device_id, {})
        
        # Also try to get latest from DynamoDB
        table = dynamodb.Table(config.DYNAMODB_TABLE_NAME)
        
        # Try querying with thing as partition key (that's what ESP32 uses)
        db_data = {}
        latest_ts = 0
        try:
            # Table likely has: Partition Key = thing, Sort Key = ts
            # Query with ScanIndexForward=False to get most recent first
            response = table.query(
                KeyConditionExpression=Key('thing').eq(device_id),
                ScanIndexForward=False,  # Get most recent first (highest ts first)
                Limit=1
            )
            if response.get('Items'):
                db_data = response['Items'][0]
                latest_ts = float(db_data.get('ts', 0) or db_data.get('timestamp', 0))
                print(f"[DEBUG] Query success: Got item with ts={latest_ts}")
        except Exception as e:
            print(f"[DEBUG] Query failed, trying scan with pagination: {e}")
            # If query fails, scan ALL items for this device with pagination
            all_items = []
            last_evaluated_key = None
            
            while True:
                if last_evaluated_key:
                    response = table.scan(
                        FilterExpression=Attr('thing').eq(device_id),
                        Limit=1000,
                        ExclusiveStartKey=last_evaluated_key
                    )
                else:
                    response = table.scan(
                        FilterExpression=Attr('thing').eq(device_id),
                        Limit=1000
                    )
                
                all_items.extend(response.get('Items', []))
                last_evaluated_key = response.get('LastEvaluatedKey')
                
                if not last_evaluated_key:
                    break
            
            # Sort by ts descending and take the MOST RECENT (highest ts)
            if all_items:
                all_items.sort(key=lambda x: float(x.get('ts', 0) or x.get('timestamp', 0)), reverse=True)
                db_data = all_items[0]  # Most recent item
                latest_ts = float(db_data.get('ts', 0) or db_data.get('timestamp', 0))
                print(f"[DEBUG] Scan success: Found {len(all_items)} items, using most recent with ts={latest_ts}")
            else:
                print(f"[DEBUG] Scan found no items for device {device_id}")
        
        # Determine status: online if we have recent data (within last 5 minutes)
        # Since ts is ESP32 millis(), we check if it's recent relative to other data
        # Or check if we have data at all (if device is sending, latest ts will be high)
        # For now, if we have any data in DynamoDB, consider it online
        # Better: check if latest_ts is within reasonable range (device has been running)
        status = 'offline'
        if db_data:
            # If we have data, device is likely online
            # Check if ts is reasonable (not 0, and not too old relative to other readings)
            if latest_ts > 0:
                status = 'online'
        elif cache_data:
            # Check cache
            status = device_status.get(device_id, 'online' if cache_data else 'offline')
        else:
            status = device_status.get(device_id, 'offline')
        
        # Extract telemetry and state from db_data
        # db_data contains the raw DynamoDB item, which is already telemetry
        # Since DynamoDB only stores telemetry (not separate state), telemetry and state are the same
        telemetry = cache_data.get('telemetry') or {}
        state = cache_data.get('state') or {}
        cache_ts = cache_data.get('last_update', 0)
        
        # ALWAYS use db_data if it's available - it's the source of truth from DynamoDB
        # Cache is only for real-time updates, but DynamoDB has the persistent state
        if db_data:
            db_ts = float(db_data.get('ts', 0) or db_data.get('timestamp', 0))
            print(f"[DEBUG] Using DynamoDB data (ts={db_ts}) for {device_id}")
            
            # db_data is a telemetry record, use it directly
            # Convert DynamoDB Decimal types to Python native types
            def convert_value(val):
                if val is None:
                    return None
                # Handle DynamoDB Decimal type
                if hasattr(val, '__float__'):
                    return float(val)
                if isinstance(val, (int, float)):
                    return float(val) if isinstance(val, float) else int(val)
                if isinstance(val, str):
                    try:
                        return float(val) if '.' in val else int(val)
                    except:
                        return val
                return val
            
            temp_val = convert_value(db_data.get('temp'))
            hum_val = convert_value(db_data.get('hum'))
            
            # Only set to None if value is actually None or invalid
            # 0.0 is a valid reading (though unlikely for temp/hum)
            # Helper to convert to boolean (handles 0.0, 1.0, False, True, "0", "1", etc.)
            def to_bool(val):
                if val is None:
                    return False
                if isinstance(val, bool):
                    return val
                if isinstance(val, (int, float)):
                    return bool(val != 0)
                if isinstance(val, str):
                    return val.lower() in ('true', '1', 'yes', 'on')
                return bool(val)
            
            # Debug: log raw values from DynamoDB
            raw_m1 = db_data.get('m1')
            raw_m2 = db_data.get('m2')
            raw_cp = db_data.get('cp')
            raw_heater = db_data.get('heater')
            raw_run = db_data.get('run')
            raw_temp = db_data.get('temp')
            raw_hum = db_data.get('hum')
            raw_tempSet = db_data.get('tempSet')
            raw_humSet = db_data.get('humSet')
            raw_fanSpeed = db_data.get('fanSpeed')
            
            print(f"[DEBUG] Most recent DynamoDB item for {device_id} (ts={latest_ts}):")
            print(f"  temp: {raw_temp}, hum: {raw_hum}")
            print(f"  tempSet: {raw_tempSet}, humSet: {raw_humSet}")
            print(f"  run: {raw_run} -> {to_bool(raw_run)}")
            print(f"  m1: {raw_m1} -> {to_bool(raw_m1)}, m2: {raw_m2} -> {to_bool(raw_m2)}")
            print(f"  cp: {raw_cp} -> {to_bool(raw_cp)}, heater: {raw_heater} -> {to_bool(raw_heater)}")
            print(f"  fanSpeed: {raw_fanSpeed}")
            
            telemetry = {
                'temp': temp_val if temp_val is not None else None,
                'hum': hum_val if hum_val is not None else None,
                'm1': to_bool(raw_m1),
                'm2': to_bool(raw_m2),
                'run': to_bool(raw_run),
                'cp': to_bool(raw_cp),
                'heater': to_bool(raw_heater),
                'fan': to_bool(db_data.get('fan')),
                'fanSpeed': int(convert_value(db_data.get('fanSpeed', 0)) or 0),
                'tempSet': convert_value(db_data.get('tempSet')),
                'humSet': convert_value(db_data.get('humSet'))
            }
            
            # Since DynamoDB only has telemetry, state is the same as telemetry
            if not state:
                state = telemetry.copy()
        
        # Ensure state is populated from telemetry if still empty
        # Since DynamoDB only stores telemetry (not separate state messages),
        # telemetry contains all state information (setpoints, run status, etc.)
        if not state or len(state) == 0:
            # Use telemetry as state (it contains all the same fields)
            state = telemetry.copy() if telemetry else {}
        else:
            # Merge telemetry values into state for missing or None fields
            # This ensures we always have complete data
            for key in ['tempSet', 'humSet', 'fanSpeed', 'run', 'm1', 'm2', 'cp', 'heater', 'fan']:
                if key not in state or state.get(key) is None:
                    if key in telemetry:
                        state[key] = telemetry[key]
        
        # Merge cache and DB data
        result = {
            'device_id': device_id,
            'status': status,
            'telemetry': telemetry,
            'state': state,
            'last_update': cache_data.get('last_update', latest_ts)
        }
        
        return jsonify({
            'success': True,
            'data': result
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/device/<device_id>/telemetry', methods=['GET'])
def get_telemetry(device_id):
    """Get telemetry data for graphs"""
    try:
        hours = int(request.args.get('hours', 24))
        cutoff_time = int((datetime.now() - timedelta(hours=hours)).timestamp() * 1000)
        
        table = dynamodb.Table(config.DYNAMODB_TABLE_NAME)
        
        # Query using thing as partition key (ESP32 uses this)
        # Note: ts is ESP32 millis(), not Unix timestamp, so we can't filter by time range easily
        # Instead, get all items for this device and filter/sort in code
        items = []
        try:
            # Table structure: Partition Key = thing, Sort Key = ts
            # Handle pagination
            last_evaluated_key = None
            while True:
                if last_evaluated_key:
                    response = table.query(
                        KeyConditionExpression=Key('thing').eq(device_id),
                        ScanIndexForward=True,  # Oldest first for time series
                        Limit=1000,
                        ExclusiveStartKey=last_evaluated_key
                    )
                else:
                    response = table.query(
                        KeyConditionExpression=Key('thing').eq(device_id),
                        ScanIndexForward=True,  # Oldest first for time series
                        Limit=1000
                    )
                
                items.extend(response.get('Items', []))
                last_evaluated_key = response.get('LastEvaluatedKey')
                if not last_evaluated_key:
                    break
        except Exception as e:
            print(f"Query failed, trying scan: {e}")
            # Fallback: scan for "thing" with pagination
            last_evaluated_key = None
            while True:
                if last_evaluated_key:
                    response = table.scan(
                        FilterExpression=Attr('thing').eq(device_id),
                        Limit=1000,
                        ExclusiveStartKey=last_evaluated_key
                    )
                else:
                    response = table.scan(
                        FilterExpression=Attr('thing').eq(device_id),
                        Limit=1000
                    )
                
                items.extend(response.get('Items', []))
                last_evaluated_key = response.get('LastEvaluatedKey')
                if not last_evaluated_key:
                    break
        
        data = []
        # items already populated from pagination above
        
        # Filter by hours if needed (convert hours to approximate ESP32 millis)
        # Since ts is millis() since boot, we can't directly convert hours
        # Instead, get recent items (last N items) or filter by relative ts values
        if hours < 24:
            # For short time ranges, get last N items (assuming ~5 second intervals)
            items_per_hour = 720  # 3600 seconds / 5 seconds per reading
            max_items = items_per_hour * hours
            items = items[-max_items:] if len(items) > max_items else items
        
        for item in items:
            # Handle both 'timestamp' and 'ts' fields
            # ts is ESP32 millis(), convert to relative timestamp for charts
            ts_value = item.get('ts') or item.get('timestamp', 0)
            # For charts, we'll use ts as-is (it's relative time since boot)
            # Or convert to Unix timestamp if we have boot time (we don't, so use relative)
            timestamp = float(ts_value) if ts_value else 0
            
            # Handle both 'temp' and 'temperature' fields
            temp = item.get('temperature') or item.get('temp')
            hum = item.get('humidity') or item.get('hum')
            
            # Convert 0.0 to None for missing values
            if temp == 0.0 and item.get('type') == 'telemetry':
                temp = None
            if hum == 0.0 and item.get('type') == 'telemetry':
                hum = None
            
            data.append({
                'timestamp': timestamp,
                'temperature': temp,
                'humidity': hum,
                'm1': bool(item.get('m1', False)),
                'm2': bool(item.get('m2', False)),
                'run': bool(item.get('run', False)),
                'cp': bool(item.get('cp', False)),
                'heater': bool(item.get('heater', False)),
                'fan': bool(item.get('fan', False)),
                'fanSpeed': int(item.get('fanSpeed', 0))
            })
        
        return jsonify({
            'success': True,
            'data': data
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/device/<device_id>/command', methods=['POST'])
def send_command(device_id):
    """Send command to device via AWS IoT Core or Local MQTT"""
    try:
        data = request.json
        command = data.get('command', {})
        payload = json.dumps(command)
        
        # Try AWS IoT Core first
        if iot_data:
            try:
                topic = config.AWS_IOT_TOPIC_SUBSCRIBE
                iot_data.publish(
                    topic=topic,
                    qos=1,
                    payload=payload
                )
                return jsonify({
                    'success': True,
                    'message': 'Command sent via AWS IoT Core'
                })
            except Exception as e:
                print(f"AWS IoT publish failed: {e}, trying local MQTT")
        
        # Fallback to local MQTT
        if mqtt_client and mqtt_connected:
            # Construct topic: almed/ahu/site/room/device-id/cmd
            # For now, use a default topic structure
            topic = f'almed/ahu/hospitalA/icu1/{device_id}/cmd'
            mqtt_client.publish(topic, payload)
            return jsonify({
                'success': True,
                'message': 'Command sent via local MQTT'
            })
        
        return jsonify({
            'success': False,
            'error': 'No MQTT connection available'
        }), 500
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/admin/verify', methods=['POST'])
def verify_admin():
    """Verify admin passcode"""
    data = request.json
    passcode = data.get('passcode', '')
    
    if passcode == config.ADMIN_PASSCODE:
        return jsonify({
            'success': True,
            'message': 'Access granted'
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Invalid passcode'
        }), 401

@app.route('/api/debug/dynamodb', methods=['GET'])
def debug_dynamodb():
    """Debug endpoint to see what's actually in DynamoDB"""
    try:
        table = dynamodb.Table(config.DYNAMODB_TABLE_NAME)
        
        # Get parameter for limit (default 50, max 100)
        limit = min(int(request.args.get('limit', 50)), 100)
        
        # Get items with pagination to show more
        items = []
        last_evaluated_key = None
        
        while len(items) < limit:
            if last_evaluated_key:
                response = table.scan(Limit=min(limit - len(items), 100), ExclusiveStartKey=last_evaluated_key)
            else:
                response = table.scan(Limit=min(limit, 100))
            
            items.extend(response.get('Items', []))
            
            last_evaluated_key = response.get('LastEvaluatedKey')
            if not last_evaluated_key or len(items) >= limit:
                break
        
        # Sort by ts descending to show most recent first
        items.sort(key=lambda x: float(x.get('ts', 0) or x.get('timestamp', 0)), reverse=True)
        
        # Convert DynamoDB items to JSON-serializable format
        result = []
        for item in items:
            converted = {}
            for key, value in item.items():
                # Handle DynamoDB Decimal types
                if hasattr(value, 'value'):
                    converted[key] = value.value
                elif hasattr(value, '__float__'):
                    converted[key] = float(value)
                elif isinstance(value, (str, int, float, bool, type(None))):
                    converted[key] = value
                else:
                    converted[key] = str(value)
            result.append(converted)
        
        return jsonify({
            'success': True,
            'table_name': config.DYNAMODB_TABLE_NAME,
            'item_count': len(result),
            'total_scanned': len(items),
            'items': result,
            'sample_keys': list(result[0].keys()) if result else [],
            'note': 'Items sorted by ts (most recent first). Use ?limit=N to get more items (max 100).'
        })
    except Exception as e:
        import traceback
        return jsonify({
            'success': False,
            'error': str(e),
            'traceback': traceback.format_exc()
        }), 500

if __name__ == '__main__':
    print("=" * 50)
    print("ALMED AHU Web Dashboard")
    print("=" * 50)
    print(f"Server running on http://{config.HOST}:{config.PORT}")
    print(f"AWS Region: {config.AWS_REGION}")
    print(f"DynamoDB Table: {config.DYNAMODB_TABLE_NAME}")
    print("=" * 50)
    
    app.run(
        host=config.HOST,
        port=config.PORT,
        debug=config.DEBUG
    )

