#!/bin/bash
# ================================================================
# AHU Dashboard OTA Updater Installation Script
# Run this on the Raspberry Pi to install the OTA updater service
# ================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "========================================"
echo "AHU Dashboard OTA Updater Installation"
echo "========================================"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please do not run as root. Run as 'pi' user.${NC}"
    exit 1
fi

# Configuration
INSTALL_DIR="/home/pi/ahu_ota_updater"
SERVICE_NAME="ahu-ota-updater"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installation directory: $INSTALL_DIR"
echo "Script directory: $SCRIPT_DIR"
echo ""

# Step 1: Create installation directory
echo -e "${YELLOW}[1/6] Creating installation directory...${NC}"
mkdir -p "$INSTALL_DIR"

# Step 2: Copy files
echo -e "${YELLOW}[2/6] Copying files...${NC}"
cp "$SCRIPT_DIR/rpi_ota_updater.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"

# Step 3: Install Python dependencies
echo -e "${YELLOW}[3/6] Installing Python dependencies...${NC}"
pip3 install --user -r "$INSTALL_DIR/requirements.txt"

# Step 4: Create log file with proper permissions
echo -e "${YELLOW}[4/6] Setting up logging...${NC}"
sudo touch /var/log/ahu_ota_updater.log
sudo chown pi:pi /var/log/ahu_ota_updater.log

# Step 5: Install systemd service
echo -e "${YELLOW}[5/6] Installing systemd service...${NC}"
sudo cp "$SCRIPT_DIR/ahu-ota-updater.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

# Step 6: Configure sudoers for systemctl commands (no password needed)
echo -e "${YELLOW}[6/6] Configuring sudoers...${NC}"
SUDOERS_FILE="/etc/sudoers.d/ahu-ota-updater"
sudo tee "$SUDOERS_FILE" > /dev/null << 'EOF'
# Allow pi user to control ahu-dashboard service without password
pi ALL=(ALL) NOPASSWD: /bin/systemctl start ahu-dashboard
pi ALL=(ALL) NOPASSWD: /bin/systemctl stop ahu-dashboard
pi ALL=(ALL) NOPASSWD: /bin/systemctl restart ahu-dashboard
pi ALL=(ALL) NOPASSWD: /bin/systemctl status ahu-dashboard
EOF
sudo chmod 440 "$SUDOERS_FILE"

echo ""
echo -e "${GREEN}========================================"
echo "Installation Complete!"
echo "========================================${NC}"
echo ""
echo "To configure, edit /etc/default/ahu-ota-updater:"
echo "  GITHUB_TOKEN=your_github_token"
echo "  MQTT_BROKER=10.42.0.1"
echo ""
echo "To start the service:"
echo "  sudo systemctl start $SERVICE_NAME"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "To test MQTT commands, publish to: almed/rpi/ota/command"
echo "  Example: {\"type\": \"check_update\"}"
echo ""

