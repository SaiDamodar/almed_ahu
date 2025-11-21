"""
ALMED AHU Web Dashboard - Flask Backend
Handles AWS IoT Core and MQTT communication (Real-time only, no DynamoDB)
"""

import eventlet
eventlet.monkey_patch()

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
from pymongo import MongoClient, ASCENDING, DESCENDING
from pymongo.errors import PyMongoError
from zoneinfo import ZoneInfo
from github import Github
from github.GithubException import GithubException
import requests

app = Flask(__name__)
app.config['SECRET_KEY'] = config.SECRET_KEY
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=24)  # Session expires after 24 hours
CORS(app, origins=config.CORS_ORIGINS)

# Initialize SocketIO with explicit async mode and heartbeat settings
socketio = SocketIO(
    app,
    cors_allowed_origins="*",
    async_mode='eventlet',
    ping_interval=25,
    ping_timeout=60
)

# AWS IoT Data Plane client (for publishing)
iot_data = None
iot_data_error = None
try:
    # Validate credentials before attempting to create client
    if not config.AWS_ACCESS_KEY_ID or not config.AWS_SECRET_ACCESS_KEY:
        raise ValueError("AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is missing")
    if not config.AWS_IOT_ENDPOINT:
        raise ValueError("AWS_IOT_ENDPOINT is missing")
    if not config.AWS_REGION:
        raise ValueError("AWS_REGION is missing")
    
    iot_data = boto3.client(
        'iot-data',
        region_name=config.AWS_REGION,
        aws_access_key_id=config.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=config.AWS_SECRET_ACCESS_KEY,
        endpoint_url=f'https://{config.AWS_IOT_ENDPOINT}'
    )
    print(f"✓ AWS IoT Data client initialized")
    print(f"  Endpoint: {config.AWS_IOT_ENDPOINT}")
    print(f"  Region: {config.AWS_REGION}")
    print(f"  Subscribe topic: {config.AWS_IOT_TOPIC_SUBSCRIBE}")
    print(f"  Publish topic: {config.AWS_IOT_TOPIC_PUBLISH}")
except Exception as e:
    iot_data_error = str(e)
    print(f"❌ ERROR: Could not initialize IoT Data client: {e}")
    print("Publishing to AWS IoT Core will be disabled")
    print("Please check:")
    print("  - AWS_ACCESS_KEY_ID environment variable")
    print("  - AWS_SECRET_ACCESS_KEY environment variable")
    print("  - AWS_IOT_ENDPOINT environment variable")
    print("  - AWS_REGION environment variable")
    import traceback
    traceback.print_exc()

# MQTT Client for AWS IoT Core
aws_iot_mqtt_client = None
aws_iot_connected = False

# In-memory cache for real-time data
device_cache = {}
device_status = {}
last_persist_time = {}  # Track last Mongo write per device/type

# WebSocket connected clients
connected_clients = set()

# MongoDB client (historical data)
mongo_client = None
mongo_collection = None
THROTTLE_SECONDS = 10  # Minimum seconds between MongoDB writes per device/type
IST_ZONE = ZoneInfo('Asia/Kolkata')

def parse_timestamp_seconds(value):
    """Convert various timestamp formats to epoch seconds."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.timestamp()
    if isinstance(value, str):
        for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M:%S.%f'):
            try:
                parsed = datetime.strptime(value, fmt)
                parsed = parsed.replace(tzinfo=IST_ZONE)
                return parsed.timestamp()
            except ValueError:
                continue
    try:
        value = float(value)
        if value > 1e12:  # assume milliseconds
            return value / 1000.0
        return value
    except (TypeError, ValueError):
        return None

def get_last_telemetry_doc(device_id):
    """Fetch the most recent telemetry document for a device."""
    if mongo_collection is None:
        return None
    try:
        # Try to use created_at_ist first (latest first) - handle both cases
        cursor = (
            mongo_collection
            .find({'device_id': device_id, 'type': 'telemetry'})
            .sort('created_at_ist', DESCENDING)
            .limit(1)
        )
        doc = next(cursor, None)
        
        # Try uppercase version if lowercase didn't work
        if doc is None:
            cursor = (
                mongo_collection
                .find({'device_id': device_id, 'type': 'telemetry'})
                .sort('created_at_IST', DESCENDING)
                .limit(1)
            )
            doc = next(cursor, None)
        
        # Fallback to created_at if created_at_ist doesn't work
        if doc is None:
            cursor = (
                mongo_collection
                .find({'device_id': device_id, 'type': 'telemetry'})
                .sort('created_at', DESCENDING)
                .limit(1)
            )
            doc = next(cursor, None)
        
        # Last resort: use _id
        if doc is None:
            legacy_cursor = (
                mongo_collection
                .find({'device_id': device_id, 'type': 'telemetry'})
                .sort('_id', DESCENDING)
                .limit(1)
            )
            doc = next(legacy_cursor, None)
    except Exception as e:
        print(f"Error fetching last telemetry doc: {e}")
        # Fallback to _id sort
        try:
            legacy_cursor = (
                mongo_collection
                .find({'device_id': device_id, 'type': 'telemetry'})
                .sort('_id', DESCENDING)
                .limit(1)
            )
            doc = next(legacy_cursor, None)
        except:
            doc = None
    
    return doc

def init_mongo():
    """Initialize MongoDB client for historical data storage"""
    global mongo_client, mongo_collection
    try:
        # Increase timeout and add connection options for replica sets
        # The MONGO_URI already contains connection parameters, so we just add timeout options
        mongo_client = MongoClient(
            config.MONGO_URI,
            serverSelectionTimeoutMS=30000,  # Increased from 5s to 30s for replica set discovery
            connectTimeoutMS=30000,  # Connection timeout
            socketTimeoutMS=30000,  # Socket timeout
            retryWrites=True,
            retryReads=True,
            # Connection pool options
            maxPoolSize=10,
            minPoolSize=1,
            # Heartbeat frequency for replica set monitoring
            heartbeatFrequencyMS=10000
        )
        mongo_db = mongo_client[config.MONGO_DB_NAME]
        mongo_collection = mongo_db[config.MONGO_COLLECTION]
        # Force connection test with longer timeout
        mongo_client.admin.command('ping', maxTimeMS=30000)
        print(f"✓ MongoDB: Connected to {config.MONGO_DB_NAME}.{config.MONGO_COLLECTION}")
    except Exception as e:
        mongo_client = None
        mongo_collection = None
        print(f"❌ MongoDB: Failed to connect - {e}")
        print("   This may be due to:")
        print("   - Network connectivity issues")
        print("   - Incorrect MongoDB URI")
        print("   - Replica set configuration issues")
        print("   - Firewall blocking connection")
        print("   - Server selection timeout (replica set members not reachable)")

def store_historical_data(device_id, msg_type, payload):
    """Persist telemetry/state payloads to MongoDB for historical data"""
    if mongo_collection is None:
        return
    
    now = time.time()
    throttle_key = f"{device_id}:{msg_type}"
    last_time = last_persist_time.get(throttle_key, 0)
    if now - last_time < THROTTLE_SECONDS:
        return
    last_persist_time[throttle_key] = now
    
    created_at_utc = datetime.utcnow()
    created_at_ist = datetime.now(IST_ZONE)
    created_at_str = created_at_ist.strftime('%Y-%m-%d %H:%M:%S')
    document = {
        'device_id': device_id,
        'type': msg_type,
        'created_at': created_at_utc,
        'created_at_ist': created_at_str,
        'ts': payload.get('ts'),
        'payload': payload
    }
    
    # Flatten commonly queried fields for easier filtering
    for field in ['temp', 'hum', 'm1', 'm2', 'run', 'cp', 'heater', 'fan', 'fanSpeed', 'tempSet', 'humSet']:
        if field in payload:
            document[field] = payload.get(field)
    
    try:
        mongo_collection.insert_one(document)
    except PyMongoError as exc:
        print(f"MongoDB: Failed to store telemetry for {device_id} - {exc}")

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
    
    # Validate AWS credentials before attempting connection
    if not config.AWS_ACCESS_KEY_ID or not config.AWS_SECRET_ACCESS_KEY or not config.AWS_IOT_ENDPOINT:
        print("⚠️ AWS IoT MQTT: Missing AWS credentials or endpoint. Skipping MQTT connection.")
        print("   Set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_IOT_ENDPOINT environment variables to enable.")
        aws_iot_connected = False
        return
    
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
            error_type = type(e).__name__
            if 'WebsocketConnectionError' in error_type or 'WebSocket' in str(type(e)):
                print(f"⚠️ AWS IoT MQTT: WebSocket connection failed: {e}")
                print("   This may be due to:")
                print("   - Invalid AWS credentials")
                print("   - Incorrect AWS IoT endpoint")
                print("   - Network connectivity issues")
                print("   - AWS IoT Core policy restrictions")
            else:
                print(f"⚠️ AWS IoT MQTT: Failed to initialize: {e}")
            import traceback
            traceback.print_exc()
            aws_iot_connected = False
            aws_iot_mqtt_client = None
    
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
        
        # Persist for historical analysis
        store_historical_data(device_id, msg_type, payload)
        
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

# Initialize AWS IoT MQTT on startup
init_aws_iot_mqtt()

# Initialize MongoDB for historical storage
init_mongo()

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

@app.before_request
def require_login():
    """Ensure user is logged in before accessing any page (except login, API login, and static files)"""
    # Allow login page and API login endpoint
    if request.endpoint in ['login', 'api_login', 'verify_admin', 'static']:
        return None
    # Require authentication for all other routes
    if not session.get('authenticated'):
        # For API endpoints, return JSON error
        if request.path.startswith('/api/'):
            return jsonify({'success': False, 'error': 'Authentication required'}), 401
        # For regular pages, redirect to login
        return redirect(url_for('login'))

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
    return render_template('dashboard.html')

@app.route('/dashboard')
@login_required
def dashboard():
    """Dashboard page"""
    return render_template('dashboard.html')

@app.route('/hospitals')
@login_required
def hospitals():
    """Hospitals → Devices view"""
    return render_template('hospitals.html')

@app.route('/devices')
@login_required
def devices():
    """Devices page - Monitor and control all devices"""
    return render_template('devices_page.html')

@app.route('/users')
@login_required
def users():
    """Users management page"""
    return render_template('users.html')

@app.route('/reports')
@login_required
def reports():
    """Reports page"""
    return render_template('reports.html')

@app.route('/calendar')
@login_required
def calendar():
    """Calendar page"""
    return render_template('calendar.html')


@app.route('/profile')
@login_required
def profile():
    """User profile page"""
    return render_template('profile.html')

@app.route('/ahu/<device_id>')
@login_required
def ahu_control(device_id):
    """AHU control page"""
    return render_template('ahu_control.html', device_id=device_id)

@app.route('/ahu/<device_id>/graphs')
@login_required
def ahu_graphs(device_id):
    """AHU graphs page"""
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

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint for Railway and monitoring"""
    return jsonify({
        'status': 'healthy',
        'service': 'ALMED AHU Web Dashboard',
        'timestamp': datetime.now().isoformat()
    }), 200

@app.route('/api/aws-iot/status', methods=['GET'])
def aws_iot_status():
    """Check AWS IoT connection status"""
    status = {
        'iot_data_client': iot_data is not None,
        'mqtt_client': aws_iot_mqtt_client is not None,
        'mqtt_connected': aws_iot_connected,
        'endpoint': config.AWS_IOT_ENDPOINT if config.AWS_IOT_ENDPOINT else None,
        'region': config.AWS_REGION if config.AWS_REGION else None,
        'publish_topic': config.AWS_IOT_TOPIC_PUBLISH if hasattr(config, 'AWS_IOT_TOPIC_PUBLISH') else None,
        'subscribe_topic': config.AWS_IOT_TOPIC_SUBSCRIBE if hasattr(config, 'AWS_IOT_TOPIC_SUBSCRIBE') else None,
    }
    
    if iot_data_error:
        status['iot_data_error'] = iot_data_error
    
    if not config.AWS_ACCESS_KEY_ID:
        status['error'] = 'AWS_ACCESS_KEY_ID not configured'
    elif not config.AWS_SECRET_ACCESS_KEY:
        status['error'] = 'AWS_SECRET_ACCESS_KEY not configured'
    elif not config.AWS_IOT_ENDPOINT:
        status['error'] = 'AWS_IOT_ENDPOINT not configured'
    
    return jsonify({
        'success': True,
        'status': status
    }), 200

@app.route('/api/devices', methods=['GET'])
def get_devices():
    """Get all devices grouped by hospital (from MQTT cache only)"""
    try:
        # Group by hospital/site from cache only
        hospitals = {}
        seen_devices = set()

        def format_device_name(device_id):
            cleaned = (
                device_id.replace('ahu-', '')
                .replace('AHU_', '')
                .replace('ESP2', '')
                .strip()
                .upper()
            )
            return f'AHU {cleaned or "ESP2"}'

        def add_device_record(device_id, telemetry=None, state=None, last_seen=None):
            nonlocal hospitals
            telemetry = telemetry or {}
            state = state or {}
            source = telemetry if telemetry else state

            site = 'hospitalA'
            room = 'icu1'

            # Map known device IDs
            lower_id = device_id.lower()
            if 'ahu_esp2' in lower_id or 'esp2' in lower_id:
                site = 'hospitalA'
                room = 'icu1'
            elif 'ahu-01' in lower_id:
                site = 'hospitalA'
                room = 'icu1'

            site = source.get('site', state.get('site', site))
            room = source.get('room', state.get('room', room))

            if site not in hospitals:
                hospitals[site] = {}
            if room not in hospitals[site]:
                hospitals[site][room] = []

            hospitals[site][room].append({
                'id': device_id,
                'name': format_device_name(device_id),
                'site': site,
                'room': room,
                'last_seen': last_seen
            })
            seen_devices.add(device_id)
        
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
            
            add_device_record(device_id, telemetry, state, data.get('last_update'))

        # Include offline devices persisted in MongoDB
        if mongo_collection is not None:
            try:
                device_ids = mongo_collection.distinct('device_id', {'type': 'telemetry'})
                for device_id in device_ids:
                    if device_id in seen_devices:
                        continue
                    doc = get_last_telemetry_doc(device_id)
                    if not doc:
                        continue
                    payload = doc.get('payload', {})
                    last_seen = parse_timestamp_seconds(doc.get('created_at')) or parse_timestamp_seconds(payload.get('ts'))
                    add_device_record(device_id, payload, payload, last_seen)
            except Exception as mongo_err:
                print(f"MongoDB fallback failed in get_devices: {mongo_err}")
        
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
        fallback_doc = None
        
        # If cache empty and Mongo available, use last stored telemetry
        if (not cache_data or (not cache_data.get('telemetry') and not cache_data.get('state'))) and (mongo_collection is not None):
            fallback_doc = get_last_telemetry_doc(device_id)
            if fallback_doc:
                payload = fallback_doc.get('payload', {})
                last_update_ts = parse_timestamp_seconds(fallback_doc.get('created_at')) or parse_timestamp_seconds(payload.get('ts'))
                if last_update_ts is None:
                    last_update_ts = time.time()
                cache_data = {
                    'telemetry': payload,
                    'state': payload,
                    'last_update': last_update_ts
                }
                device_cache[device_id] = cache_data
        
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
    """Get telemetry data (historical data from MongoDB Atlas)"""
    try:
        if mongo_collection is None:
            return jsonify({
                'success': False,
                'error': 'MongoDB connection not available'
            }), 500
        
        hours = int(request.args.get('hours', 24))
        limit = int(request.args.get('limit', 1000))
        limit = max(1, min(limit, 5000))
        
        query = {
            'device_id': device_id,
            'type': 'telemetry'
        }
        
        # Calculate time threshold based on hours
        if hours > 0:
            now_ist = datetime.now(IST_ZONE)
            since_ist = now_ist - timedelta(hours=hours)
            since_str = since_ist.strftime('%Y-%m-%d %H:%M:%S')
            # Filter by created_at_ist string comparison (works for ISO format strings)
            query['created_at_ist'] = {'$gte': since_str}
        
        # Try to use created_at_ist first, fallback to created_at
        # Sort by ASCENDING to get chronological order (oldest first) for charts
        try:
            # First try with created_at_ist field (IST timezone string)
            cursor = mongo_collection.find(query).sort('created_at_ist', ASCENDING).limit(limit)
            documents = list(cursor)
            
            # If no documents or created_at_ist doesn't exist, try created_at
            if not documents:
                if hours > 0:
                    since = datetime.utcnow() - timedelta(hours=hours)
                    query.pop('created_at_ist', None)
                    query['created_at'] = {'$gte': since}
                
                cursor = mongo_collection.find(query).sort('created_at', ASCENDING).limit(limit)
                documents = list(cursor)
            
            # If still no documents, try legacy _id sort
            if not documents:
                query.pop('created_at', None)
                query.pop('created_at_ist', None)
                legacy_cursor = (
                    mongo_collection
                    .find(query)
                    .sort('_id', ASCENDING)
                    .limit(limit)
                )
                documents = list(legacy_cursor)
            
        except Exception as query_error:
            print(f"MongoDB query error: {query_error}")
            # Fallback to basic query
            if hours > 0:
                since = datetime.utcnow() - timedelta(hours=hours)
                query.pop('created_at_ist', None)
                query['created_at'] = {'$gte': since}
            cursor = mongo_collection.find(query).sort('created_at', ASCENDING).limit(limit)
            documents = list(cursor)
        
        data = []
        for doc in documents:
            payload = doc.get('payload', {})
            
            # Try to parse created_at_ist first (format: "YYYY-MM-DD HH:MM:SS")
            timestamp_secs = None
            created_at_ist = doc.get('created_at_ist') or doc.get('created_at_IST')  # Handle both cases
            
            if created_at_ist:
                try:
                    # Parse IST string format: "2024-01-15 14:30:45"
                    dt_obj = datetime.strptime(created_at_ist, '%Y-%m-%d %H:%M:%S')
                    # Set timezone to IST
                    dt_obj = dt_obj.replace(tzinfo=IST_ZONE)
                    timestamp_secs = dt_obj.timestamp()
                except (ValueError, TypeError) as e:
                    print(f"Error parsing created_at_ist '{created_at_ist}': {e}")
            
            # Fallback to created_at (UTC datetime)
            if timestamp_secs is None:
                created_at = doc.get('created_at')
                timestamp_secs = parse_timestamp_seconds(created_at)
            
            # Fallback to ts field
            if timestamp_secs is None:
                ts_value = doc.get('ts') or payload.get('ts')
                timestamp_secs = parse_timestamp_seconds(ts_value)
            
            # Last resort: use current time
            if timestamp_secs is None:
                timestamp_secs = datetime.utcnow().timestamp()

            timestamp_ms = int(timestamp_secs * 1000)
            
            data.append({
                'timestamp': timestamp_ms,
                'temp': doc.get('temp', payload.get('temp')),
                'hum': doc.get('hum', payload.get('hum')),
                'm1': doc.get('m1', payload.get('m1', False)),
                'm2': doc.get('m2', payload.get('m2', False)),
                'run': doc.get('run', payload.get('run', False)),
                'cp': doc.get('cp', payload.get('cp', False)),
                'heater': doc.get('heater', payload.get('heater', False)),
                'fan': doc.get('fan', payload.get('fan', False)),
                'fanSpeed': doc.get('fanSpeed', payload.get('fanSpeed', 0)),
                'tempSet': doc.get('tempSet', payload.get('tempSet')),
                'humSet': doc.get('humSet', payload.get('humSet'))
            })
        
        return jsonify({
            'success': True,
            'data': data,
            'count': len(data),
            'source': 'MongoDB Atlas'
        })
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/device/<device_id>/command', methods=['POST'])
def send_command(device_id):
    """Send command to device via AWS IoT Core"""
    try:
        data = request.json
        command = data.get('command', {})
        
        if not command:
            return jsonify({
                'success': False,
                'error': 'Command payload is required'
            }), 400
        
        payload = json.dumps(command)
        
        # Check if AWS IoT Data client is available
        if not iot_data:
            error_msg = 'AWS IoT Core client not available'
            if iot_data_error:
                error_msg += f': {iot_data_error}'
            return jsonify({
                'success': False,
                'error': error_msg,
                'details': 'Please check AWS credentials and IoT endpoint configuration in Railway environment variables'
            }), 500
        
        # Validate topic configuration
        if not config.AWS_IOT_TOPIC_SUBSCRIBE:
            return jsonify({
                'success': False,
                'error': 'AWS IoT topic not configured'
            }), 500
        
        # Publish via AWS IoT Core
        try:
            topic = config.AWS_IOT_TOPIC_SUBSCRIBE
            print(f"[COMMAND] Publishing to topic: {topic}")
            print(f"[COMMAND] Payload: {payload[:200]}...")  # Log first 200 chars
            
            response = iot_data.publish(
                topic=topic,
                qos=1,
                payload=payload
            )
            
            # Check response
            http_status = response.get('ResponseMetadata', {}).get('HTTPStatusCode', 0)
            if http_status == 200:
                print(f"[COMMAND] ✓ Command sent successfully (HTTP {http_status})")
                return jsonify({
                    'success': True,
                    'message': 'Command sent via AWS IoT Core',
                    'topic': topic,
                    'device_id': device_id
                })
            else:
                print(f"[COMMAND] ⚠️ Unexpected HTTP status: {http_status}")
                return jsonify({
                    'success': False,
                    'error': f'AWS IoT Core returned HTTP status {http_status}',
                    'response': str(response)
                }), 500
                
        except Exception as e:
            error_msg = str(e)
            error_type = type(e).__name__
            print(f"[COMMAND] ❌ AWS IoT publish failed: {error_type}: {error_msg}")
            import traceback
            traceback.print_exc()
            
            # Provide helpful error messages based on exception type
            if 'CredentialsError' in error_type or 'InvalidAccessKeyId' in error_type:
                error_details = 'Invalid AWS credentials. Please check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.'
            elif 'EndpointConnectionError' in error_type or 'ConnectionError' in error_type:
                error_details = f'Cannot connect to AWS IoT endpoint: {config.AWS_IOT_ENDPOINT}. Check endpoint and network connectivity.'
            elif 'UnauthorizedOperation' in error_type or 'AccessDenied' in error_type:
                error_details = 'AWS credentials do not have permission to publish to IoT Core. Check IAM policies.'
            else:
                error_details = f'AWS IoT publish failed: {error_msg}'
            
            return jsonify({
                'success': False,
                'error': 'Failed to send command via AWS IoT Core',
                'details': error_details,
                'exception_type': error_type
            }), 500
        
    except Exception as e:
        print(f"[COMMAND] ❌ Unexpected error in send_command: {e}")
        import traceback
        traceback.print_exc()
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

@app.route('/api/ota/push-to-github', methods=['POST'])
@login_required
def push_firmware_to_github():
    """Push ESP32 firmware code to GitHub repository AND create release with .bin file"""
    try:
        data = request.json
        firmware_code = data.get('code', '')
        firmware_bin_base64 = data.get('bin_file', '')  # Base64-encoded .bin file
        commit_message = data.get('message', 'OTA firmware update')
        version = data.get('version', '')  # Optional version tag (e.g., "v1.0.1")

        if not firmware_code:
            return jsonify({
                'success': False,
                'error': 'Firmware code is required'
            }), 400

        # Check if code looks like it's already base64 encoded (common mistake)
        if len(firmware_code) > 100 and not any(keyword in firmware_code for keyword in ['#include', 'void setup', 'void loop', 'Serial.', 'WiFi.', '//', '/*']):
            try:
                decoded = base64.b64decode(firmware_code).decode('utf-8')
                if any(keyword in decoded for keyword in ['#include', 'void setup', 'void loop']):
                    firmware_code = decoded
            except:
                pass

        # Validate it looks like Arduino code
        if not any(keyword in firmware_code for keyword in ['#include', 'void setup', 'void loop', 'setup()', 'loop()']):
            return jsonify({
                'success': False,
                'error': 'Code does not appear to be valid Arduino/ESP32 code.'
            }), 400

        # Validate GitHub configuration
        if not config.GITHUB_TOKEN or not config.GITHUB_REPO_OWNER or not config.GITHUB_REPO_NAME:
            return jsonify({
                'success': False,
                'error': 'GitHub configuration is missing'
            }), 500

        headers = {
            'Authorization': f'token {config.GITHUB_TOKEN}',
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json'
        }

        # Step 1: Push .ino source code to repo
        api_url = f"https://api.github.com/repos/{config.GITHUB_REPO_OWNER}/{config.GITHUB_REPO_NAME}/contents/{config.GITHUB_FIRMWARE_PATH}"
        
        # Check if file exists and get SHA
        response = requests.get(api_url, headers=headers, params={'ref': config.GITHUB_REPO_BRANCH})
        sha = None
        if response.status_code == 200:
            sha = response.json().get('sha')
        elif response.status_code != 404:
            return jsonify({
                'success': False,
                'error': f'GitHub API error: {response.status_code}'
            }), 500

        # Encode firmware code to base64
        firmware_encoded = base64.b64encode(firmware_code.encode('utf-8')).decode('utf-8')

        payload = {
            'message': commit_message,
            'content': firmware_encoded,
            'branch': config.GITHUB_REPO_BRANCH
        }
        if sha:
            payload['sha'] = sha

        response = requests.put(api_url, headers=headers, json=payload)
        if response.status_code not in [200, 201]:
            error_msg = response.json().get('message', response.text) if response.text else 'Unknown error'
            return jsonify({
                'success': False,
                'error': f'Failed to push source code ({response.status_code}): {error_msg}'
            }), 500

        result = response.json()
        commit_sha = result.get('commit', {}).get('sha', 'unknown')
        commit_url = result.get('commit', {}).get('html_url', '')

        # Step 2: Create GitHub Release with .bin file (if provided)
        release_tag = version
        release_created = False
        release_url = ''
        
        if firmware_bin_base64:
            # Auto-generate version if not provided (format: v1.0.0, v1.0.1, etc.)
            if not release_tag:
                # Get latest release to auto-increment version
                releases_url = f"https://api.github.com/repos/{config.GITHUB_REPO_OWNER}/{config.GITHUB_REPO_NAME}/releases"
                releases_response = requests.get(releases_url, headers=headers, params={'per_page': 1})
                
                if releases_response.status_code == 200:
                    releases = releases_response.json()
                    if releases and len(releases) > 0:
                        latest_tag = releases[0].get('tag_name', 'v0.0.0')
                        # Simple version increment: v1.0.0 -> v1.0.1
                        try:
                            parts = latest_tag.lstrip('v').split('.')
                            if len(parts) == 3:
                                patch = int(parts[2]) + 1
                                release_tag = f"v{parts[0]}.{parts[1]}.{patch}"
                            else:
                                release_tag = f"v1.0.{int(time.time()) % 10000}"  # Fallback: use timestamp
                        except:
                            release_tag = f"v1.0.{int(time.time()) % 10000}"
                    else:
                        release_tag = "v1.0.0"  # First release
                else:
                    release_tag = f"v1.0.{int(time.time()) % 10000}"  # Fallback
            
            # Create release
            release_payload = {
                'tag_name': release_tag,
                'name': release_tag,
                'body': f'OTA Firmware Update\n\nCommit: {commit_sha[:7]}\nMessage: {commit_message}',
                'draft': False,
                'prerelease': False
            }
            
            create_release_url = f"https://api.github.com/repos/{config.GITHUB_REPO_OWNER}/{config.GITHUB_REPO_NAME}/releases"
            release_response = requests.post(create_release_url, headers=headers, json=release_payload)
            
            if release_response.status_code == 201:
                release_data = release_response.json()
                release_id = release_data.get('id')
                upload_url = release_data.get('upload_url', '').split('{')[0]  # Remove {?name,label} suffix
                release_url = release_data.get('html_url', '')
                
                # Upload .bin file as release asset
                firmware_bin_data = base64.b64decode(firmware_bin_base64)
                asset_name = config.GITHUB_FIRMWARE_ASSET_NAME if hasattr(config, 'GITHUB_FIRMWARE_ASSET_NAME') else 'esp32_main.ino.bin'
                
                upload_headers = {
                    'Authorization': f'token {config.GITHUB_TOKEN}',
                    'Content-Type': 'application/octet-stream'
                }
                
                upload_response = requests.post(
                    f"{upload_url}?name={asset_name}",
                    headers=upload_headers,
                    data=firmware_bin_data
                )
                
                if upload_response.status_code == 201:
                    release_created = True
                    print(f"[OTA] ✓ Release created: {release_tag} with asset: {asset_name}")
                else:
                    print(f"[OTA] ⚠️ Release created but asset upload failed: {upload_response.status_code}")
            else:
                print(f"[OTA] ⚠️ Failed to create release: {release_response.status_code}")
                print(f"[OTA] Response: {release_response.text}")

        return jsonify({
            'success': True,
            'message': 'Firmware pushed to GitHub successfully',
            'commit_sha': commit_sha,
            'commit_url': commit_url,
            'release_created': release_created,
            'release_tag': release_tag if release_created else None,
            'release_url': release_url if release_created else None
        })
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/ota/test-mqtt', methods=['POST'])
@login_required
def test_mqtt():
    """Test MQTT connection by sending a simple message"""
    try:
        if not iot_data:
            return jsonify({
                'success': False,
                'error': 'AWS IoT Data client not available'
            }), 500
        
        test_command = {
            'type': 'test',
            'message': 'MQTT test message',
            'timestamp': int(time.time())
        }
        
        topic = config.AWS_IOT_TOPIC_SUBSCRIBE
        payload = json.dumps(test_command)
        
        print(f"\n[TEST] Sending test MQTT message to {topic}")
        response = iot_data.publish(
            topic=topic,
            qos=1,
            payload=payload
        )
        
        http_status = response.get('ResponseMetadata', {}).get('HTTPStatusCode', 'Unknown')
        
        return jsonify({
            'success': http_status == 200,
            'message': 'Test MQTT message sent',
            'topic': topic,
            'http_status': http_status,
            'response': str(response)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/ota/trigger-update', methods=['POST'])
@login_required
def trigger_ota_update():
    """Send MQTT command to ESP32 to trigger OTA update from GitHub"""
    try:
        data = request.json
        device_id = data.get('device_id', '')
        version = data.get('version', 'latest')
        commit_sha = data.get('commit_sha', '')
        
        if not device_id:
            return jsonify({
                'success': False,
                'error': 'Device ID is required'
            }), 400
        
        # Validate GitHub configuration
        if not config.GITHUB_TOKEN or not config.GITHUB_REPO_OWNER or not config.GITHUB_REPO_NAME:
            return jsonify({
                'success': False,
                'error': 'GitHub configuration is missing'
            }), 500
        
        # Build GitHub raw file URL for firmware download
        # Format: https://raw.githubusercontent.com/owner/repo/branch/path
        firmware_url = f"https://raw.githubusercontent.com/{config.GITHUB_REPO_OWNER}/{config.GITHUB_REPO_NAME}/{config.GITHUB_REPO_BRANCH}/{config.GITHUB_FIRMWARE_PATH}"
        
        # Build GitHub API URL for getting file (with auth token)
        # ESP32 will use this to download firmware
        github_api_url = f"https://api.github.com/repos/{config.GITHUB_REPO_OWNER}/{config.GITHUB_REPO_NAME}/contents/{config.GITHUB_FIRMWARE_PATH}"
        
        # Create OTA command - MINIMAL (ESP32 has hardcoded GitHub values)
        # Only send essential info, ESP32 will use hardcoded repo details
        ota_command = {
            'type': 'ota_update',
            'version': version,
            'commit_sha': commit_sha if commit_sha else 'latest'
        }
        # Note: ESP32 will use hardcoded GITHUB_REPO_OWNER, GITHUB_REPO_NAME, etc.
        # Only send token if needed (ESP32 also has it hardcoded)
        
        # Print the exact OTA command for debugging
        ota_json = json.dumps(ota_command, indent=2)
        print(f"\n[OTA] OTA Command JSON:")
        print(ota_json)
        print(f"[OTA] Command size: {len(ota_json)} bytes\n")
        
        # Send via AWS IoT Core
        if iot_data:
            try:
                topic = config.AWS_IOT_TOPIC_SUBSCRIBE
                payload = json.dumps(ota_command)
                
                print(f"\n{'='*60}")
                print(f"[OTA] Publishing MQTT message to AWS IoT Core")
                print(f"[OTA] Topic: {topic}")
                print(f"[OTA] Payload length: {len(payload)} bytes")
                print(f"[OTA] Payload preview: {payload[:300]}...")
                print(f"{'='*60}\n")
                
                # Publish to AWS IoT Core
                response = iot_data.publish(
                    topic=topic,
                    qos=1,
                    payload=payload
                )
                
                print(f"[OTA] Publish response: {response}")
                print(f"[OTA] Response metadata: {response.get('ResponseMetadata', {})}")
                
                # Verify the message was sent
                if 'ResponseMetadata' in response:
                    http_status = response['ResponseMetadata'].get('HTTPStatusCode', 'Unknown')
                    print(f"[OTA] HTTP Status Code: {http_status}")
                    if http_status == 200:
                        print(f"[OTA] ✓ Message published successfully to {topic}")
                    else:
                        print(f"[OTA] ⚠️ Unexpected HTTP status: {http_status}")
                
                return jsonify({
                    'success': True,
                    'message': 'OTA update command sent to device',
                    'device_id': device_id,
                    'firmware_url': firmware_url,
                    'topic': topic,
                    'payload_length': len(payload),
                    'http_status': response.get('ResponseMetadata', {}).get('HTTPStatusCode', 'Unknown')
                })
            except Exception as e:
                error_msg = str(e)
                print(f"[OTA] AWS IoT publish failed: {error_msg}")
                import traceback
                traceback.print_exc()
                return jsonify({
                    'success': False,
                    'error': f'Failed to send OTA command via AWS IoT Core: {error_msg}'
                }), 500
        
        return jsonify({
            'success': False,
            'error': 'AWS IoT Core client not available. Check AWS credentials and IoT endpoint configuration.'
        }), 500
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


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
    print(f"MongoDB Collection: {config.MONGO_DB_NAME}.{config.MONGO_COLLECTION}")
    print(f"WebSocket enabled: SocketIO")
    print("=" * 50)
    
    socketio.run(
        app,
        host=config.HOST,
        port=config.PORT,
        debug=config.DEBUG,
        use_reloader=False,
        allow_unsafe_werkzeug=True
    )

