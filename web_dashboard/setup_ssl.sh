#!/bin/bash
# Setup Let's Encrypt SSL Certificate for app.almedequipments.in
# Run this script on your EC2 server

DOMAIN="app.almedequipments.in"
EMAIL="almedequip@gmail.com"  # CHANGE THIS TO YOUR EMAIL

echo "=========================================="
echo "Let's Encrypt SSL Certificate Setup"
echo "=========================================="
echo ""
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""
echo "IMPORTANT: Make sure to update EMAIL in this script!"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    
    # Detect OS and install certbot
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Cannot detect OS. Please install certbot manually."
        exit 1
    fi
    
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif [ "$OS" == "amzn" ] || [ "$OS" == "centos" ] || [ "$OS" == "rhel" ]; then
        if [ "$OS" == "amzn" ]; then
            sudo yum install -y certbot
        else
            sudo yum install -y epel-release
            sudo yum install -y certbot
        fi
    else
        echo "Unsupported OS. Please install certbot manually."
        exit 1
    fi
fi

echo ""
echo "Getting certificate for $DOMAIN..."
echo "Make sure:"
echo "  1. Domain $DOMAIN points to this server's IP"
echo "  2. Port 80 is open in security group"
echo "  3. Flask app is NOT running (certbot needs port 80)"
echo ""

# Stop Flask app if running (you may need to adjust this)
# sudo systemctl stop your-flask-app  # Uncomment if using systemd

# Get certificate
sudo certbot certonly --standalone \
    --preferred-challenges http \
    -d $DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --non-interactive

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Certificate obtained successfully!"
    echo ""
    echo "Certificate files:"
    echo "  Cert: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    echo "  Key:  /etc/letsencrypt/live/$DOMAIN/privkey.pem"
    echo ""
    echo "Update your config.py or environment variables:"
    echo "  SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    echo "  SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    echo ""
    echo "Set up auto-renewal (optional):"
    echo "  sudo certbot renew --dry-run"
    echo "  # Add to crontab: 0 0 * * * certbot renew --quiet"
else
    echo ""
    echo "❌ Failed to get certificate"
    echo "Common issues:"
    echo "  - Domain doesn't point to this server"
    echo "  - Port 80 is blocked or in use"
    echo "  - Firewall blocking port 80"
fi

