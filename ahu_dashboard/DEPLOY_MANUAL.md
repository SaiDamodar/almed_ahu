# Manual Deployment Guide

If the automatic deployment script fails due to SSH issues, follow these steps:

## Step 1: Build the Flutter Bundle

```bash
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
flutter build bundle --release
```

The output will be in: `build/flutter_assets/`

## Step 2: Find Your Raspberry Pi

### Check if Pi is reachable:
```bash
# Try ping
ping raspberrypi.local

# Or try the default Pi hotspot IP
ping 10.42.0.1

# Or check your local network
ip addr show
```

### Common Pi IP addresses:
- `10.42.0.1` - Pi hotspot mode
- `192.168.1.XXX` - Home network
- `raspberrypi.local` - mDNS hostname

## Step 3: Copy Files to Pi

### Option A: Using SCP (if SSH works)
```bash
# Replace <PI_IP> with your actual Pi IP
scp -r build/flutter_assets pi@<PI_IP>:/home/pi/ahu_dashboard
```

### Option B: Using USB Drive
1. Copy `build/flutter_assets/` to a USB drive
2. Plug USB into Raspberry Pi
3. On Pi: 
   ```bash
   sudo mkdir -p /media/usb
   sudo mount /dev/sda1 /media/usb
   cp -r /media/usb/flutter_assets /home/pi/ahu_dashboard
   ```

### Option C: Using Network Share
1. Set up Samba on Pi
2. Copy files via file browser

## Step 4: Enable SSH on Raspberry Pi

If SSH is not working:

### From Pi Desktop:
1. Open Raspberry Pi Configuration
2. Go to Interfaces tab
3. Enable SSH
4. Click OK

### From Terminal on Pi:
```bash
sudo raspi-config
# Navigate to: Interface Options → SSH → Enable
```

### Or directly:
```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

## Step 5: Test SSH Connection

```bash
# Test connection
ssh pi@<PI_IP>

# Default password is usually: raspberry
```

## Step 6: Run Dashboard on Pi

Once files are copied:

```bash
# SSH into Pi
ssh pi@<PI_IP>

# Run flutter-pi
flutter-pi --release /home/pi/ahu_dashboard
```

## Troubleshooting

### Can't find Pi IP?
```bash
# On Pi, run:
hostname -I

# Or check network settings:
ip addr show
```

### SSH still not working?
```bash
# On Pi, check SSH status:
sudo systemctl status ssh

# Check if port 22 is open:
sudo netstat -tlnp | grep :22
```

### Permission denied?
```bash
# On Pi, fix permissions:
sudo chown -R pi:pi /home/pi/ahu_dashboard
chmod -R 755 /home/pi/ahu_dashboard
```

## Quick Test Without Pi

You can test the dashboard on your current machine:

```bash
cd /home/almedproto/Documents/almed_ahu/ahu_dashboard
flutter run -d linux
```

This will run the dashboard on your desktop for testing!

