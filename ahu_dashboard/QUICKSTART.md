# Quick Start Guide

## Testing on Desktop (Development)

### 1. Ensure MQTT Broker is Running

```bash
# Check if mosquitto is running
sudo systemctl status mosquitto

# If not installed, install it
sudo apt install mosquitto mosquitto-clients

# Start it
sudo systemctl start mosquitto
```

### 2. Configure MQTT User

```bash
# Create user
sudo mosquitto_passwd -c /etc/mosquitto/passwd almed
# Password: Almed1234$

# Edit config
sudo nano /etc/mosquitto/mosquitto.conf
```

Add:
```
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
```

Restart:
```bash
sudo systemctl restart mosquitto
```

### 3. Run the Dashboard

```bash
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
flutter run -d linux
```

### 4. Test Without ESP32

You can simulate ESP32 data using mosquitto_pub:

```bash
# Simulate telemetry
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/telemetry' \
  -m '{"temp":22.5,"hum":55.0,"m1":false,"m2":false,"run":false,"cp":false,"heater":false,"tempSet":22.0,"humSet":55.0,"ts":12345}'

# Simulate state
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/state' -r \
  -m '{"run":false,"m1":false,"m2":false,"cp":false,"heater":false,"tempSet":22.0,"humSet":55.0,"ip":"192.168.1.100"}'

# Simulate status
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/status' -r \
  -m 'online'

# Simulate log
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/log' \
  -m '{"ts":12345,"lvl":"INFO","msg":"System started"}'
```

## Deploying to Raspberry Pi

### Quick Deploy Script

Create a file `deploy.sh`:

```bash
#!/bin/bash

# Build the Flutter app
echo "Building Flutter app..."
flutter build bundle --release

# Copy to Raspberry Pi
echo "Copying to Raspberry Pi..."
PI_IP="10.42.0.1"  # Change to your Pi IP
scp -r build/flutter_assets pi@$PI_IP:/home/pi/ahu_dashboard

echo "Deployment complete!"
echo "On Pi, run: flutter-pi --release /home/pi/ahu_dashboard"
```

Make it executable:
```bash
chmod +x deploy.sh
./deploy.sh
```

## Common Commands

### View MQTT Messages
```bash
mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t 'almed/#' -v
```

### Send Start Command
```bash
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/cmd' \
  -m '{"start":true}'
```

### Send Stop Command
```bash
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/cmd' \
  -m '{"stop":true}'
```

### Set Temperature
```bash
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/cmd' \
  -m '{"setpoint":24.0}'
```

### Set Humidity
```bash
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/cmd' \
  -m '{"humset":60.0}'
```

## Troubleshooting Quick Fixes

### Can't connect to MQTT
```bash
# Check if running
sudo systemctl status mosquitto

# Restart
sudo systemctl restart mosquitto

# Check logs
sudo journalctl -u mosquitto -f
```

### Flutter build errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Pi won't boot to dashboard
```bash
# SSH into Pi
ssh pi@<pi-ip>

# Check service status
sudo systemctl status ahu-dashboard.service

# View logs
journalctl -u ahu-dashboard.service -f

# Restart service
sudo systemctl restart ahu-dashboard.service
```
