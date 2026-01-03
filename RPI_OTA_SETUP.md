# RPi OTA Update System Setup

This document contains everything needed to set up the RPi OTA updater that receives commands from ESP32 via local MQTT.

## Overview

- **Purpose**: Update RPi dashboard via `git pull` when commanded from web dashboard
- **Flow**: Web Dashboard → AWS IoT → ESP32 → Local MQTT → RPi → `git pull` → Restart dashboard
- **No file upload needed** - just push to GitHub and trigger update from web

---

## Step 1: Create the OTA Updater Script

Create file: `/home/pi/rpi_ota_updater/rpi_ota_updater.py`

```python
#!/usr/bin/env python3
"""
RPi OTA Updater - Receives commands via local MQTT, runs git pull, restarts dashboard
"""

import os
import sys
import json
import time
import subprocess
import logging
import paho.mqtt.client as mqtt
from datetime import datetime

# ==================== Configuration ====================

MQTT_BROKER = os.getenv('MQTT_BROKER', '10.42.0.1')
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
MQTT_USERNAME = os.getenv('MQTT_USERNAME', 'ahu_user')
MQTT_PASSWORD = os.getenv('MQTT_PASSWORD', 'ahu_pass_2024')
MQTT_CLIENT_ID = f"rpi_ota_updater_{int(time.time())}"

MQTT_TOPIC_COMMAND = 'almed/rpi/ota/command'
MQTT_TOPIC_STATUS = 'almed/rpi/ota/status'

DASHBOARD_DIR = os.getenv('DASHBOARD_DIR', '/home/pi/ahu_dashboard')
FLUTTER_PI_SERVICE = os.getenv('FLUTTER_PI_SERVICE', 'ahu-dashboard')
GIT_BRANCH = os.getenv('GIT_BRANCH', 'main')

# ==================== Logging ====================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger('rpi_ota_updater')

# ==================== Global State ====================

mqtt_client = None
current_version = 'unknown'
update_in_progress = False


def get_current_version():
    global current_version
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--short', 'HEAD'],
            cwd=DASHBOARD_DIR,
            capture_output=True, text=True, timeout=10
        )
        current_version = result.stdout.strip() if result.returncode == 0 else 'unknown'
    except:
        current_version = 'unknown'
    return current_version


def publish_status(status, message, progress=None):
    global mqtt_client, current_version
    if not mqtt_client or not mqtt_client.is_connected():
        return
    
    payload = {
        'status': status,
        'message': message,
        'current_version': current_version,
        'timestamp': datetime.utcnow().isoformat()
    }
    if progress is not None:
        payload['progress'] = progress
    
    try:
        mqtt_client.publish(MQTT_TOPIC_STATUS, json.dumps(payload), qos=1)
        logger.info(f"Status: {status} - {message}")
    except Exception as e:
        logger.error(f"Publish failed: {e}")


def run_git_pull():
    logger.info(f"Running git pull origin {GIT_BRANCH}...")
    try:
        # Fetch
        subprocess.run(['git', 'fetch', 'origin', GIT_BRANCH],
                      cwd=DASHBOARD_DIR, capture_output=True, timeout=120)
        
        # Check if up to date
        status = subprocess.run(['git', 'status', '-uno'],
                               cwd=DASHBOARD_DIR, capture_output=True, text=True, timeout=10)
        if 'Your branch is up to date' in status.stdout:
            return True, 'Already up to date'
        
        # Pull
        result = subprocess.run(['git', 'pull', 'origin', GIT_BRANCH],
                               cwd=DASHBOARD_DIR, capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            return True, result.stdout
        return False, result.stderr
    except Exception as e:
        return False, str(e)


def restart_dashboard():
    logger.info(f"Restarting {FLUTTER_PI_SERVICE}...")
    try:
        result = subprocess.run(['sudo', 'systemctl', 'restart', FLUTTER_PI_SERVICE],
                               capture_output=True, text=True, timeout=60)
        return result.returncode == 0, result.stderr if result.returncode != 0 else "OK"
    except Exception as e:
        return False, str(e)


def perform_update():
    global update_in_progress
    if update_in_progress:
        publish_status('error', 'Update already in progress')
        return
    
    update_in_progress = True
    try:
        publish_status('starting', 'Starting update...', progress=0)
        
        # Git pull
        publish_status('pulling', f'Running git pull origin {GIT_BRANCH}...', progress=20)
        success, message = run_git_pull()
        
        if not success:
            publish_status('error', f'Git pull failed: {message}')
            return
        
        if 'Already up to date' in message:
            get_current_version()
            publish_status('up_to_date', 'Already up to date', progress=100)
            return
        
        publish_status('pulled', 'Code updated', progress=50)
        old_version = current_version
        get_current_version()
        
        # Restart
        publish_status('restarting', 'Restarting dashboard...', progress=70)
        success, message = restart_dashboard()
        
        if not success:
            publish_status('error', f'Restart failed: {message}')
            return
        
        time.sleep(3)
        publish_status('complete', f'✅ Updated: {old_version} → {current_version}', progress=100)
        
        # Send confirmations
        for i in range(5):
            time.sleep(1)
            publish_status('complete', f'🎉 OTA Complete! v{current_version} [{i+1}/5]', progress=100)
            
    finally:
        update_in_progress = False


def check_for_updates():
    publish_status('checking', 'Checking for updates...')
    try:
        subprocess.run(['git', 'fetch', 'origin', GIT_BRANCH],
                      cwd=DASHBOARD_DIR, capture_output=True, timeout=60)
        
        status = subprocess.run(['git', 'status', '-uno'],
                               cwd=DASHBOARD_DIR, capture_output=True, text=True, timeout=10)
        get_current_version()
        
        if 'Your branch is behind' in status.stdout:
            publish_status('update_available', 'Update available!')
        else:
            publish_status('up_to_date', f'Up to date: {current_version}')
    except Exception as e:
        publish_status('error', str(e))


# ==================== MQTT Callbacks ====================

def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        logger.info(f"✓ Connected to MQTT: {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(MQTT_TOPIC_COMMAND, qos=1)
        get_current_version()
        publish_status('online', f'RPi OTA ready (v{current_version})')
    else:
        logger.error(f"MQTT connect failed: {rc}")


def on_disconnect(client, userdata, rc, properties=None):
    logger.warning(f"MQTT disconnected: {rc}")


def on_message(client, userdata, msg):
    try:
        payload = msg.payload.decode('utf-8')
        logger.info(f"📩 Received: {payload}")
        
        data = json.loads(payload)
        command = data.get('type', data.get('command', ''))
        
        if command in ['ota_update', 'update', 'pull']:
            perform_update()
        elif command in ['check_update', 'check']:
            check_for_updates()
        elif command == 'restart':
            publish_status('restarting', 'Restarting...')
            success, _ = restart_dashboard()
            time.sleep(2)
            get_current_version()
            publish_status('restarted' if success else 'error', f'v{current_version}')
        elif command == 'status':
            get_current_version()
            publish_status('online', f'RPi OTA ready (v{current_version})')
        else:
            logger.warning(f"Unknown command: {command}")
    except Exception as e:
        logger.error(f"Error: {e}")


# ==================== Main ====================

def main():
    global mqtt_client
    
    print("=" * 50)
    print("  RPi OTA Updater")
    print("=" * 50)
    print(f"  MQTT: {MQTT_BROKER}:{MQTT_PORT}")
    print(f"  Dashboard: {DASHBOARD_DIR}")
    print(f"  Branch: {GIT_BRANCH}")
    print("=" * 50)
    
    if not os.path.exists(os.path.join(DASHBOARD_DIR, '.git')):
        logger.error(f"Not a git repo: {DASHBOARD_DIR}")
        sys.exit(1)
    
    get_current_version()
    logger.info(f"Version: {current_version}")
    
    mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=MQTT_CLIENT_ID)
    mqtt_client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    mqtt_client.on_connect = on_connect
    mqtt_client.on_disconnect = on_disconnect
    mqtt_client.on_message = on_message
    
    while True:
        try:
            mqtt_client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
            break
        except Exception as e:
            logger.error(f"Connect failed: {e}, retrying...")
            time.sleep(10)
    
    mqtt_client.loop_forever()


if __name__ == '__main__':
    main()
```

---

## Step 2: Create the Systemd Service

Create file: `/etc/systemd/system/ahu-ota-updater.service`

```ini
[Unit]
Description=AHU Dashboard OTA Updater
After=network.target mosquitto.service

[Service]
Type=simple
User=pi
Environment=MQTT_BROKER=10.42.0.1
Environment=MQTT_PORT=1883
Environment=MQTT_USERNAME=ahu_user
Environment=MQTT_PASSWORD=ahu_pass_2024
Environment=DASHBOARD_DIR=/home/pi/ahu_dashboard
Environment=FLUTTER_PI_SERVICE=ahu-dashboard
Environment=GIT_BRANCH=main
ExecStart=/usr/bin/python3 /home/pi/rpi_ota_updater/rpi_ota_updater.py
WorkingDirectory=/home/pi/rpi_ota_updater
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## Step 3: Setup Sudoers for Service Control

Create file: `/etc/sudoers.d/ahu-ota-updater`

```
pi ALL=(ALL) NOPASSWD: /bin/systemctl restart ahu-dashboard
pi ALL=(ALL) NOPASSWD: /bin/systemctl start ahu-dashboard
pi ALL=(ALL) NOPASSWD: /bin/systemctl stop ahu-dashboard
```

---

## Step 4: Run These Commands

```bash
# 1. Create directory
mkdir -p /home/pi/rpi_ota_updater

# 2. Create the Python script (copy content from Step 1)
nano /home/pi/rpi_ota_updater/rpi_ota_updater.py

# 3. Install paho-mqtt
pip3 install paho-mqtt --break-system-packages

# 4. Create systemd service (copy content from Step 2)
sudo nano /etc/systemd/system/ahu-ota-updater.service

# 5. Create sudoers file (copy content from Step 3)
sudo visudo -f /etc/sudoers.d/ahu-ota-updater

# 6. Set permissions
sudo chmod 440 /etc/sudoers.d/ahu-ota-updater

# 7. Reload systemd
sudo systemctl daemon-reload

# 8. Enable service
sudo systemctl enable ahu-ota-updater

# 9. Start service
sudo systemctl start ahu-ota-updater

# 10. Check status
sudo systemctl status ahu-ota-updater
```

---

## Step 5: Verify Dashboard is a Git Repo

```bash
cd /home/pi/ahu_dashboard
git status
git remote -v  # Should show origin URL
```

If not a git repo, clone it:
```bash
cd /home/pi
git clone https://github.com/YOUR_USERNAME/ahu_dashboard.git
```

---

## Testing

### Test from command line:
```bash
# Send status request
mosquitto_pub -h 10.42.0.1 -u ahu_user -P ahu_pass_2024 \
  -t "almed/rpi/ota/command" -m '{"type": "status"}'

# Watch responses
mosquitto_sub -h 10.42.0.1 -u ahu_user -P ahu_pass_2024 \
  -t "almed/rpi/ota/status"

# Trigger update
mosquitto_pub -h 10.42.0.1 -u ahu_user -P ahu_pass_2024 \
  -t "almed/rpi/ota/command" -m '{"type": "ota_update"}'
```

### View logs:
```bash
sudo journalctl -u ahu-ota-updater -f
```

---

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `MQTT_BROKER` | 10.42.0.1 | ESP32 hotspot IP |
| `MQTT_PORT` | 1883 | MQTT port |
| `MQTT_USERNAME` | ahu_user | MQTT user |
| `MQTT_PASSWORD` | ahu_pass_2024 | MQTT password |
| `DASHBOARD_DIR` | /home/pi/ahu_dashboard | Git repo path |
| `FLUTTER_PI_SERVICE` | ahu-dashboard | Systemd service |
| `GIT_BRANCH` | main | Branch to pull |

---

## MQTT Topics

| Topic | Direction | Purpose |
|-------|-----------|---------|
| `almed/rpi/ota/command` | Subscribe | Receive commands |
| `almed/rpi/ota/status` | Publish | Send status back |

## Commands

| Command | Action |
|---------|--------|
| `{"type": "ota_update"}` | git pull + restart |
| `{"type": "check_update"}` | Check if updates available |
| `{"type": "restart"}` | Restart dashboard only |
| `{"type": "status"}` | Report current status |

