#!/bin/bash
# Persistent Hotspot Stability Fix for Raspberry Pi
# This script makes the hotspot stable and creates auto-recovery

set -e

echo "=========================================="
echo "  Persistent Hotspot Stability Fix"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# 1. Create WiFi power save disable service
echo "[1/4] Creating WiFi power save disable service..."
cat > /etc/systemd/system/wifi-power-save-off.service << 'EOF'
[Unit]
Description=Disable WiFi Power Saving
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sleep 5 && iw dev wlan0 set power_save off'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable wifi-power-save-off.service
echo "✓ WiFi power save disable service created"

# 2. Create hotspot auto-restart service
echo "[2/4] Creating hotspot watchdog service..."
cat > /usr/local/bin/hotspot-watchdog.sh << 'EOF'
#!/bin/bash
# Hotspot watchdog - auto-restart on failure

LOG_FILE="/var/log/hotspot-watchdog.log"
HOTSPOT_NAME="Hotspot"
CHECK_INTERVAL=30
RESTART_THRESHOLD=3
fail_count=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Hotspot watchdog started"

while true; do
    # Check if hotspot is active
    if nmcli con show --active | grep -q "$HOTSPOT_NAME"; then
        # Check if we can ping the hotspot IP
        if ping -c 1 -W 2 10.42.0.1 &> /dev/null; then
            # Hotspot is working
            if [ $fail_count -gt 0 ]; then
                log "Hotspot recovered after $fail_count failures"
                fail_count=0
            fi
        else
            fail_count=$((fail_count + 1))
            log "WARNING: Hotspot ping failed ($fail_count/$RESTART_THRESHOLD)"
            
            if [ $fail_count -ge $RESTART_THRESHOLD ]; then
                log "ERROR: Hotspot unresponsive, restarting..."
                nmcli con down "$HOTSPOT_NAME" 2>/dev/null || true
                sleep 2
                nmcli con up "$HOTSPOT_NAME"
                sleep 3
                iw dev wlan0 set power_save off 2>/dev/null || true
                fail_count=0
                log "Hotspot restarted"
            fi
        fi
    else
        log "WARNING: Hotspot not active, starting..."
        nmcli con up "$HOTSPOT_NAME" 2>/dev/null || true
        sleep 3
        iw dev wlan0 set power_save off 2>/dev/null || true
        fail_count=0
    fi
    
    sleep $CHECK_INTERVAL
done
EOF

chmod +x /usr/local/bin/hotspot-watchdog.sh

# Create systemd service for watchdog
cat > /etc/systemd/system/hotspot-watchdog.service << 'EOF'
[Unit]
Description=Hotspot Watchdog and Auto-Recovery
After=network.target NetworkManager.service

[Service]
Type=simple
ExecStart=/usr/local/bin/hotspot-watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable hotspot-watchdog.service
echo "✓ Hotspot watchdog service created"

# 3. Add connection limits and stability to NetworkManager hotspot
echo "[3/4] Optimizing NetworkManager hotspot connection..."
nmcli con modify "Hotspot" 802-11-wireless.band bg 2>/dev/null || true
nmcli con modify "Hotspot" 802-11-wireless.channel 6 2>/dev/null || true
nmcli con modify "Hotspot" 802-11-wireless.powersave 2 2>/dev/null || true
nmcli con modify "Hotspot" ipv4.method shared 2>/dev/null || true
echo "✓ Hotspot optimized"

# 4. Create manual restart script for convenience
echo "[4/4] Creating manual restart script..."
cat > /usr/local/bin/restart-hotspot << 'EOF'
#!/bin/bash
echo "Restarting hotspot..."
sudo nmcli con down "Hotspot" 2>/dev/null || true
sleep 2
sudo nmcli con up "Hotspot"
sleep 3
sudo iw dev wlan0 set power_save off 2>/dev/null || true
echo "✓ Hotspot restarted"
echo "Check status: nmcli con show --active | grep Hotspot"
EOF

chmod +x /usr/local/bin/restart-hotspot
echo "✓ Manual restart script created: /usr/local/bin/restart-hotspot"

# 5. Start services
echo ""
echo "Starting services..."
systemctl start wifi-power-save-off.service
systemctl start hotspot-watchdog.service

echo ""
echo "=========================================="
echo "  ✓ Hotspot Stability Fix Complete!"
echo "=========================================="
echo ""
echo "Changes applied:"
echo "  • Fixed WiFi channel 6 (no more hopping)"
echo "  • Power save permanently disabled"
echo "  • Auto-restart watchdog enabled"
echo "  • Manual restart: sudo restart-hotspot"
echo ""
echo "Monitor watchdog: sudo journalctl -u hotspot-watchdog -f"
echo "Check logs: tail -f /var/log/hotspot-watchdog.log"
echo ""
echo "Hotspot should now be stable!"
echo "=========================================="

