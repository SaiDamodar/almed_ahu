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
from pymongo.errors import PyMongoError, DuplicateKeyError
from zoneinfo import ZoneInfo
from github import Github
from github.GithubException import GithubException
import requests
from werkzeug.security import generate_password_hash, check_password_hash
from bson import ObjectId
import os

# Firebase Admin SDK for push notifications
firebase_app = None
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    
    # Initialize Firebase Admin SDK
    if config.FIREBASE_SERVICE_ACCOUNT_JSON:
        # Use inline credentials (base64 encoded)
        import base64
        cred_json = json.loads(base64.b64decode(config.FIREBASE_SERVICE_ACCOUNT_JSON))
        cred = credentials.Certificate(cred_json)
        firebase_app = firebase_admin.initialize_app(cred)
        print("✓ Firebase Admin SDK initialized (from inline JSON)")
    elif os.path.exists(config.FIREBASE_SERVICE_ACCOUNT_PATH):
        # Use service account file
        cred = credentials.Certificate(config.FIREBASE_SERVICE_ACCOUNT_PATH)
        firebase_app = firebase_admin.initialize_app(cred)
        print(f"✓ Firebase Admin SDK initialized (from {config.FIREBASE_SERVICE_ACCOUNT_PATH})")
    else:
        print("⚠ Firebase: No service account found. Push notifications disabled.")
        print(f"  - Looked for file: {config.FIREBASE_SERVICE_ACCOUNT_PATH}")
        print("  - FIREBASE_SERVICE_ACCOUNT_JSON env var is empty")
except ImportError:
    print("⚠ Firebase Admin SDK not installed. Push notifications disabled.")
except Exception as e:
    print(f"❌ Firebase initialization error: {e}")

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
mongo_users_collection = None  # Users collection
mongo_tickets_collection = None  # Support tickets collection
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
    global mongo_client, mongo_collection, mongo_users_collection, mongo_tickets_collection
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
        # Initialize users collection
        mongo_users_collection = mongo_db['users']
        # Initialize tickets collection
        mongo_tickets_collection = mongo_db['support_tickets']
        # Create unique index on email
        try:
            mongo_users_collection.create_index([('email', 1)], unique=True)
        except Exception as e:
            print(f"Note: Email index may already exist: {e}")
        
        # Create indexes for tickets
        try:
            mongo_tickets_collection.create_index([('user_id', 1)])
            mongo_tickets_collection.create_index([('status', 1)])
            mongo_tickets_collection.create_index([('created_at', -1)])
        except Exception as e:
            print(f"Note: Tickets indexes may already exist: {e}")
        
        # Drop firebase_uid index if it exists (causes duplicate key errors with null values)
        try:
            mongo_users_collection.drop_index('firebase_uid_unique')
            print("Dropped firebase_uid_unique index")
        except Exception as e:
            # Index doesn't exist or already dropped
            pass
        
        # Force connection test with longer timeout
        mongo_client.admin.command('ping', maxTimeMS=30000)
        print(f"✓ MongoDB: Connected to {config.MONGO_DB_NAME}.{config.MONGO_COLLECTION}")
        print(f"✓ MongoDB: Users collection initialized")
        print(f"✓ MongoDB: Tickets collection initialized")
    except Exception as e:
        mongo_client = None
        mongo_collection = None
        mongo_users_collection = None
        mongo_tickets_collection = None
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
    
    # Extract location metadata from payload
    site = payload.get('site', 'unknown')
    room = payload.get('room', 'unknown')
    ahu = payload.get('ahu', 'unknown')
    
    document = {
        'device_id': device_id,
        'site': site,
        'room': room,
        'ahu': ahu,
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
        
        # Extract location metadata from payload (new fields from ESP32)
        site = payload.get('site', 'unknown')
        room = payload.get('room', 'unknown')
        ahu = payload.get('ahu', 'unknown')
        
        # Create composite device_id from location (for backward compatibility with existing code)
        # Format: site_room_ahu (e.g., "hospitalA_icu1_ahu-01")
        device_id = f"{site}_{room}_{ahu}" if (site != 'unknown' and room != 'unknown' and ahu != 'unknown') else payload.get('thing', 'unknown')
        
        # Determine message type
        msg_type = payload.get('type', 'telemetry')
        
        # Update device cache (store location metadata)
        if device_id not in device_cache:
            device_cache[device_id] = {
                'site': site,
                'room': room,
                'ahu': ahu
            }
        else:
            # Update location metadata if not already set
            if 'site' not in device_cache[device_id]:
                device_cache[device_id]['site'] = site
            if 'room' not in device_cache[device_id]:
                device_cache[device_id]['room'] = room
            if 'ahu' not in device_cache[device_id]:
                device_cache[device_id]['ahu'] = ahu
        
        if msg_type == 'telemetry':
            device_cache[device_id]['telemetry'] = payload
            device_cache[device_id]['last_update'] = time.time()
        elif msg_type == 'state':
            device_cache[device_id]['state'] = payload
            device_cache[device_id]['last_update'] = time.time()
        elif msg_type == 'ota_status':
            # OTA status update from ESP32
            update_esp32_ota_status(device_id, payload)
        elif msg_type == 'ota_verify':
            # OTA verification message from ESP32 (after successful update)
            update_esp32_ota_status(device_id, payload)
        
        # Persist for historical analysis
        store_historical_data(device_id, msg_type, payload)
        
        # Broadcast to all connected WebSocket clients (include location metadata)
        socketio.emit('device_update', {
            'device_id': device_id,
            'site': site,
            'room': room,
            'ahu': ahu,
            'type': msg_type,
            'data': payload,
            'timestamp': time.time()
        })
        
        print(f"AWS IoT MQTT: Received {msg_type} from {site}/{room}/{ahu} (device_id: {device_id})")
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
    # Allow login page and API endpoints that don't require authentication
    allowed_endpoints = ['login', 'api_login', 'verify_admin', 'api_register', 'api_user_login', 'api_register_google', 'api_user_login_google', 'static', 'health_check']
    if request.endpoint in allowed_endpoints:
        return None
    # Allow public API endpoints (registration and user login)
    if request.path in ['/api/register', '/api/user/login', '/api/register/google', '/api/user/login/google', '/api/health']:
        return None
    # Require authentication for all other routes (admin or user)
    is_authenticated = session.get('authenticated') or session.get('user_id')
    if not is_authenticated:
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
    # Verify admin access
    if not session.get('authenticated'):
        return redirect(url_for('login'))
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

        def format_device_name(ahu_id, device_id=None):
            """Format device name from ahu field, fallback to device_id formatting"""
            if ahu_id and ahu_id != 'unknown':
                # Use the ahu field directly (e.g., "ahu-01" -> "AHU-01")
                # Normalize: convert to uppercase and ensure consistent formatting
                name = ahu_id.upper()
                # Normalize underscores to hyphens
                name = name.replace('_', '-')
                # Ensure it starts with AHU- (in case it's just "01")
                if not name.startswith('AHU'):
                    name = f'AHU-{name}'
                return name
            # Fallback to old formatting if ahu not available
            if device_id:
                cleaned = (
                    device_id.replace('ahu-', '')
                    .replace('AHU_', '')
                    .replace('ESP2', '')
                    .strip()
                    .upper()
                )
                return f'AHU {cleaned or "ESP2"}'
            return 'AHU Unknown'

        def add_device_record(device_id, telemetry=None, state=None, last_seen=None):
            nonlocal hospitals
            telemetry = telemetry or {}
            state = state or {}
            source = telemetry if telemetry else state

            # Extract location metadata from payload (preferred) or cache
            site = source.get('site', state.get('site', 'unknown'))
            room = source.get('room', state.get('room', 'unknown'))
            ahu = source.get('ahu', state.get('ahu', 'unknown'))
            
            # Fallback to defaults if not in payload
            if site == 'unknown':
                site = 'hospitalA'
            if room == 'unknown':
                room = 'icu1'
            if ahu == 'unknown':
                # Try to extract from device_id format (site_room_ahu)
                parts = device_id.split('_')
                if len(parts) >= 3:
                    site = parts[0] if parts[0] != 'unknown' else site
                    room = parts[1] if parts[1] != 'unknown' else room
                    ahu = parts[2] if parts[2] != 'unknown' else ahu

            if site not in hospitals:
                hospitals[site] = {}
            if room not in hospitals[site]:
                hospitals[site][room] = []

            # Use ahu field for device name
            device_name = format_device_name(ahu, device_id)

            hospitals[site][room].append({
                'id': device_id,
                'name': device_name,
                'site': site,
                'room': room,
                'ahu': ahu,
                'last_seen': last_seen
            })
            seen_devices.add(device_id)
        
        for device_id, data in device_cache.items():
            # Get location metadata from cache (stored in on_aws_iot_message)
            site = data.get('site', 'unknown')
            room = data.get('room', 'unknown')
            ahu = data.get('ahu', 'unknown')
            
            # Try to get from telemetry or state payloads (in case cache metadata missing)
            telemetry = data.get('telemetry', {})
            state = data.get('state', {})
            
            if site == 'unknown' and 'site' in telemetry:
                site = telemetry['site']
            elif site == 'unknown' and 'site' in state:
                site = state['site']
            
            if room == 'unknown' and 'room' in telemetry:
                room = telemetry['room']
            elif room == 'unknown' and 'room' in state:
                room = state['room']
            
            if ahu == 'unknown' and 'ahu' in telemetry:
                ahu = telemetry['ahu']
            elif ahu == 'unknown' and 'ahu' in state:
                ahu = state['ahu']
            
            # Fallback defaults
            if site == 'unknown':
                site = 'hospitalA'
            if room == 'unknown':
                room = 'icu1'
            if ahu == 'unknown':
                # Try to extract from device_id format (site_room_ahu)
                parts = device_id.split('_')
                if len(parts) >= 3:
                    site = parts[0] if parts[0] != 'unknown' else site
                    room = parts[1] if parts[1] != 'unknown' else room
                    ahu = parts[2] if parts[2] != 'unknown' else ahu
            
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
                    # Try to get location from doc first, then from payload
                    payload = doc.get('payload', {})
                    site = doc.get('site', payload.get('site', 'unknown'))
                    room = doc.get('room', payload.get('room', 'unknown'))
                    ahu = doc.get('ahu', payload.get('ahu', 'unknown'))
                    
                    # Update payload with location if missing
                    if 'site' not in payload and site != 'unknown':
                        payload['site'] = site
                    if 'room' not in payload and room != 'unknown':
                        payload['room'] = room
                    if 'ahu' not in payload and ahu != 'unknown':
                        payload['ahu'] = ahu
                    
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

@app.route('/api/register', methods=['POST'])
def api_register():
    """Register new hospital user"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    try:
        data = request.json
        email = data.get('email', '').strip().lower()
        username = data.get('username', '').strip()
        phone_number = data.get('phone_number', '').strip()
        hospital_name = data.get('hospital_name', '').strip()
        password = data.get('password', '')
        google_id = data.get('google_id')
        profile_image_url = data.get('profile_image_url')
        
        print(f"Registration attempt - Email: {email}, Username: {username}")
        
        # Validation
        if not email or '@' not in email:
            return jsonify({
                'success': False,
                'message': 'Valid email is required'
            }), 400
        
        if not username:
            return jsonify({
                'success': False,
                'message': 'Username is required'
            }), 400
        
        if not phone_number:
            return jsonify({
                'success': False,
                'message': 'Phone number is required'
            }), 400
        
        if not hospital_name:
            return jsonify({
                'success': False,
                'message': 'Hospital name is required'
            }), 400
        
        # Password is optional for Google users
        if not google_id and (not password or len(password) < 6):
            return jsonify({
                'success': False,
                'message': 'Password must be at least 6 characters'
            }), 400
        
        # Check if user already exists
        # Email is already lowercased, so just check exact match
        existing_user = mongo_users_collection.find_one({'email': email})
        if existing_user:
            print(f"Registration failed - Email already exists: {email}")
            print(f"Existing user: {existing_user.get('_id')}, {existing_user.get('email')}")
            return jsonify({
                'success': False,
                'message': 'Email already registered'
            }), 400
        
        print(f"Email {email} is available, proceeding with registration")
        
        # Hash password (only if provided, Google users don't need password)
        password_hash = None
        if password:
            password_hash = generate_password_hash(password)
        
        # Create user document
        user_doc = {
            'email': email,
            'username': username,
            'phone_number': phone_number,
            'hospital_name': hospital_name,
            'status': 'pending',  # pending, approved, active, rejected, suspended
            'access_level': 'viewer',  # viewer (read-only) or operator (full control)
            'assigned_ahu_ids': [],
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        # Only add password if provided (not for Google users)
        if password_hash:
            user_doc['password'] = password_hash
        
        if google_id:
            user_doc['google_id'] = google_id
        
        if profile_image_url:
            user_doc['profile_image_url'] = profile_image_url
        
        # Insert user
        try:
            result = mongo_users_collection.insert_one(user_doc)
            user_id = str(result.inserted_id)
            print(f"User registered successfully: {email}, ID: {user_id}")
        except DuplicateKeyError as e:
            print(f"DuplicateKeyError during registration: {e}")
            # Double-check if email exists (race condition)
            existing_user = mongo_users_collection.find_one({'email': email})
            if existing_user:
                print(f"Confirmed duplicate email: {email} (existing user ID: {existing_user.get('_id')})")
                return jsonify({
                    'success': False,
                    'message': 'Email already registered'
                }), 400
            else:
                # Re-raise if it's a different duplicate key error
                print(f"DuplicateKeyError but email not found in DB - re-raising")
                raise
        
        # Return user data (without password)
        user_data = {
            '_id': user_id,
            'email': email,
            'username': username,
            'phone_number': phone_number,
            'hospital_name': hospital_name,
            'status': 'pending',
            'assigned_ahu_ids': [],
            'created_at': user_doc['created_at'].isoformat(),
            'updated_at': user_doc['updated_at'].isoformat()
        }
        
        if google_id:
            user_data['google_id'] = google_id
        if profile_image_url:
            user_data['profile_image_url'] = profile_image_url
        
        return jsonify({
            'success': True,
            'user': user_data,
            'message': 'Registration successful. Waiting for admin approval.'
        }), 201
        
    except Exception as e:
        print(f"Registration error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Registration failed: {str(e)}'
        }), 500

@app.route('/api/register/google', methods=['POST'])
def api_register_google():
    """Register new hospital user with Google authentication"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    try:
        data = request.json
        if not data:
            print("Google Registration: No JSON data received")
            return jsonify({
                'success': False,
                'message': 'No data received'
            }), 400
        
        print(f"Google Registration: Received data: {data}")
        
        email = data.get('email', '').strip().lower()
        username = data.get('username', '').strip()
        phone_number = data.get('phone_number', '').strip()
        hospital_name = data.get('hospital_name', '').strip()
        google_id = data.get('google_id', '')
        profile_image_url = data.get('profile_image_url')
        id_token = data.get('id_token', '')
        
        print(f"Google Registration attempt - Email: '{email}', Google ID: '{google_id}', Username: '{username}'")
        
        # Validate required fields
        if not email or '@' not in email:
            return jsonify({
                'success': False,
                'message': 'Valid email is required'
            }), 400
        
        if not username:
            return jsonify({
                'success': False,
                'message': 'Username is required'
            }), 400
        
        if not phone_number:
            return jsonify({
                'success': False,
                'message': 'Phone number is required'
            }), 400
        
        if not hospital_name:
            return jsonify({
                'success': False,
                'message': 'Hospital name is required'
            }), 400
        
        if not google_id:
            return jsonify({
                'success': False,
                'message': 'Google ID is required'
            }), 400
        
        # TODO: Verify Firebase ID token here
        # For now, we'll trust the client, but in production you should verify the token
        # using Firebase Admin SDK
        
        # Check if user already exists by email or google_id
        existing_user = mongo_users_collection.find_one({
            '$or': [
                {'email': email},
                {'google_id': google_id}
            ]
        })
        if existing_user:
            print(f"Google Registration failed - User already exists: {email}")
            return jsonify({
                'success': False,
                'message': 'Email or Google account already registered'
            }), 400
        
        print(f"Email {email} is available, proceeding with Google registration")
        
        # Create user document (no password for Google users)
        user_doc = {
            'email': email,
            'username': username,
            'phone_number': phone_number,
            'hospital_name': hospital_name,
            'google_id': google_id,
            'status': 'pending',
            'access_level': 'viewer',  # viewer (read-only) or operator (full control)
            'assigned_ahu_ids': [],
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        if profile_image_url:
            user_doc['profile_image_url'] = profile_image_url
        
        # Insert user
        try:
            result = mongo_users_collection.insert_one(user_doc)
            user_id = str(result.inserted_id)
            print(f"User registered successfully with Google: {email}, ID: {user_id}")
        except DuplicateKeyError as e:
            print(f"DuplicateKeyError during Google registration: {e}")
            existing_user = mongo_users_collection.find_one({'email': email})
            if existing_user:
                return jsonify({
                    'success': False,
                    'message': 'Email already registered'
                }), 400
            raise
        
        # Return user data
        user_data = {
            '_id': user_id,
            'email': email,
            'username': username,
            'phone_number': phone_number,
            'hospital_name': hospital_name,
            'status': 'pending',
            'assigned_ahu_ids': [],
            'created_at': user_doc['created_at'].isoformat(),
            'updated_at': user_doc['updated_at'].isoformat()
        }
        
        if profile_image_url:
            user_data['profile_image_url'] = profile_image_url
        
        return jsonify({
            'success': True,
            'user': user_data,
            'message': 'Registration successful. Waiting for admin approval.'
        }), 201
        
    except Exception as e:
        print(f"Google Registration error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Registration failed: {str(e)}'
        }), 500

@app.route('/api/user/login', methods=['POST'])
def api_user_login():
    """Hospital user login"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    try:
        data = request.json
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        
        if not email or not password:
            return jsonify({
                'success': False,
                'message': 'Email and password are required'
            }), 400
        
        # Find user
        user = mongo_users_collection.find_one({'email': email})
        if not user:
            return jsonify({
                'success': False,
                'message': 'Invalid email or password'
            }), 401
        
        # Check password (skip if user has Google ID and no password)
        user_password = user.get('password')
        if user_password:
            # User has password, verify it
            if not check_password_hash(user_password, password):
                return jsonify({
                    'success': False,
                    'message': 'Invalid email or password'
                }), 401
        elif not user.get('google_id'):
            # User has no password and no Google ID - invalid account
            return jsonify({
                'success': False,
                'message': 'Invalid email or password'
            }), 401
        
        # Create session
        session['user_id'] = str(user['_id'])
        session['user_email'] = user['email']
        session['user_type'] = 'hospital_user'
        session.permanent = True
        
        # Return user data (without password)
        user_data = {
            '_id': str(user['_id']),
            'email': user['email'],
            'username': user.get('username', ''),
            'phone_number': user.get('phone_number', ''),
            'hospital_name': user.get('hospital_name', ''),
            'status': user.get('status', 'pending'),
            'access_level': user.get('access_level', 'viewer'),  # viewer or operator
            'assigned_ahu_ids': user.get('assigned_ahu_ids', []),
            'created_at': user.get('created_at', datetime.utcnow()).isoformat() if isinstance(user.get('created_at'), datetime) else str(user.get('created_at', '')),
            'updated_at': user.get('updated_at', datetime.utcnow()).isoformat() if isinstance(user.get('updated_at'), datetime) else str(user.get('updated_at', ''))
        }
        
        if 'google_id' in user:
            user_data['google_id'] = user['google_id']
        if 'profile_image_url' in user:
            user_data['profile_image_url'] = user['profile_image_url']
        
        return jsonify({
            'success': True,
            'user': user_data,
            'message': 'Login successful'
        })
        
    except Exception as e:
        print(f"User login error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Login failed: {str(e)}'
        }), 500

@app.route('/api/user/status', methods=['GET'])
def api_user_status():
    """Get current logged-in user status"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    # Check if user is logged in
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({
            'success': False,
            'message': 'Not authenticated'
        }), 401
    
    try:
        # Find user
        user = mongo_users_collection.find_one({'_id': ObjectId(user_id)})
        if not user:
            # Clear invalid session
            session.pop('user_id', None)
            session.pop('user_email', None)
            session.pop('user_type', None)
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        # Return user data (without password)
        user_data = {
            '_id': str(user['_id']),
            'email': user['email'],
            'username': user.get('username', ''),
            'phone_number': user.get('phone_number', ''),
            'hospital_name': user.get('hospital_name', ''),
            'status': user.get('status', 'pending'),
            'access_level': user.get('access_level', 'viewer'),  # viewer or operator
            'assigned_ahu_ids': user.get('assigned_ahu_ids', []),
            'created_at': user.get('created_at', datetime.utcnow()).isoformat() if isinstance(user.get('created_at'), datetime) else str(user.get('created_at', '')),
            'updated_at': user.get('updated_at', datetime.utcnow()).isoformat() if isinstance(user.get('updated_at'), datetime) else str(user.get('updated_at', ''))
        }
        
        if 'google_id' in user:
            user_data['google_id'] = user['google_id']
        if 'profile_image_url' in user:
            user_data['profile_image_url'] = user['profile_image_url']
        
        return jsonify({
            'success': True,
            'user': user_data
        })
        
    except Exception as e:
        print(f"Get user status error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to get user status: {str(e)}'
        }), 500

@app.route('/api/user/login/google', methods=['POST'])
def api_user_login_google():
    """Hospital user login with Google"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    try:
        data = request.json
        google_id = data.get('google_id', '')
        email = data.get('email', '').strip().lower()
        id_token = data.get('id_token', '')
        
        if not google_id or not email:
            return jsonify({
                'success': False,
                'message': 'Google ID and email are required'
            }), 400
        
        # TODO: Verify Firebase ID token here
        # For now, we'll trust the client, but in production you should verify the token
        
        # Find user by Google ID or email
        user = mongo_users_collection.find_one({
            '$or': [
                {'google_id': google_id},
                {'email': email}
            ]
        })
        
        if not user:
            return jsonify({
                'success': False,
                'message': 'User not found. Please register first.'
            }), 404
        
        # Update Google ID if not set
        if not user.get('google_id'):
            mongo_users_collection.update_one(
                {'_id': user['_id']},
                {'$set': {'google_id': google_id, 'updated_at': datetime.utcnow()}}
            )
        
        # Create session
        session['user_id'] = str(user['_id'])
        session['user_email'] = user['email']
        session['user_type'] = 'hospital_user'
        session.permanent = True
        
        # Return user data
        user_data = {
            '_id': str(user['_id']),
            'email': user['email'],
            'username': user.get('username', ''),
            'phone_number': user.get('phone_number', ''),
            'hospital_name': user.get('hospital_name', ''),
            'status': user.get('status', 'pending'),
            'access_level': user.get('access_level', 'viewer'),  # viewer or operator
            'assigned_ahu_ids': user.get('assigned_ahu_ids', []),
            'created_at': user.get('created_at', datetime.utcnow()).isoformat() if isinstance(user.get('created_at'), datetime) else str(user.get('created_at', '')),
            'updated_at': user.get('updated_at', datetime.utcnow()).isoformat() if isinstance(user.get('updated_at'), datetime) else str(user.get('updated_at', ''))
        }
        
        if 'google_id' in user:
            user_data['google_id'] = user['google_id']
        if 'profile_image_url' in user:
            user_data['profile_image_url'] = user['profile_image_url']
        
        return jsonify({
            'success': True,
            'user': user_data,
            'message': 'Login successful'
        })
        
    except Exception as e:
        print(f"Google login error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Login failed: {str(e)}'
        }), 500

# ==================== Admin User Management Endpoints ====================

@app.route('/api/admin/users/pending', methods=['GET'])
@login_required
def api_get_pending_users():
    """Get all pending user registrations (admin only)"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        # Find all users with status 'pending'
        users = list(mongo_users_collection.find({'status': 'pending'}).sort('created_at', DESCENDING))
        
        users_data = []
        for user in users:
            user_data = {
                '_id': str(user['_id']),
                'email': user['email'],
                'username': user.get('username', ''),
                'phone_number': user.get('phone_number', ''),
                'hospital_name': user.get('hospital_name', ''),
                'status': user.get('status', 'pending'),
                'created_at': user.get('created_at', datetime.utcnow()).isoformat() if isinstance(user.get('created_at'), datetime) else str(user.get('created_at', ''))
            }
            if 'google_id' in user:
                user_data['google_id'] = user['google_id']
            if 'profile_image_url' in user:
                user_data['profile_image_url'] = user['profile_image_url']
            users_data.append(user_data)
        
        return jsonify({
            'success': True,
            'users': users_data
        })
        
    except Exception as e:
        print(f"Get pending users error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to get pending users: {str(e)}'
        }), 500

@app.route('/api/admin/users/registered', methods=['GET'])
@login_required
def api_get_registered_users():
    """Get all registered/approved users (admin only)"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        # Find all users with status 'approved' or 'active'
        users = list(mongo_users_collection.find({
            'status': {'$in': ['approved', 'active']}
        }).sort('created_at', DESCENDING))
        
        users_data = []
        for user in users:
            user_data = {
                '_id': str(user['_id']),
                'email': user['email'],
                'username': user.get('username', ''),
                'phone_number': user.get('phone_number', ''),
                'hospital_name': user.get('hospital_name', ''),
                'status': user.get('status', 'approved'),
                'access_level': user.get('access_level', 'viewer'),  # viewer or operator
                'assigned_ahu_ids': user.get('assigned_ahu_ids', []),
                'created_at': user.get('created_at', datetime.utcnow()).isoformat() if isinstance(user.get('created_at'), datetime) else str(user.get('created_at', ''))
            }
            if 'google_id' in user:
                user_data['google_id'] = user['google_id']
            if 'profile_image_url' in user:
                user_data['profile_image_url'] = user['profile_image_url']
            users_data.append(user_data)
        
        return jsonify({
            'success': True,
            'users': users_data
        })
        
    except Exception as e:
        print(f"Get registered users error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to get registered users: {str(e)}'
        }), 500

@app.route('/api/admin/users/<user_id>/approve', methods=['POST'])
@login_required
def api_approve_user(user_id):
    """Approve a pending user registration (admin only)"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        # Get access level from request (default to 'viewer' for safety)
        data = request.json or {}
        access_level = data.get('access_level', 'viewer')
        
        # Validate access level
        if access_level not in ['operator', 'viewer']:
            access_level = 'viewer'
        
        # Update user status to 'approved' and set access level
        result = mongo_users_collection.update_one(
            {'_id': ObjectId(user_id), 'status': 'pending'},
            {
                '$set': {
                    'status': 'approved',
                    'access_level': access_level,
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        if result.matched_count == 0:
            return jsonify({
                'success': False,
                'message': 'User not found or already processed'
            }), 404
        
        access_text = 'Operating Access' if access_level == 'operator' else 'View Only'
        return jsonify({
            'success': True,
            'message': f'User approved with {access_text}'
        })
        
    except Exception as e:
        print(f"Approve user error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to approve user: {str(e)}'
        }), 500

@app.route('/api/admin/users/<user_id>/access-level', methods=['POST'])
@login_required
def api_update_access_level(user_id):
    """Update user access level (admin only)"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        data = request.json
        access_level = data.get('access_level', 'viewer')
        
        # Validate access level
        if access_level not in ['operator', 'viewer']:
            return jsonify({
                'success': False,
                'message': 'Invalid access level. Must be "operator" or "viewer"'
            }), 400
        
        # Update user access level
        result = mongo_users_collection.update_one(
            {'_id': ObjectId(user_id)},
            {
                '$set': {
                    'access_level': access_level,
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        if result.matched_count == 0:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        access_text = 'Operating Access' if access_level == 'operator' else 'View Only'
        return jsonify({
            'success': True,
            'message': f'Access level updated to {access_text}'
        })
        
    except Exception as e:
        print(f"Update access level error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to update access level: {str(e)}'
        }), 500

@app.route('/api/admin/users/<user_id>/reject', methods=['POST'])
@login_required
def api_reject_user(user_id):
    """Reject a pending user registration (admin only)"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        # Update user status to 'rejected'
        result = mongo_users_collection.update_one(
            {'_id': ObjectId(user_id), 'status': 'pending'},
            {
                '$set': {
                    'status': 'rejected',
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        if result.matched_count == 0:
            return jsonify({
                'success': False,
                'message': 'User not found or already processed'
            }), 404
        
        return jsonify({
            'success': True,
            'message': 'User rejected successfully'
        })
        
    except Exception as e:
        print(f"Reject user error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to reject user: {str(e)}'
        }), 500

@app.route('/api/admin/users/<user_id>/assign-ahus', methods=['POST'])
@login_required
def api_assign_ahus(user_id):
    """Assign AHU units to a user (admin only)"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        data = request.json
        ahu_ids = data.get('ahu_ids', [])
        
        if not isinstance(ahu_ids, list):
            return jsonify({
                'success': False,
                'message': 'ahu_ids must be a list'
            }), 400
        
        # Update user with assigned AHUs and set status to 'active'
        result = mongo_users_collection.update_one(
            {'_id': ObjectId(user_id)},
            {
                '$set': {
                    'assigned_ahu_ids': ahu_ids,
                    'status': 'active' if ahu_ids else 'approved',
                    'updated_at': datetime.utcnow()
                }
            }
        )
        
        if result.matched_count == 0:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        return jsonify({
            'success': True,
            'message': 'AHUs assigned successfully'
        })
        
    except Exception as e:
        print(f"Assign AHUs error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to assign AHUs: {str(e)}'
        }), 500


# ============================================================================
# Support Tickets API
# ============================================================================

@app.route('/api/tickets', methods=['POST'])
def api_create_ticket():
    """Create a new support ticket (for hospital users)"""
    if mongo_tickets_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    # Check if user is logged in
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({
            'success': False,
            'message': 'Authentication required'
        }), 401
    
    try:
        data = request.json
        title = data.get('title', '').strip()
        description = data.get('description', '').strip()
        ahu_id = data.get('ahu_id', '').strip()
        priority = data.get('priority', 'medium').lower()
        
        if not title:
            return jsonify({
                'success': False,
                'message': 'Title is required'
            }), 400
        
        if not description:
            return jsonify({
                'success': False,
                'message': 'Description is required'
            }), 400
        
        if priority not in ['low', 'medium', 'high', 'critical']:
            priority = 'medium'
        
        # Get user info
        user = mongo_users_collection.find_one({'_id': ObjectId(user_id)})
        if not user:
            return jsonify({
                'success': False,
                'message': 'User not found'
            }), 404
        
        ticket_doc = {
            'user_id': user_id,
            'user_email': user.get('email', ''),
            'user_name': user.get('username', ''),
            'hospital_name': user.get('hospital_name', ''),
            'title': title,
            'description': description,
            'ahu_id': ahu_id if ahu_id else None,
            'priority': priority,
            'status': 'open',
            'admin_response': None,
            'resolved_at': None,
            'resolved_by': None,
            'created_at': datetime.utcnow(),
            'updated_at': datetime.utcnow()
        }
        
        result = mongo_tickets_collection.insert_one(ticket_doc)
        ticket_id = str(result.inserted_id)
        
        return jsonify({
            'success': True,
            'message': 'Ticket created successfully',
            'ticket_id': ticket_id
        })
        
    except Exception as e:
        print(f"Create ticket error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to create ticket: {str(e)}'
        }), 500


@app.route('/api/tickets', methods=['GET'])
def api_get_user_tickets():
    """Get tickets for the current user"""
    if mongo_tickets_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({
            'success': False,
            'message': 'Authentication required'
        }), 401
    
    try:
        tickets = list(mongo_tickets_collection.find(
            {'user_id': user_id}
        ).sort('created_at', -1))
        
        ticket_list = []
        for ticket in tickets:
            ticket_list.append({
                'id': str(ticket['_id']),
                'title': ticket.get('title', ''),
                'description': ticket.get('description', ''),
                'ahu_id': ticket.get('ahu_id'),
                'priority': ticket.get('priority', 'medium'),
                'status': ticket.get('status', 'open'),
                'admin_response': ticket.get('admin_response'),
                'created_at': ticket.get('created_at').isoformat() if ticket.get('created_at') else None,
                'resolved_at': ticket.get('resolved_at').isoformat() if ticket.get('resolved_at') else None
            })
        
        return jsonify({
            'success': True,
            'tickets': ticket_list
        })
        
    except Exception as e:
        print(f"Get user tickets error: {e}")
        return jsonify({
            'success': False,
            'message': f'Failed to get tickets: {str(e)}'
        }), 500


@app.route('/api/admin/tickets', methods=['GET'])
@login_required
def api_get_all_tickets():
    """Get all tickets (admin only)"""
    if mongo_tickets_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        status_filter = request.args.get('status', None)
        query = {}
        if status_filter and status_filter != 'all':
            query['status'] = status_filter
        
        tickets = list(mongo_tickets_collection.find(query).sort('created_at', -1))
        
        ticket_list = []
        for ticket in tickets:
            ticket_list.append({
                'id': str(ticket['_id']),
                'user_id': ticket.get('user_id', ''),
                'user_email': ticket.get('user_email', ''),
                'user_name': ticket.get('user_name', ''),
                'hospital_name': ticket.get('hospital_name', ''),
                'title': ticket.get('title', ''),
                'description': ticket.get('description', ''),
                'ahu_id': ticket.get('ahu_id'),
                'priority': ticket.get('priority', 'medium'),
                'status': ticket.get('status', 'open'),
                'admin_response': ticket.get('admin_response'),
                'resolved_by': ticket.get('resolved_by'),
                'created_at': ticket.get('created_at').isoformat() if ticket.get('created_at') else None,
                'resolved_at': ticket.get('resolved_at').isoformat() if ticket.get('resolved_at') else None
            })
        
        return jsonify({
            'success': True,
            'tickets': ticket_list
        })
        
    except Exception as e:
        print(f"Get all tickets error: {e}")
        return jsonify({
            'success': False,
            'message': f'Failed to get tickets: {str(e)}'
        }), 500


@app.route('/api/admin/tickets/<ticket_id>/respond', methods=['POST'])
@login_required
def api_respond_ticket(ticket_id):
    """Respond to a ticket (admin only)"""
    if mongo_tickets_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        data = request.json
        response = data.get('response', '').strip()
        status = data.get('status', 'in_progress')
        
        if not response:
            return jsonify({
                'success': False,
                'message': 'Response is required'
            }), 400
        
        if status not in ['open', 'in_progress', 'resolved', 'closed']:
            status = 'in_progress'
        
        update_data = {
            'admin_response': response,
            'status': status,
            'updated_at': datetime.utcnow()
        }
        
        if status in ['resolved', 'closed']:
            update_data['resolved_at'] = datetime.utcnow()
            update_data['resolved_by'] = 'admin'
        
        result = mongo_tickets_collection.update_one(
            {'_id': ObjectId(ticket_id)},
            {'$set': update_data}
        )
        
        if result.matched_count == 0:
            return jsonify({
                'success': False,
                'message': 'Ticket not found'
            }), 404
        
        return jsonify({
            'success': True,
            'message': 'Ticket updated successfully'
        })
        
    except Exception as e:
        print(f"Respond to ticket error: {e}")
        return jsonify({
            'success': False,
            'message': f'Failed to update ticket: {str(e)}'
        }), 500


# ============================================================================
# Push Notifications API
# ============================================================================

@app.route('/api/user/fcm-token', methods=['POST'])
def api_register_fcm_token():
    """Register FCM token for push notifications"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    user_id = session.get('user_id')
    is_admin = session.get('authenticated', False)
    
    # Allow both admin and regular users
    if not user_id and not is_admin:
        return jsonify({
            'success': False,
            'message': 'Authentication required'
        }), 401
    
    try:
        data = request.json
        fcm_token = data.get('fcm_token', '').strip()
        
        if not fcm_token:
            return jsonify({
                'success': False,
                'message': 'FCM token is required'
            }), 400
        
        # First, remove this token from any other users (prevents duplicate notifications)
        # Remove from users collection
        mongo_users_collection.update_many(
            {'fcm_token': fcm_token},
            {'$unset': {'fcm_token': '', 'fcm_token_updated': ''}}
        )
        # Remove from admin tokens collection
        if mongo_client is not None:
            try:
                mongo_db = mongo_client[config.MONGO_DB_NAME]
                admin_tokens_col = mongo_db['admin_fcm_tokens']
                admin_tokens_col.delete_many({'token': fcm_token})
            except:
                pass
        
        # Store token based on user type
        if user_id:
            # Regular user - store in their user document
            print(f"Registering FCM token for user: {user_id}")
            mongo_users_collection.update_one(
                {'_id': ObjectId(user_id)},
                {
                    '$set': {
                        'fcm_token': fcm_token,
                        'fcm_token_updated': datetime.utcnow()
                    }
                }
            )
            print(f"✓ FCM token stored for user {user_id}")
        elif is_admin:
            # Admin - store in admin tokens collection or separate field
            print(f"Registering FCM token for admin")
            mongo_db = mongo_client[config.MONGO_DB_NAME]
            admin_tokens = mongo_db['admin_fcm_tokens']
            admin_tokens.update_one(
                {'token': fcm_token},
                {
                    '$set': {
                        'token': fcm_token,
                        'updated_at': datetime.utcnow()
                    }
                },
                upsert=True
            )
            print(f"✓ FCM token stored for admin")
        
        return jsonify({
            'success': True,
            'message': 'FCM token registered successfully'
        })
        
    except Exception as e:
        print(f"Register FCM token error: {e}")
        return jsonify({
            'success': False,
            'message': f'Failed to register token: {str(e)}'
        }), 500


@app.route('/api/user/fcm-token', methods=['DELETE'])
def api_unregister_fcm_token():
    """Unregister FCM token (on logout)"""
    if mongo_users_collection is None:
        return jsonify({
            'success': False,
            'message': 'Database connection unavailable'
        }), 500
    
    user_id = session.get('user_id')
    
    try:
        if user_id:
            mongo_users_collection.update_one(
                {'_id': ObjectId(user_id)},
                {'$unset': {'fcm_token': '', 'fcm_token_updated': ''}}
            )
        
        return jsonify({
            'success': True,
            'message': 'FCM token unregistered'
        })
        
    except Exception as e:
        print(f"Unregister FCM token error: {e}")
        return jsonify({
            'success': False,
            'message': f'Failed to unregister token: {str(e)}'
        }), 500


@app.route('/api/admin/notifications/send', methods=['POST'])
@login_required
def api_send_notification():
    """Send push notification to users (admin only)"""
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    if firebase_app is None:
        return jsonify({
            'success': False,
            'message': 'Push notifications are not configured. Please add Firebase service account.'
        }), 500
    
    try:
        from firebase_admin import messaging
        
        data = request.json
        title = data.get('title', '').strip()
        body = data.get('body', '').strip()
        target = data.get('target', 'all')  # 'all', 'hospital_users', 'specific', or user_id
        user_ids = data.get('user_ids', [])  # For specific targeting
        
        if not title or not body:
            return jsonify({
                'success': False,
                'message': 'Title and body are required'
            }), 400
        
        # Collect FCM tokens based on target
        tokens = []
        
        if target == 'all' or target == 'hospital_users':
            # Get all users with FCM tokens
            if mongo_users_collection is not None:
                users = mongo_users_collection.find({'fcm_token': {'$exists': True, '$ne': None}})
                for user in users:
                    if user.get('fcm_token'):
                        tokens.append(user['fcm_token'])
        
        if target == 'all':
            # Also get admin tokens
            if mongo_client is not None:
                try:
                    mongo_db = mongo_client[config.MONGO_DB_NAME]
                    admin_tokens_col = mongo_db['admin_fcm_tokens']
                    admin_tokens = admin_tokens_col.find({'token': {'$exists': True, '$ne': None}})
                    for at in admin_tokens:
                        if at.get('token'):
                            tokens.append(at['token'])
                except Exception as e:
                    print(f"Error getting admin tokens: {e}")
        
        if target == 'specific' and user_ids:
            # Get specific users
            if mongo_users_collection is not None:
                for uid in user_ids:
                    try:
                        user = mongo_users_collection.find_one({'_id': ObjectId(uid)})
                        if user and user.get('fcm_token'):
                            tokens.append(user['fcm_token'])
                    except:
                        pass
        
        if not tokens:
            return jsonify({
                'success': False,
                'message': 'No users with push notification tokens found'
            }), 400
        
        # Send notifications
        success_count = 0
        failure_count = 0
        
        # FCM allows max 500 tokens per multicast
        for i in range(0, len(tokens), 500):
            batch_tokens = tokens[i:i+500]
            
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                    'type': 'admin_notification',
                    'timestamp': str(int(time.time()))
                },
                tokens=batch_tokens,
            )
            
            response = messaging.send_each_for_multicast(message)
            success_count += response.success_count
            failure_count += response.failure_count
        
        # Log the notification
        if mongo_client is not None:
            mongo_db = mongo_client[config.MONGO_DB_NAME]
            notifications_log = mongo_db['notifications_log']
            notifications_log.insert_one({
                'title': title,
                'body': body,
                'target': target,
                'sent_count': success_count,
                'failed_count': failure_count,
                'sent_at': datetime.utcnow(),
                'sent_by': 'admin'
            })
        
        return jsonify({
            'success': True,
            'message': f'Notification sent to {success_count} devices ({failure_count} failed)',
            'success_count': success_count,
            'failure_count': failure_count
        })
        
    except Exception as e:
        print(f"Send notification error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'message': f'Failed to send notification: {str(e)}'
        }), 500


@app.route('/api/admin/notifications/history', methods=['GET'])
@login_required
def api_get_notification_history():
    """Get notification history (admin only)"""
    if not session.get('authenticated'):
        return jsonify({
            'success': False,
            'message': 'Admin access required'
        }), 403
    
    try:
        if mongo_client is not None:
            mongo_db = mongo_client[config.MONGO_DB_NAME]
            notifications_log = mongo_db['notifications_log']
            
            notifications = list(notifications_log.find().sort('sent_at', -1).limit(50))
            
            history = []
            for notif in notifications:
                history.append({
                    'id': str(notif['_id']),
                    'title': notif.get('title', ''),
                    'body': notif.get('body', ''),
                    'target': notif.get('target', 'all'),
                    'sent_count': notif.get('sent_count', 0),
                    'failed_count': notif.get('failed_count', 0),
                    'sent_at': notif.get('sent_at').isoformat() if notif.get('sent_at') else None
                })
            
            return jsonify({
                'success': True,
                'notifications': history
            })
        
        return jsonify({
            'success': True,
            'notifications': []
        })
        
    except Exception as e:
        print(f"Get notification history error: {e}")
        return jsonify({
            'success': False,
            'message': f'Failed to get history: {str(e)}'
        }), 500


@app.route('/notifications')
@login_required
def notifications_page():
    """Notifications management page"""
    if not session.get('authenticated'):
        return redirect(url_for('login'))
    return render_template('notifications.html')


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


# ==================== OTA Status Tracking ====================

# ESP32 OTA status tracking (per device)
esp32_ota_status = {}  # device_id -> status dict

def update_esp32_ota_status(device_id, status_data):
    """Update ESP32 OTA status and broadcast via WebSocket"""
    global esp32_ota_status
    
    if device_id not in esp32_ota_status:
        esp32_ota_status[device_id] = {
            'status': 'unknown',
            'message': '',
            'version': 'unknown',
            'verified': False,
            'verify_count': 0,
            'last_update': None
        }
    
    esp32_ota_status[device_id].update({
        'status': status_data.get('status', 'unknown'),
        'message': status_data.get('message', ''),
        'version': status_data.get('version', esp32_ota_status[device_id].get('version', 'unknown')),
        'last_update': time.time()
    })
    
    # Check for verification messages
    if status_data.get('type') == 'ota_verify':
        esp32_ota_status[device_id]['verified'] = True
        esp32_ota_status[device_id]['verify_count'] = status_data.get('num', 0)
        esp32_ota_status[device_id]['version'] = status_data.get('version', esp32_ota_status[device_id].get('version'))
        esp32_ota_status[device_id]['status'] = 'verified'
        esp32_ota_status[device_id]['message'] = f"OTA Verified ({status_data.get('num', 0)}/10)"
    
    # Broadcast to WebSocket clients
    socketio.emit('ota_status_update', {
        'device_type': 'esp32',
        'device_id': device_id,
        'status': esp32_ota_status[device_id],
        'timestamp': time.time()
    })
    
    print(f"[OTA] ESP32 {device_id}: {esp32_ota_status[device_id]['status']} - {esp32_ota_status[device_id]['message']}")


# ==================== RPi Dashboard OTA API ====================

# RPi OTA MQTT Topics
RPI_OTA_TOPIC_COMMAND = 'almed/rpi/ota/command'
RPI_OTA_TOPIC_STATUS = 'almed/rpi/ota/status'

# Store for RPi OTA status (received via local MQTT)
rpi_ota_status = {
    'status': 'unknown',
    'message': 'No status received yet',
    'current_version': 'unknown',
    'verified': False,
    'last_update': None
}

def update_rpi_ota_status(status_data):
    """Update RPi OTA status and broadcast via WebSocket"""
    global rpi_ota_status
    
    rpi_ota_status.update({
        'status': status_data.get('status', 'unknown'),
        'message': status_data.get('message', ''),
        'current_version': status_data.get('current_version', rpi_ota_status.get('current_version', 'unknown')),
        'target_version': status_data.get('target_version', ''),
        'progress': status_data.get('progress', None),
        'verified': status_data.get('status') == 'complete',
        'last_update': time.time()
    })
    
    # Broadcast to WebSocket clients
    socketio.emit('ota_status_update', {
        'device_type': 'rpi',
        'device_id': 'rpi_dashboard',
        'status': rpi_ota_status,
        'timestamp': time.time()
    })
    
    print(f"[OTA] RPi Dashboard: {rpi_ota_status['status']} - {rpi_ota_status['message']}")

# GitHub config for RPi dashboard (uses similar config as ESP32)
RPI_GITHUB_REPO_NAME = os.getenv('RPI_GITHUB_REPO_NAME', 'almed-rpi-dashboard')


@app.route('/api/esp32-ota/status', methods=['GET'])
@login_required
def get_esp32_ota_status():
    """Get ESP32 OTA status for all devices or a specific device"""
    device_id = request.args.get('device_id', None)
    
    if device_id:
        if device_id in esp32_ota_status:
            return jsonify({
                'success': True,
                'device_id': device_id,
                'status': esp32_ota_status[device_id]
            })
        else:
            return jsonify({
                'success': True,
                'device_id': device_id,
                'status': {
                    'status': 'unknown',
                    'message': 'No OTA status received yet',
                    'verified': False
                }
            })
    else:
        return jsonify({
            'success': True,
            'devices': esp32_ota_status
        })


@app.route('/api/esp32-ota/clear-status', methods=['POST'])
@login_required
def clear_esp32_ota_status():
    """Clear OTA status for a device (before starting new update)"""
    data = request.json
    device_id = data.get('device_id', None)
    
    if device_id and device_id in esp32_ota_status:
        esp32_ota_status[device_id] = {
            'status': 'pending',
            'message': 'OTA update initiated...',
            'version': 'unknown',
            'verified': False,
            'verify_count': 0,
            'last_update': time.time()
        }
        return jsonify({'success': True, 'message': f'Status cleared for {device_id}'})
    elif device_id:
        esp32_ota_status[device_id] = {
            'status': 'pending',
            'message': 'OTA update initiated...',
            'version': 'unknown',
            'verified': False,
            'verify_count': 0,
            'last_update': time.time()
        }
        return jsonify({'success': True, 'message': f'Status initialized for {device_id}'})
    
    return jsonify({'success': False, 'error': 'device_id required'}), 400


@app.route('/api/rpi-ota/status', methods=['GET'])
@login_required
def get_rpi_ota_status():
    """Get current RPi OTA updater status"""
    return jsonify({
        'success': True,
        'status': rpi_ota_status
    })


@app.route('/api/rpi-ota/check-update', methods=['POST'])
@login_required
def rpi_check_update():
    """Send command to RPi to check for updates"""
    try:
        command = {
            'type': 'check_update',
            'timestamp': int(time.time())
        }
        
        # Send via local MQTT broker
        success = publish_to_local_mqtt(RPI_OTA_TOPIC_COMMAND, command)
        
        if success:
            return jsonify({
                'success': True,
                'message': 'Check update command sent to RPi'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to send command to RPi (MQTT publish failed)'
            }), 500
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/rpi-ota/trigger-update', methods=['POST'])
@login_required
def trigger_rpi_ota_update():
    """Send OTA update command to RPi dashboard"""
    try:
        data = request.json
        version = data.get('version', 'latest')
        
        command = {
            'type': 'ota_update',
            'version': version,
            'timestamp': int(time.time())
        }
        
        print(f"\n[RPi OTA] Sending update command:")
        print(f"[RPi OTA] Version: {version}")
        print(f"[RPi OTA] Topic: {RPI_OTA_TOPIC_COMMAND}")
        
        # Send via local MQTT broker
        success = publish_to_local_mqtt(RPI_OTA_TOPIC_COMMAND, command)
        
        if success:
            return jsonify({
                'success': True,
                'message': f'OTA update command sent to RPi (version: {version})',
                'version': version
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to send command to RPi (MQTT publish failed)'
            }), 500
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/rpi-ota/restart', methods=['POST'])
@login_required
def restart_rpi_dashboard():
    """Send restart command to RPi dashboard service"""
    try:
        command = {
            'type': 'restart',
            'timestamp': int(time.time())
        }
        
        success = publish_to_local_mqtt(RPI_OTA_TOPIC_COMMAND, command)
        
        if success:
            return jsonify({
                'success': True,
                'message': 'Restart command sent to RPi dashboard'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to send restart command'
            }), 500
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/rpi-ota/rollback', methods=['POST'])
@login_required
def rollback_rpi_dashboard():
    """Send rollback command to RPi dashboard"""
    try:
        command = {
            'type': 'rollback',
            'timestamp': int(time.time())
        }
        
        success = publish_to_local_mqtt(RPI_OTA_TOPIC_COMMAND, command)
        
        if success:
            return jsonify({
                'success': True,
                'message': 'Rollback command sent to RPi'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to send rollback command'
            }), 500
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/rpi-ota/releases', methods=['GET'])
@login_required
def get_rpi_releases():
    """Get available releases from GitHub for RPi dashboard"""
    try:
        headers = {
            'Accept': 'application/vnd.github.v3+json',
            'Authorization': f'token {config.GITHUB_TOKEN}'
        }
        
        repo_name = RPI_GITHUB_REPO_NAME
        url = f'https://api.github.com/repos/{config.GITHUB_REPO_OWNER}/{repo_name}/releases'
        
        response = requests.get(url, headers=headers, timeout=30)
        
        if response.status_code == 200:
            releases = response.json()
            # Simplify the response
            simplified = []
            for release in releases[:10]:  # Limit to 10 releases
                assets = []
                for asset in release.get('assets', []):
                    assets.append({
                        'name': asset.get('name'),
                        'size': asset.get('size'),
                        'download_count': asset.get('download_count')
                    })
                simplified.append({
                    'tag': release.get('tag_name'),
                    'name': release.get('name'),
                    'published_at': release.get('published_at'),
                    'prerelease': release.get('prerelease'),
                    'assets': assets
                })
            
            return jsonify({
                'success': True,
                'releases': simplified,
                'repo': f'{config.GITHUB_REPO_OWNER}/{repo_name}'
            })
        elif response.status_code == 404:
            return jsonify({
                'success': True,
                'releases': [],
                'message': 'No releases found or repository does not exist'
            })
        else:
            return jsonify({
                'success': False,
                'error': f'GitHub API error: {response.status_code}'
            }), 500
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/rpi-ota/push-release', methods=['POST'])
@login_required
def push_rpi_release():
    """Create a new RPi dashboard release on GitHub with uploaded bundle"""
    try:
        data = request.json
        bundle_base64 = data.get('bundle')  # Base64-encoded tar.gz
        version = data.get('version')
        release_notes = data.get('notes', 'RPi Dashboard Update')
        
        if not bundle_base64:
            return jsonify({
                'success': False,
                'error': 'Bundle file is required'
            }), 400
        
        if not version:
            # Auto-generate version
            version = f'v{datetime.now().strftime("%Y.%m.%d.%H%M")}'
        
        headers = {
            'Accept': 'application/vnd.github.v3+json',
            'Authorization': f'token {config.GITHUB_TOKEN}'
        }
        
        repo_name = RPI_GITHUB_REPO_NAME
        
        # Step 1: Create release
        release_url = f'https://api.github.com/repos/{config.GITHUB_REPO_OWNER}/{repo_name}/releases'
        release_data = {
            'tag_name': version,
            'name': f'RPi Dashboard {version}',
            'body': release_notes,
            'draft': False,
            'prerelease': False
        }
        
        release_response = requests.post(release_url, headers=headers, json=release_data, timeout=60)
        
        if release_response.status_code != 201:
            return jsonify({
                'success': False,
                'error': f'Failed to create release: {release_response.text}'
            }), 500
        
        release_info = release_response.json()
        upload_url = release_info['upload_url'].replace('{?name,label}', '')
        
        # Step 2: Upload bundle asset
        bundle_data = base64.b64decode(bundle_base64)
        asset_name = f'ahu_dashboard_{version}.tar.gz'
        
        upload_headers = {
            'Authorization': f'token {config.GITHUB_TOKEN}',
            'Content-Type': 'application/gzip'
        }
        
        upload_response = requests.post(
            f"{upload_url}?name={asset_name}",
            headers=upload_headers,
            data=bundle_data,
            timeout=300
        )
        
        if upload_response.status_code == 201:
            return jsonify({
                'success': True,
                'message': f'Release {version} created successfully',
                'version': version,
                'release_url': release_info.get('html_url')
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Release created but asset upload failed: {upload_response.status_code}'
            }), 500
            
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


def publish_to_local_mqtt(topic, payload):
    """Publish message to local MQTT broker for RPi communication"""
    import paho.mqtt.publish as publish
    
    # Local MQTT broker config (same as ESP32 uses)
    MQTT_BROKER = os.getenv('LOCAL_MQTT_BROKER', '10.42.0.1')
    MQTT_PORT = int(os.getenv('LOCAL_MQTT_PORT', '1883'))
    MQTT_USERNAME = os.getenv('LOCAL_MQTT_USERNAME', 'ahu_user')
    MQTT_PASSWORD = os.getenv('LOCAL_MQTT_PASSWORD', 'ahu_pass_2024')
    
    try:
        print(f"[RPi MQTT] Publishing to {MQTT_BROKER}:{MQTT_PORT}")
        print(f"[RPi MQTT] Topic: {topic}")
        print(f"[RPi MQTT] Payload: {json.dumps(payload)}")
        
        publish.single(
            topic,
            payload=json.dumps(payload),
            hostname=MQTT_BROKER,
            port=MQTT_PORT,
            auth={'username': MQTT_USERNAME, 'password': MQTT_PASSWORD},
            qos=1,
            retain=False
        )
        
        print(f"[RPi MQTT] ✓ Message published successfully")
        return True
        
    except Exception as e:
        print(f"[RPi MQTT] ✗ Publish failed: {e}")
        import traceback
        traceback.print_exc()
        return False


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
    # Test update - git pull permission test
    print("=" * 50)
    print("ALMED AHU Web Dashboard")
    print("=" * 50)
    
    # Check if SSL is enabled and certificates exist
    ssl_context = None
    if config.SSL_ENABLED:
        import os
        if os.path.exists(config.SSL_CERT_PATH) and os.path.exists(config.SSL_KEY_PATH):
            ssl_context = (config.SSL_CERT_PATH, config.SSL_KEY_PATH)
            print(f"✓ SSL enabled - HTTPS on port {config.HTTPS_PORT}")
            print(f"  Certificate: {config.SSL_CERT_PATH}")
            print(f"  Private Key: {config.SSL_KEY_PATH}")
        else:
            print(f"⚠️ SSL enabled but certificates not found:")
            print(f"  Certificate: {config.SSL_CERT_PATH}")
            print(f"  Private Key: {config.SSL_KEY_PATH}")
            print("  Falling back to HTTP only")
            print("  Run 'python generate_cert.py' to generate certificates")
            ssl_context = None
    
    # HTTP to HTTPS redirect server (runs on port 80 if SSL is enabled)
    if config.SSL_ENABLED and ssl_context:
        def http_redirect_server():
            """Simple HTTP server that redirects all requests to HTTPS"""
            from http.server import HTTPServer, BaseHTTPRequestHandler
            
            class RedirectHandler(BaseHTTPRequestHandler):
                def do_GET(self):
                    host = self.headers.get("Host", "").replace(f":{config.PORT}", f":{config.HTTPS_PORT}")
                    if not host:
                        host = "app.almedequipments.in"
                    self.send_response(301)
                    self.send_header('Location', f'https://{host}{self.path}')
                    self.end_headers()
                
                def do_POST(self):
                    self.do_GET()
                
                def do_PUT(self):
                    self.do_GET()
                
                def do_DELETE(self):
                    self.do_GET()
                
                def log_message(self, format, *args):
                    pass  # Suppress logs
            
            server = HTTPServer((config.HOST, config.PORT), RedirectHandler)
            server.serve_forever()
        
        http_thread = Thread(target=http_redirect_server, daemon=True)
        http_thread.start()
        print(f"✓ HTTP to HTTPS redirect enabled on port {config.PORT}")
    
    if ssl_context:
        print(f"Server running on https://{config.HOST}:{config.HTTPS_PORT}")
    else:
        print(f"Server running on http://{config.HOST}:{config.PORT}")
    
    print(f"AWS Region: {config.AWS_REGION}")
    print(f"AWS IoT Endpoint: {config.AWS_IOT_ENDPOINT}")
    print(f"MQTT Topic: {config.AWS_IOT_TOPIC_PUBLISH}")
    print(f"MongoDB Collection: {config.MONGO_DB_NAME}.{config.MONGO_COLLECTION}")
    print(f"WebSocket enabled: SocketIO")
    print("=" * 50)
    
    # Run with SSL if enabled and certificates are available
    if ssl_context:
        # For eventlet with SocketIO, use eventlet's wrap_ssl properly
        import eventlet.wsgi as wsgi_server
        import os
        
        # Verify certificate files exist and are readable
        if not os.path.exists(config.SSL_CERT_PATH):
            print(f"❌ Certificate file not found: {config.SSL_CERT_PATH}")
            ssl_context = None
        elif not os.path.exists(config.SSL_KEY_PATH):
            print(f"❌ Key file not found: {config.SSL_KEY_PATH}")
            ssl_context = None
        else:
            # Check file permissions
            if not os.access(config.SSL_CERT_PATH, os.R_OK):
                print(f"⚠️  Warning: Certificate file is not readable: {config.SSL_CERT_PATH}")
                print("   Try: sudo chmod 644 " + config.SSL_CERT_PATH)
            if not os.access(config.SSL_KEY_PATH, os.R_OK):
                print(f"⚠️  Warning: Key file is not readable: {config.SSL_KEY_PATH}")
                print("   Try: sudo chmod 600 " + config.SSL_KEY_PATH)
            
            try:
                # Create socket using eventlet
                sock = eventlet.listen((config.HOST, config.HTTPS_PORT))
                
                # Wrap with SSL using eventlet.wrap_ssl
                # For Let's Encrypt, fullchain.pem includes the certificate chain
                # Using minimal SSL options for maximum compatibility
                try:
                    sock = eventlet.wrap_ssl(
                        sock,
                        certfile=config.SSL_CERT_PATH,
                        keyfile=config.SSL_KEY_PATH,
                        server_side=True
                    )
                except Exception as wrap_error:
                    print(f"❌ Error wrapping socket with SSL: {wrap_error}")
                    print(f"   Certificate: {config.SSL_CERT_PATH}")
                    print(f"   Key: {config.SSL_KEY_PATH}")
                    raise
                
                print("Starting HTTPS server...")
                # Flask app is already integrated with SocketIO
                wsgi_server.server(sock, app, log_output=config.DEBUG)
            except Exception as e:
                print(f"❌ SSL Error: {e}")
                import traceback
                traceback.print_exc()
                print("\nTroubleshooting:")
                print(f"  1. Check certificate: openssl x509 -in {config.SSL_CERT_PATH} -text -noout")
                print(f"  2. Check key: openssl rsa -in {config.SSL_KEY_PATH} -check")
                print(f"  3. Verify paths are correct")
                print("Falling back to HTTP only...")
                ssl_context = None
    
    if not ssl_context:
        socketio.run(
            app,
            host=config.HOST,
            port=config.PORT,
            debug=config.DEBUG,
            use_reloader=False,
            allow_unsafe_werkzeug=True
        )

