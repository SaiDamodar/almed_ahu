"""
ALMED AHU Web Dashboard - Flask Backend
Handles AWS IoT Core and MQTT communication (Real-time only, no DynamoDB)
"""

from flask import Flask, render_template, jsonify, request, session, redirect, url_for
from flask_cors import CORS
from flask_socketio import SocketIO, emit
from functools import wraps
import boto3
import json
import time
from datetime import datetime, timedelta
import paho.mqtt.client as mqtt
from threading import Thread
import config
import urllib.parse
import hmac
import hashlib
import base64
from datetime import datetime as dt
import ssl

app = Flask(__name__)
app.config['SECRET_KEY'] = config.SECRET_KEY
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=24)  # Session expires after 24 hours
CORS(app, origins=config.CORS_ORIGINS)

# Initialize SocketIO
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

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

# MQTT Client for AWS IoT Core
aws_iot_mqtt_client = None
aws_iot_connected = False

# MQTT Client for local broker (fallback)
mqtt_client = None
mqtt_connected = False

# In-memory cache for real-time data
device_cache = {}
device_status = {}

# WebSocket connected clients
connected_clients = set()

def sign_url(access_key, secret_key, region, endpoint, service='iotdevicegateway'):
    """Generate SigV4 signed URL for AWS IoT Core WebSocket connection"""
    now = dt.utcnow()
    amzdate = now.strftime('%Y%m%dT%H%M%SZ')
    datestamp = now.strftime('%Y%m%d')
    
    # Create canonical request
    canonical_uri = '/mqtt'
    canonical_querystring = 'X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=' + \
        urllib.parse.quote_plus(f'{access_key}/{datestamp}/{region}/{service}/aws4_request') + \
        '&X-Amz-Date=' + amzdate + \
        '&X-Amz-SignedHeaders=host'
    
    canonical_headers = f'host:{endpoint}\n'
    signed_headers = 'host'
    payload_hash = hashlib.sha256(''.encode('utf-8')).hexdigest()
    
    canonical_request = f'GET\n{canonical_uri}\n{canonical_querystring}\n{canonical_headers}\n{signed_headers}\n{payload_hash}'
    
    # Create string to sign
    algorithm = 'AWS4-HMAC-SHA256'
    credential_scope = f'{datestamp}/{region}/{service}/aws4_request'
    string_to_sign = f'{algorithm}\n{amzdate}\n{credential_scope}\n{hashlib.sha256(canonical_request.encode("utf-8")).hexdigest()}'
    
    # Calculate signature
    def sign(key, msg):
        return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()
    
    k_date = sign(('AWS4' + secret_key).encode('utf-8'), datestamp)
    k_region = sign(k_date, region)
    k_service = sign(k_region, service)
    k_signing = sign(k_service, 'aws4_request')
    signature = hmac.new(k_signing, string_to_sign.encode('utf-8'), hashlib.sha256).hexdigest()
    
    # Add signature to query string
    canonical_querystring += f'&X-Amz-Signature={signature}'
    
    return f'wss://{endpoint}/mqtt?{canonical_querystring}'

def init_aws_iot_mqtt():
    """Initialize MQTT client for AWS IoT Core WebSocket connection"""
    global aws_iot_mqtt_client, aws_iot_connected
    
    def connect_async():
        """Connect in a separate thread to avoid blocking"""
        try:
            # Generate SigV4 signed WebSocket URL
            ws_url = sign_url(
                config.AWS_ACCESS_KEY_ID,
                config.AWS_SECRET_ACCESS_KEY,
                config.AWS_REGION,
                config.AWS_IOT_ENDPOINT
            )
            
            # Parse WebSocket URL
            parsed = urllib.parse.urlparse(ws_url)
            host = parsed.hostname
            port = parsed.port or 443
            path = parsed.path + '?' + parsed.query
            
            # Create MQTT client with WebSocket transport
            client_id = f'almed_dashboard_{int(time.time())}'
            aws_iot_mqtt_client = mqtt.Client(
                client_id=client_id,
                transport='websockets',
                protocol=mqtt.MQTTv311
            )
            
            # Set WebSocket path with headers
            headers = {
                'Host': host
            }
            aws_iot_mqtt_client.ws_set_options(
                path=path,
                headers=headers
            )
            
            # Enable TLS for secure WebSocket connection
            aws_iot_mqtt_client.tls_set()
            
            # Set callbacks
            aws_iot_mqtt_client.on_connect = on_aws_iot_connect
            aws_iot_mqtt_client.on_message = on_aws_iot_message
            aws_iot_mqtt_client.on_disconnect = on_aws_iot_disconnect
            
            print(f"AWS IoT MQTT: Connecting to {host}:{port} via WebSocket...")
            print(f"AWS IoT MQTT: Path: {path[:100]}...")
            
            # Connect with timeout
            aws_iot_mqtt_client.connect(host, port, 60)
            aws_iot_mqtt_client.loop_start()
            
        except Exception as e:
            print(f"AWS IoT MQTT: Failed to initialize: {e}")
            import traceback
            traceback.print_exc()
            aws_iot_connected = False
    
    # Start connection in background thread
    thread = Thread(target=connect_async, daemon=True)
    thread.start()

def on_aws_iot_connect(client, userdata, flags, rc):
    """AWS IoT MQTT connection callback"""
    global aws_iot_connected
    if rc == 0:
        aws_iot_connected = True
        # Subscribe to esp32/pub topic (where ESP32 publishes telemetry)
        client.subscribe(config.AWS_IOT_TOPIC_PUBLISH, qos=1)
        print(f"AWS IoT MQTT: Connected and subscribed to {config.AWS_IOT_TOPIC_PUBLISH}")
    else:
        aws_iot_connected = False
        print(f"AWS IoT MQTT: Connection failed with code {rc}")

def on_aws_iot_message(client, userdata, msg):
    """AWS IoT MQTT message callback - broadcasts via WebSocket"""
    try:
        topic = msg.topic
        payload_str = msg.payload.decode('utf-8')
        payload = json.loads(payload_str)
        
        # Extract device ID from 'thing' field
        device_id = payload.get('thing', 'unknown')
        
        # Determine message type
        msg_type = payload.get('type', 'telemetry')
        
        # Update device cache
        if device_id not in device_cache:
            device_cache[device_id] = {}
        
        if msg_type == 'telemetry':
            device_cache[device_id]['telemetry'] = payload
            device_cache[device_id]['last_update'] = time.time()
        elif msg_type == 'state':
            device_cache[device_id]['state'] = payload
            device_cache[device_id]['last_update'] = time.time()
        
        # Broadcast to all connected WebSocket clients
        socketio.emit('device_update', {
            'device_id': device_id,
            'type': msg_type,
            'data': payload,
            'timestamp': time.time()
        })
        
        print(f"AWS IoT MQTT: Received {msg_type} from {device_id}")
    except Exception as e:
        print(f"AWS IoT MQTT: Error processing message: {e}")
        import traceback
        traceback.print_exc()

def on_aws_iot_disconnect(client, userdata, rc):
    """AWS IoT MQTT disconnection callback"""
    global aws_iot_connected
    aws_iot_connected = False
    print(f"AWS IoT MQTT: Disconnected (rc={rc})")
    # Attempt to reconnect after 5 seconds
    time.sleep(5)
    init_aws_iot_mqtt()

def init_mqtt():
    """Initialize MQTT client for local broker (optional fallback)"""
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

# Initialize AWS IoT MQTT on startup
init_aws_iot_mqtt()

# Initialize local MQTT (fallback)
init_mqtt()

# ==================== Authentication Decorator ====================

def login_required(f):
    """Decorator to require login for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('authenticated'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# ==================== Routes ====================

@app.route('/login')
def login():
    """Login page"""
    if session.get('authenticated'):
        return redirect(url_for('index'))
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Logout and clear session"""
    session.clear()
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    """Main dashboard"""
    return render_template('index.html')

@app.route('/hospitals')
@login_required
def hospitals():
    """Hospitals → Devices view"""
    return render_template('hospitals.html')

@app.route('/ahu/<device_id>')
@login_required
def ahu_control(device_id):
    """AHU control page"""
    return render_template('ahu_control.html', device_id=device_id)

@app.route('/graphs/<device_id>')
@login_required
def graphs(device_id):
    """Graphs and analytics page"""
    return render_template('graphs.html', device_id=device_id)

@app.route('/settings')
@login_required
def settings():
    """Admin settings page"""
    return render_template('settings.html')

@app.route('/ota')
@login_required
def ota():
    """OTA updates page"""
    return render_template('ota.html')

# ==================== API Endpoints ====================

@app.route('/api/devices', methods=['GET'])
def get_devices():
    """Get all devices grouped by hospital (from MQTT cache only)"""
    try:
        # Group by hospital/site from cache only
        hospitals = {}
        
        for device_id, data in device_cache.items():
            # Try to extract site/room from cache or use defaults
            site = 'hospitalA'  # Default
            room = 'icu1'  # Default
            
            # Map known device IDs
            if 'AHU_ESP2' in device_id or 'ESP2' in device_id:
                site = 'hospitalA'
                room = 'icu1'
            elif 'ahu-01' in device_id.lower():
                site = 'hospitalA'
                room = 'icu1'
            
            # Try to get from telemetry or state
            telemetry = data.get('telemetry', {})
            state = data.get('state', {})
            
            if 'site' in telemetry:
                site = telemetry['site']
            elif 'site' in state:
                site = state['site']
            
            if 'room' in telemetry:
                room = telemetry['room']
            elif 'room' in state:
                room = state['room']
            
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
        
        return jsonify({
            'success': True,
            'hospitals': hospitals if hospitals else {}
        })
    except Exception as e:
        print(f"Error in get_devices: {e}")
        return jsonify({
            'success': True,
            'hospitals': {},
            'error': str(e)
        })

@app.route('/api/device/<device_id>/status', methods=['GET'])
def get_device_status(device_id):
    """Get real-time device status (from MQTT cache only)"""
    try:
        # Get data from cache only
        cache_data = device_cache.get(device_id, {})
        
        # Determine status: online if we have recent data (within last 5 minutes)
        status = 'offline'
        if cache_data:
            last_update = cache_data.get('last_update', 0)
            # Consider online if data is less than 5 minutes old
            if time.time() - last_update < 300:
                status = 'online'
            else:
                status = device_status.get(device_id, 'offline')
        else:
            status = device_status.get(device_id, 'offline')
        
        # Extract telemetry and state from cache
        telemetry = cache_data.get('telemetry') or {}
        state = cache_data.get('state') or {}
        
        # If state is empty, use telemetry (it contains all state info)
        if not state or len(state) == 0:
            state = telemetry.copy() if telemetry else {}
        else:
            # Merge telemetry values into state for missing fields
            for key in ['tempSet', 'humSet', 'fanSpeed', 'run', 'm1', 'm2', 'cp', 'heater', 'fan']:
                if key not in state or state.get(key) is None:
                    if key in telemetry:
                        state[key] = telemetry[key]
        
        result = {
            'device_id': device_id,
            'status': status,
            'telemetry': telemetry,
            'state': state,
            'last_update': cache_data.get('last_update', 0)
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
    """Get telemetry data for graphs (from cache only - historical data will be from S3 later)"""
    try:
        # For now, return current cached data only
        # Historical data will be retrieved from S3 in the future
        cache_data = device_cache.get(device_id, {})
        telemetry = cache_data.get('telemetry') or {}
        
        # Return current data point only (historical data will come from S3)
        data = []
        if telemetry:
            current_time = int(time.time() * 1000)
            data.append({
                'timestamp': current_time,
                'temp': telemetry.get('temp'),
                'hum': telemetry.get('hum'),
                'm1': telemetry.get('m1', False),
                'm2': telemetry.get('m2', False),
                'run': telemetry.get('run', False),
                'cp': telemetry.get('cp', False),
                'heater': telemetry.get('heater', False),
                'fan': telemetry.get('fan', False),
                'fanSpeed': telemetry.get('fanSpeed', 0)
            })
        
        return jsonify({
            'success': True,
            'data': data,
            'note': 'Historical data will be available from S3 in the future'
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

@app.route('/api/login', methods=['POST'])
def api_login():
    """Login endpoint"""
    data = request.json
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    if username == config.ADMIN_USERNAME and password == config.ADMIN_PASSWORD:
        session['authenticated'] = True
        session['username'] = username
        session.permanent = True
        return jsonify({
            'success': True,
            'message': 'Login successful'
        })
    else:
        return jsonify({
            'success': False,
            'message': 'Invalid username or password'
        }), 401

@app.route('/api/admin/verify', methods=['POST'])
def verify_admin():
    """Verify admin passcode (for backward compatibility)"""
    data = request.json
    passcode = data.get('passcode', '')
    
    if passcode == config.ADMIN_PASSCODE:
        session['authenticated'] = True
        session.permanent = True
        return jsonify({
            'success': True,
            'message': 'Access granted'
        })
    else:
        return jsonify({
            'success': False,
            'error': 'Invalid passcode'
        }), 401


# ==================== WebSocket Event Handlers ====================

@socketio.on('connect')
def handle_connect(auth):
    """Handle WebSocket client connection"""
    connected_clients.add(request.sid)
    print(f"WebSocket: Client connected ({request.sid})")
    emit('connected', {'status': 'connected'})

@socketio.on('disconnect')
def handle_disconnect():
    """Handle WebSocket client disconnection"""
    connected_clients.discard(request.sid)
    print(f"WebSocket: Client disconnected ({request.sid})")

@socketio.on('subscribe_device')
def handle_subscribe_device(data):
    """Handle device subscription request from client"""
    device_id = data.get('device_id')
    print(f"WebSocket: Client {request.sid} subscribed to {device_id}")
    emit('subscribed', {'device_id': device_id, 'status': 'subscribed'})
    
    # Send current cached data if available
    if device_id in device_cache:
        emit('device_update', {
            'device_id': device_id,
            'type': 'cached',
            'data': device_cache[device_id],
            'timestamp': device_cache[device_id].get('last_update', time.time())
        })

if __name__ == '__main__':
    print("=" * 50)
    print("ALMED AHU Web Dashboard")
    print("=" * 50)
    print(f"Server running on http://{config.HOST}:{config.PORT}")
    print(f"AWS Region: {config.AWS_REGION}")
    print(f"AWS IoT Endpoint: {config.AWS_IOT_ENDPOINT}")
    print(f"MQTT Topic: {config.AWS_IOT_TOPIC_PUBLISH}")
    print(f"WebSocket enabled: SocketIO")
    print("=" * 50)
    
    socketio.run(
        app,
        host=config.HOST,
        port=config.PORT,
        debug=config.DEBUG,
        allow_unsafe_werkzeug=True
    )

