# AHU Control Dashboard

A professional touch-friendly Flutter dashboard for monitoring and controlling Air Handling Units (AHU) in hospital environments. Designed to run on Raspberry Pi with Flutter-Pi for embedded kiosk deployment.

## Features

### 🏥 Hospital User Mode
- Real-time monitoring of temperature and humidity
- Visual status indicators for all AHU components
- Start/Stop system control
- Adjust temperature and humidity setpoints
- View system logs in real-time
- Monitor motor status (drain and filter cleaning)
- Track compressor and heater operation

### 🔧 Admin Mode
- All hospital user features
- WiFi provisioning for ESP32 devices
  - Configure primary WiFi (Pi hotspot)
  - Configure secondary WiFi (hospital network)
- MQTT broker configuration
- Advanced system settings

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Raspberry Pi (Dashboard)                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Flutter-Pi Dashboard (This App)              │   │
│  │  • Touch-friendly UI                                 │   │
│  │  • Real-time MQTT communication                      │   │
│  │  • Multi-user support (Hospital/Admin)               │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ MQTT                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            Mosquitto MQTT Broker                     │   │
│  │  • localhost:1883 or 10.42.0.1:1883                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↕ MQTT (WiFi)
┌─────────────────────────────────────────────────────────────┐
│                    ESP32 AHU Controller                      │
│  • SHT45 Temperature/Humidity Sensor                         │
│  • L298N Motor Driver (2 motors)                             │
│  • Relay control (Compressor + Heater)                       │
│  • Dual WiFi support (Pi hotspot + Hospital network)         │
└─────────────────────────────────────────────────────────────┘
```

## MQTT Topics

The dashboard subscribes to these topics (wildcard: `almed/ahu/#`):

- `almed/ahu/{site}/{room}/{ahu-id}/telemetry` - Real-time sensor data
- `almed/ahu/{site}/{room}/{ahu-id}/state` - System state (retained)
- `almed/ahu/{site}/{room}/{ahu-id}/log` - Log messages
- `almed/ahu/{site}/{room}/{ahu-id}/status` - Online/offline status
- `almed/ahu/{site}/{room}/{ahu-id}/cmd` - Command topic (publish)
- `almed/ahu/{site}/{room}/{ahu-id}/provision/wifi` - WiFi provisioning (admin)
- `almed/ahu/{site}/{room}/{ahu-id}/provision/broker` - Broker provisioning (admin)

## Prerequisites

### For Development (Desktop)
- Flutter SDK 3.x or higher
- Dart SDK
- Linux, macOS, or Windows

### For Deployment (Raspberry Pi)
- Raspberry Pi 4 (2GB+ recommended) or Pi 3
- Raspberry Pi OS (Lite or Desktop)
- Touchscreen display (optional but recommended)
- Flutter-Pi installed
- Mosquitto MQTT broker running

## Installation

### 1. Clone the Repository

```bash
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate JSON Serialization Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Run on Desktop (Development)

```bash
flutter run -d linux
```

### 5. Build for Flutter-Pi (Production)

```bash
# Build the Flutter bundle
flutter build bundle

# The output will be in build/flutter_assets/
# Copy this to your Raspberry Pi
```

## Deployment on Raspberry Pi with Flutter-Pi

### Step 1: Install Flutter-Pi

```bash
# On Raspberry Pi
sudo apt update
sudo apt install -y cmake libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev \
  libdrm-dev libgbm-dev ttf-mscorefonts-installer fontconfig libsystemd-dev \
  libinput-dev libudev-dev libxkbcommon-dev

# Clone and build flutter-pi
git clone https://github.com/ardera/flutter-pi
cd flutter-pi
mkdir build && cd build
cmake ..
make -j4
sudo make install
```

### Step 2: Install Mosquitto MQTT Broker

```bash
sudo apt install -y mosquitto mosquitto-clients

# Configure mosquitto to allow authentication
sudo nano /etc/mosquitto/mosquitto.conf
```

Add these lines:
```
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
```

Create user credentials:
```bash
sudo mosquitto_passwd -c /etc/mosquitto/passwd almed
# Enter password: Almed1234$

sudo systemctl restart mosquitto
sudo systemctl enable mosquitto
```

### Step 3: Deploy the Dashboard

```bash
# On your development machine, build the app
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
flutter build bundle --release

# Copy to Raspberry Pi
scp -r build/flutter_assets pi@<pi-ip>:/home/pi/ahu_dashboard
```

### Step 4: Run Flutter-Pi in Kiosk Mode

```bash
# On Raspberry Pi
flutter-pi --release /home/pi/ahu_dashboard
```

### Step 5: Auto-Start on Boot (Kiosk Mode)

Create a systemd service:

```bash
sudo nano /etc/systemd/system/ahu-dashboard.service
```

Add:
```ini
[Unit]
Description=AHU Dashboard
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi
ExecStart=/usr/local/bin/flutter-pi --release /home/pi/ahu_dashboard
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable ahu-dashboard.service
sudo systemctl start ahu-dashboard.service
```

### Step 6: Admin Access (Debug Mode)

To access the Raspbian OS for debugging, you can:

1. **SSH into the Pi** (recommended):
   ```bash
   ssh pi@<pi-ip>
   ```

2. **Stop the dashboard service**:
   ```bash
   sudo systemctl stop ahu-dashboard.service
   ```

3. **Restart to desktop** (if needed):
   ```bash
   sudo systemctl set-default graphical.target
   sudo reboot
   ```

4. **Return to kiosk mode**:
   ```bash
   sudo systemctl set-default multi-user.target
   sudo systemctl start ahu-dashboard.service
   ```

## Configuration

### MQTT Broker Settings

Edit `lib/providers/app_provider.dart` to change default MQTT settings:

```dart
Future<bool> initializeMqtt({
  String broker = '127.0.0.1',  // Change to your broker IP
  int port = 1883,
  String username = 'almed',
  String password = 'Almed1234\$',
}) async {
  // ...
}
```

### Default AHU Units

Edit `lib/providers/app_provider.dart` in the `loadDefaultAhus()` method:

```dart
void loadDefaultAhus() {
  final defaultAhu = AhuUnit(
    id: 'ahu-01',
    name: 'ICU-1 AHU',
    site: 'hospitalA',
    room: 'icu1',
    org: 'almed',
  );
  addAhuUnit(defaultAhu);
  
  // Add more AHUs as needed
}
```

## Usage

### Hospital User Workflow

1. **Login**: Select "Hospital User" on the login screen
2. **Dashboard**: View all AHU units in your hospital
3. **Select AHU**: Tap on an AHU card to open detailed controls
4. **Monitor**: View real-time temperature, humidity, and component status
5. **Control**: Start/stop the system, adjust setpoints
6. **Logs**: Scroll through system logs at the bottom

### Admin Workflow

1. **Login**: Select "Administrator" on the login screen
2. **Dashboard**: View all AHU units
3. **Admin Settings**: Tap the settings icon in the app bar
4. **Select AHU**: Choose which AHU to configure
5. **WiFi Provisioning**: 
   - Enter primary WiFi credentials (Pi hotspot)
   - Enter secondary WiFi credentials (hospital network)
   - Tap "Provision WiFi"
6. **Broker Settings**:
   - Enter MQTT broker host and port
   - Tap "Provision Broker"

## Testing MQTT Connection

Test the MQTT broker connection:

```bash
# Subscribe to all AHU topics
mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t 'almed/#' -v

# Publish a test command
mosquitto_pub -h 127.0.0.1 -u almed -P 'Almed1234$' \
  -t 'almed/ahu/hospitalA/icu1/ahu-01/cmd' \
  -m '{"start":true}'
```

## Troubleshooting

### Dashboard won't connect to MQTT

1. Check if Mosquitto is running:
   ```bash
   sudo systemctl status mosquitto
   ```

2. Test MQTT connection:
   ```bash
   mosquitto_sub -h 127.0.0.1 -u almed -P 'Almed1234$' -t 'test' -v
   ```

3. Check firewall settings:
   ```bash
   sudo ufw allow 1883/tcp
   ```

### ESP32 not appearing in dashboard

1. Verify ESP32 is connected to WiFi
2. Check ESP32 serial output for connection status
3. Verify MQTT topics match between ESP32 and dashboard
4. Check ESP32 can reach the MQTT broker

### Touch not working on Pi

1. Ensure touchscreen drivers are installed
2. Check `/dev/input/` for touch device
3. Consider using the custom touchscreen driver mentioned in the main project

### Flutter-Pi won't start

1. Check if all dependencies are installed
2. Verify the Flutter bundle is complete
3. Check logs:
   ```bash
   journalctl -u ahu-dashboard.service -f
   ```

## Project Structure

```
ahu_dashboard/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   │   ├── ahu_telemetry.dart   # Telemetry data model
│   │   ├── ahu_state.dart       # State data model
│   │   ├── ahu_log.dart         # Log message model
│   │   ├── ahu_unit.dart        # AHU unit model
│   │   └── user_role.dart       # User role enum
│   ├── services/                 # Business logic
│   │   └── mqtt_service.dart    # MQTT communication
│   ├── providers/                # State management
│   │   └── app_provider.dart    # Main app state
│   ├── screens/                  # UI screens
│   │   ├── login_screen.dart    # Login/role selection
│   │   ├── dashboard_screen.dart # AHU list dashboard
│   │   ├── ahu_control_screen.dart # Detailed AHU control
│   │   └── admin_screen.dart    # Admin settings
│   └── widgets/                  # Reusable components
│       ├── sensor_display.dart  # Sensor readings widget
│       ├── control_panel.dart   # Control buttons widget
│       ├── motor_status.dart    # Motor status widget
│       └── log_viewer.dart      # Log display widget
├── pubspec.yaml                  # Dependencies
└── README.md                     # This file
```

## Technologies Used

- **Flutter** - UI framework
- **Provider** - State management
- **mqtt_client** - MQTT communication
- **json_serializable** - JSON parsing
- **fl_chart** - Data visualization (future use)
- **shared_preferences** - Local storage

## License

This project is part of the Almed AHU Control System.

## Support

For issues or questions, please refer to the main project documentation or contact the development team.

## Future Enhancements

- [ ] Fan speed control (3 speeds)
- [ ] Historical data charts
- [ ] Alert notifications
- [ ] Multi-site support
- [ ] User authentication
- [ ] Data export functionality
- [ ] Maintenance scheduling
- [ ] Energy consumption tracking
