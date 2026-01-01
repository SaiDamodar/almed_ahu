# Raspberry Pi OTA Updater for AHU Dashboard

This service enables Over-The-Air (OTA) updates for the Flutter dashboard running on Raspberry Pi. It works similar to the ESP32 OTA system, allowing updates to be triggered from the web admin panel.

## Architecture

```
┌─────────────────────┐       ┌──────────────────────┐       ┌────────────────────┐
│   Web Dashboard     │──────▶│    Local MQTT        │──────▶│   RPi OTA Updater  │
│   (Admin Panel)     │       │    Broker            │       │   (This Service)   │
└─────────────────────┘       └──────────────────────┘       └────────────────────┘
         │                                                            │
         │                                                            ▼
         ▼                                                   ┌────────────────────┐
┌─────────────────────┐                                      │  GitHub Releases   │
│  GitHub Repository  │◀─────────────────────────────────────│  (Downloads)       │
│  (Push releases)    │                                      └────────────────────┘
└─────────────────────┘
```

## Features

- **OTA Updates**: Download and install Flutter dashboard updates from GitHub releases
- **Version Tracking**: Tracks current version and compares with available releases
- **Backup & Rollback**: Automatically backs up current version before update, supports rollback
- **Status Reporting**: Reports real-time status via MQTT for web dashboard monitoring
- **Service Control**: Can restart/stop the Flutter-Pi dashboard service

## Installation

### Prerequisites

- Raspberry Pi running Raspbian/Raspberry Pi OS
- Python 3.7+
- Local MQTT broker (Mosquitto) running on the Pi or network
- Flutter-Pi installed for running the dashboard

### Quick Install

1. Copy the `rpi_ota_updater` folder to your Raspberry Pi:
   ```bash
   scp -r rpi_ota_updater/ pi@<PI_IP>:/home/pi/
   ```

2. SSH into the Pi and run the installer:
   ```bash
   ssh pi@<PI_IP>
   cd /home/pi/rpi_ota_updater
   chmod +x install.sh
   ./install.sh
   ```

3. Configure environment (optional):
   ```bash
   sudo nano /etc/default/ahu-ota-updater
   ```
   
   Add your GitHub token for private repos:
   ```
   GITHUB_TOKEN=ghp_your_token_here
   ```

4. Start the service:
   ```bash
   sudo systemctl start ahu-ota-updater
   ```

### Manual Installation

1. Install Python dependencies:
   ```bash
   pip3 install --user paho-mqtt requests
   ```

2. Copy the service file:
   ```bash
   sudo cp ahu-ota-updater.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable ahu-ota-updater
   ```

3. Create log file:
   ```bash
   sudo touch /var/log/ahu_ota_updater.log
   sudo chown pi:pi /var/log/ahu_ota_updater.log
   ```

4. Configure sudoers for service control:
   ```bash
   sudo visudo -f /etc/sudoers.d/ahu-ota-updater
   ```
   Add:
   ```
   pi ALL=(ALL) NOPASSWD: /bin/systemctl start ahu-dashboard
   pi ALL=(ALL) NOPASSWD: /bin/systemctl stop ahu-dashboard
   pi ALL=(ALL) NOPASSWD: /bin/systemctl restart ahu-dashboard
   ```

## Configuration

Environment variables (set in `/etc/default/ahu-ota-updater` or systemd service):

| Variable | Default | Description |
|----------|---------|-------------|
| `MQTT_BROKER` | 10.42.0.1 | MQTT broker IP address |
| `MQTT_PORT` | 1883 | MQTT broker port |
| `MQTT_USERNAME` | ahu_user | MQTT username |
| `MQTT_PASSWORD` | ahu_pass_2024 | MQTT password |
| `DASHBOARD_DIR` | /home/pi/ahu_dashboard | Flutter dashboard directory |
| `BACKUP_DIR` | /home/pi/ahu_dashboard_backup | Backup directory |
| `FLUTTER_PI_SERVICE` | ahu-dashboard | Systemd service name for Flutter-Pi |
| `GITHUB_TOKEN` | (empty) | GitHub token for private repos |
| `GITHUB_REPO_OWNER` | ESPUpdaterzaid | GitHub username/org |
| `GITHUB_REPO_NAME` | almed-rpi-dashboard | Repository name |

## MQTT Topics

### Subscribe (Commands)
- `almed/rpi/ota/command` - Receive OTA commands

### Publish (Status)
- `almed/rpi/ota/status` - Report status updates
- `almed/rpi/ota/log` - Log messages

## Command Format

Send JSON commands to `almed/rpi/ota/command`:

### Check for Updates
```json
{
  "type": "check_update",
  "timestamp": 1704067200
}
```

### Trigger Update
```json
{
  "type": "ota_update",
  "version": "v1.2.0",  // or "latest"
  "timestamp": 1704067200
}
```

### Restart Dashboard
```json
{
  "type": "restart",
  "timestamp": 1704067200
}
```

### Rollback to Previous Version
```json
{
  "type": "rollback",
  "timestamp": 1704067200
}
```

### Get Status
```json
{
  "type": "status",
  "timestamp": 1704067200
}
```

## Status Response Format

The service publishes status updates to `almed/rpi/ota/status`:

```json
{
  "status": "downloading",
  "message": "Downloaded 50%",
  "timestamp": "2024-01-01T12:00:00",
  "current_version": "v1.1.0",
  "target_version": "v1.2.0",
  "progress": 50
}
```

Status values:
- `online` - Service is running and ready
- `checking` - Checking for updates
- `update_available` - New version available
- `up_to_date` - Already on latest version
- `backup` - Creating backup
- `stopping` - Stopping dashboard service
- `downloading` - Downloading update package
- `extracting` - Extracting update
- `applying` - Applying update files
- `starting` - Starting updated dashboard
- `complete` - Update completed successfully
- `error` - Error occurred
- `rolled_back` - Rollback completed

## GitHub Release Format

Create releases with the following structure:
- Tag: Version number (e.g., `v1.2.0`)
- Asset: `ahu_dashboard_v1.2.0.tar.gz` containing the Flutter bundle

The tar.gz should contain the Flutter assets directory (`flutter_assets/` or direct contents).

## Troubleshooting

### View Service Logs
```bash
sudo journalctl -u ahu-ota-updater -f
```

### View Application Logs
```bash
tail -f /var/log/ahu_ota_updater.log
```

### Test MQTT Connection
```bash
mosquitto_pub -h 10.42.0.1 -u ahu_user -P ahu_pass_2024 \
  -t "almed/rpi/ota/command" -m '{"type": "status"}'
```

### Subscribe to Status Updates
```bash
mosquitto_sub -h 10.42.0.1 -u ahu_user -P ahu_pass_2024 \
  -t "almed/rpi/ota/#"
```

### Manual Update Test
```bash
python3 /home/pi/ahu_ota_updater/rpi_ota_updater.py
```

## Web Admin Integration

The web admin panel (`/ota` page) includes an "RPi Dashboard" tab where you can:
- View current RPi dashboard version
- Check for available updates
- Trigger OTA updates
- View update progress
- Restart the dashboard
- Rollback to previous version
- Upload and push new releases

## Security Notes

- The GitHub token is stored in the environment file (`/etc/default/ahu-ota-updater`)
- MQTT communication should be secured in production (TLS)
- Sudoers configuration is limited to specific systemctl commands

