# ALMED AHU Dashboard - Raspberry Pi Deployment Guide

Complete setup guide for deploying the Flutter-Pi AHU dashboard on Raspberry Pi with kiosk mode.

## 🎯 Deployment Overview

This guide covers:
- Flutter-Pi installation
- Kiosk mode setup
- Auto-boot configuration
- Production optimization
- Troubleshooting

## 📋 Prerequisites

### Hardware Requirements
- **Raspberry Pi 4B** (4GB+ RAM recommended)
- **MicroSD Card** (32GB+ Class 10)
- **Touchscreen** (7" or 10" recommended)
- **Power Supply** (5V 3A official adapter)
- **Network**: WiFi or Ethernet

### Software Requirements
- **Raspberry Pi OS** (64-bit recommended)
- **Flutter SDK** (3.0+)
- **Flutter-Pi** (latest version)
- **MQTT Broker** (Mosquitto)

## 🚀 Step 1: Raspberry Pi Setup

### 1.1 Install Raspberry Pi OS
```bash
# Download Raspberry Pi Imager
# Flash Raspberry Pi OS Lite (64-bit) to SD card
# Enable SSH, WiFi, and set hostname: almed-ahu
```

### 1.2 Initial Configuration
```bash
# SSH into Pi
ssh pi@almed-ahu.local

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y git curl wget build-essential cmake
sudo apt install -y libgl1-mesa-dev libgles2-mesa-dev
sudo apt install -y libegl1-mesa-dev libdrm-dev
sudo apt install -y libgbm-dev libinput-dev libxkbcommon-dev
```

## 🔧 Step 2: Flutter-Pi Installation

### 2.1 Install Flutter
```bash
# Download Flutter
cd /home/pi
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
tar xf flutter_linux_3.16.0-stable.tar.xz

# Add to PATH
echo 'export PATH="$PATH:/home/pi/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
flutter --version
```

### 2.2 Install Flutter-Pi
```bash
# Clone Flutter-Pi
cd /home/pi
git clone https://github.com/ardera/flutter-pi.git
cd flutter-pi

# Build Flutter-Pi
mkdir build && cd build
cmake ..
make -j4

# Install
sudo make install
```

### 2.3 Configure Flutter-Pi
```bash
# Create Flutter-Pi config
sudo mkdir -p /etc/flutter-pi
sudo tee /etc/flutter-pi/config.txt << EOF
# Flutter-Pi Configuration
dtoverlay=vc4-kms-v3d
max_framebuffers=2
disable_overscan=1
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1024 600 60 6 0 0 0
hdmi_drive=2
display_rotate=0
EOF
```

## 📱 Step 3: Application Deployment

### 3.1 Build Flutter App
```bash
# On development machine
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard

# Build for Linux ARM64
flutter build linux --release --target-platform linux-arm64

# Copy to Pi
scp -r build/linux/arm64/release/bundle pi@almed-ahu.local:/home/pi/ahu_dashboard/
```

### 3.2 Setup on Raspberry Pi
```bash
# SSH into Pi
ssh pi@almed-ahu.local

# Create app directory
sudo mkdir -p /opt/ahu_dashboard
sudo cp -r /home/pi/ahu_dashboard/* /opt/ahu_dashboard/
sudo chown -R pi:pi /opt/ahu_dashboard
```

## 🖥️ Step 4: Kiosk Mode Setup

### 4.1 Install Display Manager
```bash
# Install lightdm
sudo apt install -y lightdm

# Configure lightdm
sudo tee /etc/lightdm/lightdm.conf << EOF
[SeatDefaults]
autologin-user=pi
autologin-user-timeout=0
user-session=openbox
greeter-session=lightdm-gtk-greeter
EOF
```

### 4.2 Create Kiosk Script
```bash
# Create startup script
sudo tee /opt/ahu_dashboard/start_kiosk.sh << 'EOF'
#!/bin/bash

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Hide cursor
unclutter -idle 0.5 -root &

# Start Flutter-Pi app
cd /opt/ahu_dashboard
flutter-pi --release .

# If app crashes, restart
if [ $? -ne 0 ]; then
    sleep 5
    exec $0
fi
EOF

sudo chmod +x /opt/ahu_dashboard/start_kiosk.sh
```

### 4.3 Configure Auto-Start
```bash
# Create systemd service
sudo tee /etc/systemd/system/ahu-dashboard.service << EOF
[Unit]
Description=ALMED AHU Dashboard
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/opt/ahu_dashboard
ExecStart=/opt/ahu_dashboard/start_kiosk.sh
Restart=always
RestartSec=5
Environment=DISPLAY=:0

[Install]
WantedBy=graphical.target
EOF

# Enable service
sudo systemctl daemon-reload
sudo systemctl enable ahu-dashboard.service
```

## 🌐 Step 5: MQTT Broker Setup

### 5.1 Install Mosquitto
```bash
# Install MQTT broker
sudo apt install -y mosquitto mosquitto-clients

# Configure Mosquitto
sudo tee /etc/mosquitto/mosquitto.conf << EOF
# MQTT Configuration
listener 1883
allow_anonymous true
persistence true
persistence_location /var/lib/mosquitto/
log_dest file /var/log/mosquitto/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information
EOF

# Start and enable
sudo systemctl start mosquitto
sudo systemctl enable mosquitto
```

### 5.2 Test MQTT
```bash
# Test connection
mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT"
mosquitto_sub -h localhost -t "test/topic"
```

## 🔧 Step 6: Production Optimization

### 6.1 Performance Tuning
```bash
# GPU memory split
sudo raspi-config
# Advanced Options → Memory Split → 128

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable hciuart
sudo systemctl disable ModemManager
```

### 6.2 Network Configuration
```bash
# Static IP (optional)
sudo tee -a /etc/dhcpcd.conf << EOF
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8
EOF
```

### 6.3 Security Hardening
```bash
# Disable SSH password auth (use keys only)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Firewall (optional)
sudo ufw enable
sudo ufw allow 1883  # MQTT
sudo ufw allow 22    # SSH
```

## 🚀 Step 7: Final Setup

### 7.1 Reboot and Test
```bash
# Reboot Pi
sudo reboot

# Check service status
sudo systemctl status ahu-dashboard.service

# View logs
sudo journalctl -u ahu-dashboard.service -f
```

### 7.2 Touchscreen Calibration
```bash
# If touchscreen needs calibration
sudo apt install -y xinput-calibrator
xinput_calibrator

# Save calibration to X11 config
sudo mkdir -p /etc/X11/xorg.conf.d
# Follow calibration tool instructions
```

## 🔍 Troubleshooting

### Common Issues

#### App Won't Start
```bash
# Check Flutter-Pi installation
flutter-pi --version

# Check app bundle
ls -la /opt/ahu_dashboard/

# Check logs
sudo journalctl -u ahu-dashboard.service -n 50
```

#### Touchscreen Not Working
```bash
# Check input devices
xinput list

# Test touch
xinput test-xi2 --root

# Recalibrate if needed
xinput_calibrator
```

#### MQTT Connection Issues
```bash
# Check Mosquitto status
sudo systemctl status mosquitto

# Test connection
mosquitto_pub -h localhost -t "almed/test" -m "test"
mosquitto_sub -h localhost -t "almed/#"
```

#### Performance Issues
```bash
# Check GPU memory
vcgencmd get_mem gpu

# Monitor resources
htop
iostat -x 1

# Check temperature
vcgencmd measure_temp
```

### Debug Mode
```bash
# Enable debug logging
sudo systemctl edit ahu-dashboard.service

# Add:
[Service]
Environment=FLUTTER_PI_DEBUG=1
Environment=FLUTTER_PI_VERBOSE=1

# Restart service
sudo systemctl daemon-reload
sudo systemctl restart ahu-dashboard.service
```

## 📊 Monitoring

### System Health
```bash
# Create monitoring script
sudo tee /opt/ahu_dashboard/monitor.sh << 'EOF'
#!/bin/bash
echo "=== ALMED AHU Dashboard Status ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Temperature: $(vcgencmd measure_temp)"
echo "GPU Memory: $(vcgencmd get_mem gpu)"
echo "Service Status:"
systemctl is-active ahu-dashboard.service
echo "MQTT Status:"
systemctl is-active mosquitto
echo "================================"
EOF

sudo chmod +x /opt/ahu_dashboard/monitor.sh

# Run monitoring
/opt/ahu_dashboard/monitor.sh
```

### Log Rotation
```bash
# Configure log rotation
sudo tee /etc/logrotate.d/ahu-dashboard << EOF
/var/log/ahu-dashboard.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 pi pi
}
EOF
```

## 🔄 Updates

### Application Updates
```bash
# On development machine
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
flutter build linux --release --target-platform linux-arm64

# Deploy to Pi
scp -r build/linux/arm64/release/bundle pi@almed-ahu.local:/tmp/
ssh pi@almed-ahu.local "sudo systemctl stop ahu-dashboard.service && sudo cp -r /tmp/bundle/* /opt/ahu_dashboard/ && sudo systemctl start ahu-dashboard.service"
```

### System Updates
```bash
# Update Pi system
sudo apt update && sudo apt upgrade -y

# Update Flutter-Pi
cd /home/pi/flutter-pi
git pull
cd build && make -j4 && sudo make install
```

## 📱 Kiosk Features

### Auto-Recovery
- **Crash Recovery**: App restarts automatically
- **Service Monitoring**: Systemd keeps app running
- **Health Checks**: Regular status monitoring

### Touch Optimization
- **Large Targets**: 44px minimum touch areas
- **Gesture Support**: Swipe, tap, long press
- **Visual Feedback**: Button states, animations
- **Accessibility**: Screen reader support

### Production Ready
- **No Desktop**: Pure kiosk mode
- **Auto-Login**: No user interaction required
- **Network Ready**: WiFi/Ethernet configuration
- **Remote Access**: SSH for maintenance

## 🎯 Final Checklist

- [ ] Raspberry Pi OS installed and updated
- [ ] Flutter-Pi compiled and installed
- [ ] Application built and deployed
- [ ] Kiosk mode configured
- [ ] MQTT broker running
- [ ] Touchscreen calibrated
- [ ] Auto-start enabled
- [ ] Performance optimized
- [ ] Security hardened
- [ ] Monitoring setup
- [ ] Documentation complete

---

**Your ALMED AHU Dashboard is now ready for production! 🚀**

For support, check logs with `sudo journalctl -u ahu-dashboard.service -f`
