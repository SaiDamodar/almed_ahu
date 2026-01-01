#!/usr/bin/env python3
"""
Raspberry Pi OTA Updater for AHU Dashboard
Listens for MQTT commands to update the Flutter dashboard from GitHub Releases
"""

import os
import sys
import json
import time
import shutil
import tarfile
import tempfile
import logging
import subprocess
import requests
import paho.mqtt.client as mqtt
from datetime import datetime
from pathlib import Path

# ==================== Configuration ====================

# MQTT Configuration - matches local ESP32 broker
MQTT_BROKER = os.getenv('MQTT_BROKER', '10.42.0.1')
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
MQTT_USERNAME = os.getenv('MQTT_USERNAME', 'ahu_user')
MQTT_PASSWORD = os.getenv('MQTT_PASSWORD', 'ahu_pass_2024')
MQTT_CLIENT_ID = f"rpi_ota_updater_{int(time.time())}"

# MQTT Topics
MQTT_TOPIC_COMMAND = 'almed/rpi/ota/command'   # Subscribe: receive OTA commands
MQTT_TOPIC_STATUS = 'almed/rpi/ota/status'      # Publish: report OTA status
MQTT_TOPIC_LOG = 'almed/rpi/ota/log'            # Publish: log messages

# GitHub Configuration
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN', '')
GITHUB_REPO_OWNER = os.getenv('GITHUB_REPO_OWNER', 'ESPUpdaterzaid')
GITHUB_REPO_NAME = os.getenv('GITHUB_REPO_NAME', 'almed-rpi-dashboard')
GITHUB_API_URL = 'https://api.github.com'

# Dashboard Configuration
DASHBOARD_DIR = os.getenv('DASHBOARD_DIR', '/home/pi/ahu_dashboard')
BACKUP_DIR = os.getenv('BACKUP_DIR', '/home/pi/ahu_dashboard_backup')
FLUTTER_PI_SERVICE = os.getenv('FLUTTER_PI_SERVICE', 'ahu-dashboard')

# Logging Configuration
LOG_FILE = os.getenv('LOG_FILE', '/var/log/ahu_ota_updater.log')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# ==================== Setup Logging ====================

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper(), logging.INFO),
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_FILE, mode='a') if os.access(os.path.dirname(LOG_FILE) or '/var/log', os.W_OK) else logging.StreamHandler()
    ]
)
logger = logging.getLogger('rpi_ota_updater')

# ==================== Global State ====================

mqtt_client = None
current_version = None
update_in_progress = False


def get_current_version():
    """Read the current installed version from version file"""
    global current_version
    version_file = os.path.join(DASHBOARD_DIR, 'version.txt')
    try:
        if os.path.exists(version_file):
            with open(version_file, 'r') as f:
                current_version = f.read().strip()
        else:
            current_version = 'unknown'
    except Exception as e:
        logger.error(f"Failed to read version file: {e}")
        current_version = 'unknown'
    return current_version


def set_current_version(version):
    """Write the current version to version file"""
    global current_version
    version_file = os.path.join(DASHBOARD_DIR, 'version.txt')
    try:
        os.makedirs(DASHBOARD_DIR, exist_ok=True)
        with open(version_file, 'w') as f:
            f.write(version)
        current_version = version
        logger.info(f"Version updated to: {version}")
    except Exception as e:
        logger.error(f"Failed to write version file: {e}")


def publish_status(status, message, version=None, progress=None):
    """Publish OTA status to MQTT"""
    global mqtt_client
    if mqtt_client is None or not mqtt_client.is_connected():
        logger.warning("MQTT not connected, cannot publish status")
        return
    
    payload = {
        'status': status,
        'message': message,
        'timestamp': datetime.utcnow().isoformat(),
        'current_version': current_version or 'unknown'
    }
    
    if version:
        payload['target_version'] = version
    if progress is not None:
        payload['progress'] = progress
    
    try:
        mqtt_client.publish(MQTT_TOPIC_STATUS, json.dumps(payload), qos=1)
        logger.info(f"Status: {status} - {message}")
    except Exception as e:
        logger.error(f"Failed to publish status: {e}")


def publish_log(level, message):
    """Publish log message to MQTT"""
    global mqtt_client
    if mqtt_client is None or not mqtt_client.is_connected():
        return
    
    payload = {
        'level': level,
        'message': message,
        'timestamp': datetime.utcnow().isoformat()
    }
    
    try:
        mqtt_client.publish(MQTT_TOPIC_LOG, json.dumps(payload), qos=0)
    except Exception:
        pass


def stop_dashboard():
    """Stop the Flutter-Pi dashboard service"""
    logger.info("Stopping dashboard service...")
    publish_log('INFO', 'Stopping dashboard service...')
    
    try:
        result = subprocess.run(
            ['sudo', 'systemctl', 'stop', FLUTTER_PI_SERVICE],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            logger.warning(f"Service stop warning: {result.stderr}")
        time.sleep(2)  # Give time for service to stop
        return True
    except subprocess.TimeoutExpired:
        logger.error("Timeout stopping service")
        return False
    except Exception as e:
        logger.error(f"Failed to stop service: {e}")
        return False


def start_dashboard():
    """Start the Flutter-Pi dashboard service"""
    logger.info("Starting dashboard service...")
    publish_log('INFO', 'Starting dashboard service...')
    
    try:
        result = subprocess.run(
            ['sudo', 'systemctl', 'start', FLUTTER_PI_SERVICE],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            logger.error(f"Service start failed: {result.stderr}")
            return False
        time.sleep(2)  # Give time for service to start
        return True
    except subprocess.TimeoutExpired:
        logger.error("Timeout starting service")
        return False
    except Exception as e:
        logger.error(f"Failed to start service: {e}")
        return False


def restart_dashboard():
    """Restart the Flutter-Pi dashboard service"""
    logger.info("Restarting dashboard service...")
    publish_log('INFO', 'Restarting dashboard service...')
    
    try:
        result = subprocess.run(
            ['sudo', 'systemctl', 'restart', FLUTTER_PI_SERVICE],
            capture_output=True, text=True, timeout=60
        )
        if result.returncode != 0:
            logger.error(f"Service restart failed: {result.stderr}")
            return False
        time.sleep(3)  # Give time for service to restart
        return True
    except subprocess.TimeoutExpired:
        logger.error("Timeout restarting service")
        return False
    except Exception as e:
        logger.error(f"Failed to restart service: {e}")
        return False


def create_backup():
    """Create a backup of the current dashboard"""
    logger.info("Creating backup of current dashboard...")
    publish_log('INFO', 'Creating backup...')
    
    try:
        if os.path.exists(BACKUP_DIR):
            shutil.rmtree(BACKUP_DIR)
        
        if os.path.exists(DASHBOARD_DIR):
            shutil.copytree(DASHBOARD_DIR, BACKUP_DIR)
            logger.info(f"Backup created at: {BACKUP_DIR}")
            return True
        else:
            logger.warning("No existing dashboard to backup")
            return True  # No backup needed
    except Exception as e:
        logger.error(f"Failed to create backup: {e}")
        return False


def restore_backup():
    """Restore dashboard from backup"""
    logger.info("Restoring from backup...")
    publish_log('WARN', 'Restoring from backup...')
    
    try:
        if not os.path.exists(BACKUP_DIR):
            logger.error("No backup found to restore")
            return False
        
        if os.path.exists(DASHBOARD_DIR):
            shutil.rmtree(DASHBOARD_DIR)
        
        shutil.copytree(BACKUP_DIR, DASHBOARD_DIR)
        logger.info("Backup restored successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to restore backup: {e}")
        return False


def get_latest_release():
    """Get the latest release info from GitHub"""
    headers = {'Accept': 'application/vnd.github.v3+json'}
    if GITHUB_TOKEN:
        headers['Authorization'] = f'token {GITHUB_TOKEN}'
    
    url = f'{GITHUB_API_URL}/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/releases/latest'
    
    try:
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 404:
            logger.warning("No releases found")
            return None
        else:
            logger.error(f"GitHub API error: {response.status_code}")
            return None
    except Exception as e:
        logger.error(f"Failed to get latest release: {e}")
        return None


def get_release_by_tag(tag):
    """Get a specific release by tag from GitHub"""
    headers = {'Accept': 'application/vnd.github.v3+json'}
    if GITHUB_TOKEN:
        headers['Authorization'] = f'token {GITHUB_TOKEN}'
    
    url = f'{GITHUB_API_URL}/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/releases/tags/{tag}'
    
    try:
        response = requests.get(url, headers=headers, timeout=30)
        if response.status_code == 200:
            return response.json()
        else:
            logger.error(f"Release not found: {tag}")
            return None
    except Exception as e:
        logger.error(f"Failed to get release: {e}")
        return None


def download_release_asset(asset_url, download_path):
    """Download a release asset from GitHub"""
    headers = {'Accept': 'application/octet-stream'}
    if GITHUB_TOKEN:
        headers['Authorization'] = f'token {GITHUB_TOKEN}'
    
    try:
        logger.info(f"Downloading from: {asset_url}")
        publish_log('INFO', 'Downloading update package...')
        
        response = requests.get(asset_url, headers=headers, stream=True, timeout=300)
        if response.status_code != 200:
            logger.error(f"Download failed: {response.status_code}")
            return False
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        
        with open(download_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        progress = int((downloaded / total_size) * 100)
                        if progress % 10 == 0:  # Log every 10%
                            publish_status('downloading', f'Downloaded {progress}%', progress=progress)
        
        logger.info(f"Downloaded: {download_path} ({downloaded} bytes)")
        return True
    except Exception as e:
        logger.error(f"Download error: {e}")
        return False


def extract_update(archive_path, extract_to):
    """Extract the update archive"""
    logger.info(f"Extracting update to: {extract_to}")
    publish_log('INFO', 'Extracting update package...')
    
    try:
        if archive_path.endswith('.tar.gz') or archive_path.endswith('.tgz'):
            with tarfile.open(archive_path, 'r:gz') as tar:
                tar.extractall(path=extract_to)
        elif archive_path.endswith('.zip'):
            import zipfile
            with zipfile.ZipFile(archive_path, 'r') as zip_ref:
                zip_ref.extractall(extract_to)
        else:
            logger.error(f"Unknown archive format: {archive_path}")
            return False
        
        logger.info("Extraction complete")
        return True
    except Exception as e:
        logger.error(f"Extraction failed: {e}")
        return False


def apply_update(extracted_dir):
    """Apply the extracted update to the dashboard directory"""
    logger.info("Applying update...")
    publish_log('INFO', 'Applying update...')
    
    try:
        # Find the flutter_assets directory in extracted content
        flutter_assets = None
        
        # Check common locations
        for root, dirs, files in os.walk(extracted_dir):
            if 'flutter_assets' in dirs:
                flutter_assets = os.path.join(root, 'flutter_assets')
                break
            # Also check for direct bundle structure
            if 'AssetManifest.json' in files or 'kernel_blob.bin' in files:
                flutter_assets = root
                break
        
        if not flutter_assets:
            # Assume the extracted dir itself is the assets
            flutter_assets = extracted_dir
        
        # Remove old dashboard content (except version.txt)
        if os.path.exists(DASHBOARD_DIR):
            for item in os.listdir(DASHBOARD_DIR):
                if item != 'version.txt':
                    item_path = os.path.join(DASHBOARD_DIR, item)
                    if os.path.isdir(item_path):
                        shutil.rmtree(item_path)
                    else:
                        os.remove(item_path)
        else:
            os.makedirs(DASHBOARD_DIR, exist_ok=True)
        
        # Copy new content
        for item in os.listdir(flutter_assets):
            src = os.path.join(flutter_assets, item)
            dst = os.path.join(DASHBOARD_DIR, item)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)
        
        logger.info("Update applied successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to apply update: {e}")
        return False


def perform_ota_update(version='latest'):
    """Perform the full OTA update process"""
    global update_in_progress
    
    if update_in_progress:
        publish_status('error', 'Update already in progress')
        return False
    
    update_in_progress = True
    success = False
    
    try:
        publish_status('starting', f'Starting OTA update to {version}')
        
        # Step 1: Get release info
        publish_status('checking', 'Checking for updates on GitHub...')
        
        if version == 'latest':
            release = get_latest_release()
        else:
            release = get_release_by_tag(version)
        
        if not release:
            publish_status('error', 'No release found on GitHub')
            return False
        
        release_tag = release.get('tag_name', 'unknown')
        logger.info(f"Found release: {release_tag}")
        
        # Check if already up to date
        if current_version == release_tag:
            publish_status('up_to_date', f'Already on version {release_tag}')
            return True
        
        # Step 2: Find the dashboard asset
        assets = release.get('assets', [])
        dashboard_asset = None
        
        for asset in assets:
            name = asset.get('name', '')
            if name.endswith('.tar.gz') or name.endswith('.tgz') or name.endswith('.zip'):
                if 'dashboard' in name.lower() or 'flutter' in name.lower() or 'rpi' in name.lower():
                    dashboard_asset = asset
                    break
        
        # If no specific dashboard asset, use first archive
        if not dashboard_asset:
            for asset in assets:
                name = asset.get('name', '')
                if name.endswith('.tar.gz') or name.endswith('.tgz') or name.endswith('.zip'):
                    dashboard_asset = asset
                    break
        
        if not dashboard_asset:
            publish_status('error', 'No dashboard package found in release')
            return False
        
        asset_name = dashboard_asset.get('name')
        asset_url = dashboard_asset.get('url')  # API URL for download
        logger.info(f"Found asset: {asset_name}")
        
        # Step 3: Create backup
        publish_status('backup', 'Creating backup of current version', version=release_tag, progress=10)
        if not create_backup():
            publish_status('error', 'Failed to create backup')
            return False
        
        # Step 4: Stop dashboard service
        publish_status('stopping', 'Stopping dashboard service', version=release_tag, progress=20)
        if not stop_dashboard():
            publish_status('warning', 'Could not stop service, continuing anyway')
        
        # Step 5: Download update
        with tempfile.TemporaryDirectory() as temp_dir:
            download_path = os.path.join(temp_dir, asset_name)
            
            publish_status('downloading', 'Downloading update package', version=release_tag, progress=30)
            if not download_release_asset(asset_url, download_path):
                publish_status('error', 'Failed to download update')
                restore_backup()
                start_dashboard()
                return False
            
            # Step 6: Extract update
            extract_dir = os.path.join(temp_dir, 'extracted')
            os.makedirs(extract_dir, exist_ok=True)
            
            publish_status('extracting', 'Extracting update package', version=release_tag, progress=70)
            if not extract_update(download_path, extract_dir):
                publish_status('error', 'Failed to extract update')
                restore_backup()
                start_dashboard()
                return False
            
            # Step 7: Apply update
            publish_status('applying', 'Applying update', version=release_tag, progress=85)
            if not apply_update(extract_dir):
                publish_status('error', 'Failed to apply update')
                restore_backup()
                start_dashboard()
                return False
        
        # Step 8: Update version file
        set_current_version(release_tag)
        
        # Step 9: Start dashboard service
        publish_status('starting', 'Starting updated dashboard', version=release_tag, progress=95)
        if not start_dashboard():
            publish_status('error', 'Failed to start dashboard after update')
            # Try to restore
            restore_backup()
            start_dashboard()
            return False
        
        # Success!
        publish_status('complete', f'Successfully updated to {release_tag}', version=release_tag, progress=100)
        success = True
        return True
        
    except Exception as e:
        logger.error(f"OTA update failed: {e}")
        publish_status('error', f'Update failed: {str(e)}')
        
        # Try to recover
        try:
            restore_backup()
            start_dashboard()
        except Exception:
            pass
        
        return False
    finally:
        update_in_progress = False


def check_for_updates():
    """Check if updates are available"""
    publish_status('checking', 'Checking for updates...')
    
    release = get_latest_release()
    if not release:
        publish_status('error', 'Could not check for updates')
        return None
    
    release_tag = release.get('tag_name', 'unknown')
    
    if current_version == release_tag:
        publish_status('up_to_date', f'Already on latest version: {release_tag}')
    else:
        publish_status('update_available', f'Update available: {release_tag}', version=release_tag)
    
    return release_tag


# ==================== MQTT Callbacks ====================

def on_connect(client, userdata, flags, rc, properties=None):
    """Callback when connected to MQTT broker"""
    if rc == 0:
        logger.info(f"Connected to MQTT broker: {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(MQTT_TOPIC_COMMAND, qos=1)
        logger.info(f"Subscribed to: {MQTT_TOPIC_COMMAND}")
        
        # Publish online status
        get_current_version()
        publish_status('online', 'RPi OTA Updater ready', version=current_version)
    else:
        logger.error(f"Failed to connect to MQTT: {rc}")


def on_disconnect(client, userdata, rc, properties=None):
    """Callback when disconnected from MQTT broker"""
    logger.warning(f"Disconnected from MQTT broker (rc={rc})")


def on_message(client, userdata, msg):
    """Callback when MQTT message received"""
    try:
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        logger.info(f"Received MQTT message on {topic}: {payload}")
        
        data = json.loads(payload)
        command = data.get('type', data.get('command', ''))
        
        if command == 'ota_update' or command == 'update':
            version = data.get('version', 'latest')
            logger.info(f"Received OTA update command for version: {version}")
            perform_ota_update(version)
            
        elif command == 'check_update' or command == 'check':
            logger.info("Received check update command")
            check_for_updates()
            
        elif command == 'restart':
            logger.info("Received restart command")
            restart_dashboard()
            publish_status('restarted', 'Dashboard restarted')
            
        elif command == 'status':
            logger.info("Received status request")
            get_current_version()
            publish_status('online', 'RPi OTA Updater ready')
            
        elif command == 'rollback':
            logger.info("Received rollback command")
            if stop_dashboard():
                if restore_backup():
                    get_current_version()
                    start_dashboard()
                    publish_status('rolled_back', 'Rolled back to previous version')
                else:
                    publish_status('error', 'Rollback failed')
                    start_dashboard()
            else:
                publish_status('error', 'Could not stop service for rollback')
        else:
            logger.warning(f"Unknown command: {command}")
            
    except json.JSONDecodeError:
        logger.error(f"Invalid JSON payload: {msg.payload}")
    except Exception as e:
        logger.error(f"Error processing message: {e}")


# ==================== Main ====================

def main():
    global mqtt_client
    
    logger.info("=" * 50)
    logger.info("RPi OTA Updater for AHU Dashboard")
    logger.info("=" * 50)
    logger.info(f"MQTT Broker: {MQTT_BROKER}:{MQTT_PORT}")
    logger.info(f"Dashboard Dir: {DASHBOARD_DIR}")
    logger.info(f"GitHub Repo: {GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}")
    
    # Get current version
    get_current_version()
    logger.info(f"Current Version: {current_version}")
    
    # Create MQTT client
    mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=MQTT_CLIENT_ID)
    mqtt_client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    
    # Set callbacks
    mqtt_client.on_connect = on_connect
    mqtt_client.on_disconnect = on_disconnect
    mqtt_client.on_message = on_message
    
    # Connect to broker with retry
    while True:
        try:
            logger.info(f"Connecting to MQTT broker...")
            mqtt_client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
            break
        except Exception as e:
            logger.error(f"MQTT connection failed: {e}")
            logger.info("Retrying in 10 seconds...")
            time.sleep(10)
    
    # Start MQTT loop
    try:
        logger.info("Starting MQTT loop...")
        mqtt_client.loop_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    finally:
        mqtt_client.disconnect()
        logger.info("Disconnected from MQTT broker")


if __name__ == '__main__':
    main()

