# Hostinger VPS Setup Guide (If You Choose This Route)

## Prerequisites

- ✅ Hostinger VPS plan (minimum 1GB RAM, 2GB recommended)
- ✅ Domain name (`almed.org.in`)
- ✅ SSH access to VPS
- ✅ Basic Linux knowledge

## Step-by-Step Setup

### Step 1: Access Your VPS

1. Get VPS IP address from Hostinger dashboard
2. SSH into VPS:
   ```bash
   ssh root@your-vps-ip
   ```

### Step 2: Update System

```bash
apt update && apt upgrade -y
```

### Step 3: Install Required Software

```bash
# Install Python, pip, git, nginx
apt install python3 python3-pip python3-venv git nginx -y

# Install certbot for SSL
apt install certbot python3-certbot-nginx -y
```

### Step 4: Clone Your Repository

```bash
# Navigate to web directory
cd /var/www

# Clone your repo (update with your actual repo URL)
git clone https://github.com/your-username/almed_ahu.git

# Navigate to web dashboard
cd almed_ahu/web_dashboard
```

### Step 5: Create Virtual Environment

```bash
# Create virtual environment
python3 -venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 6: Configure Environment Variables

```bash
# Create .env file
nano .env
```

Add your environment variables:
```env
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=your_key_here
AWS_SECRET_ACCESS_KEY=your_secret_here
AWS_IOT_ENDPOINT=al924mkqhctlg-ats.iot.ap-south-1.amazonaws.com
MONGO_URI=your_mongo_uri_here
SECRET_KEY=your_secret_key_here
ADMIN_USERNAME=admin
ADMIN_PASSWORD=1234
CORS_ORIGINS=*
PORT=5000
```

Save and exit (Ctrl+X, Y, Enter)

### Step 7: Install Gunicorn

```bash
pip install gunicorn
```

### Step 8: Create Systemd Service

```bash
# Create service file
nano /etc/systemd/system/almed-dashboard.service
```

Add content:
```ini
[Unit]
Description=ALMED AHU Dashboard
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/almed_ahu/web_dashboard
Environment="PATH=/var/www/almed_ahu/web_dashboard/venv/bin"
ExecStart=/var/www/almed_ahu/web_dashboard/venv/bin/gunicorn --worker-class eventlet -w 1 --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

Save and exit.

Enable and start service:
```bash
systemctl daemon-reload
systemctl enable almed-dashboard
systemctl start almed-dashboard
```

Check status:
```bash
systemctl status almed-dashboard
```

### Step 9: Configure Nginx Reverse Proxy

```bash
# Create Nginx config
nano /etc/nginx/sites-available/almed-dashboard
```

Add content:
```nginx
server {
    listen 80;
    server_name api.almed.org.in;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /socket.io {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Enable site:
```bash
ln -s /etc/nginx/sites-available/almed-dashboard /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default  # Remove default site
nginx -t  # Test configuration
systemctl restart nginx
```

### Step 10: Configure SSL with Let's Encrypt

```bash
# Get SSL certificate
certbot --nginx -d api.almed.org.in

# Follow prompts:
# - Enter email
# - Agree to terms
# - Choose redirect HTTP to HTTPS (recommended)

# Auto-renewal is set up automatically
```

### Step 11: Configure Firewall

```bash
# Allow SSH, HTTP, HTTPS
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable
```

### Step 12: Configure Domain DNS

In your domain registrar (where you bought `almed.org.in`):

**Add A Record:**
```
Type: A
Name: api
Value: [Your VPS IP Address]
TTL: 3600
```

Wait 15-30 minutes for DNS propagation.

### Step 13: Test

1. **Check service status:**
   ```bash
   systemctl status almed-dashboard
   ```

2. **Check logs:**
   ```bash
   journalctl -u almed-dashboard -f
   ```

3. **Test in browser:**
   - Go to: `https://api.almed.org.in/login`
   - Should load successfully

4. **Test Android app:**
   - Update `app_config.dart` with new URL
   - Test on mobile data (should work!)

## Maintenance

### View Logs
```bash
# Application logs
journalctl -u almed-dashboard -f

# Nginx logs
tail -f /var/log/nginx/error.log
tail -f /var/log/nginx/access.log
```

### Restart Service
```bash
systemctl restart almed-dashboard
```

### Update Application
```bash
cd /var/www/almed_ahu/web_dashboard
git pull
source venv/bin/activate
pip install -r requirements.txt
systemctl restart almed-dashboard
```

### Update System
```bash
apt update && apt upgrade -y
```

### SSL Certificate Renewal
```bash
# Automatic (set up by certbot)
certbot renew

# Manual renewal
certbot renew --dry-run
```

## Troubleshooting

### Service Won't Start
```bash
# Check logs
journalctl -u almed-dashboard -n 50

# Check if port is in use
netstat -tulpn | grep 5000

# Check Python dependencies
cd /var/www/almed_ahu/web_dashboard
source venv/bin/activate
pip list
```

### Nginx Errors
```bash
# Test configuration
nginx -t

# Check error logs
tail -f /var/log/nginx/error.log
```

### Permission Issues
```bash
# Ensure proper permissions
chown -R root:root /var/www/almed_ahu
chmod -R 755 /var/www/almed_ahu
```

## Security Considerations

1. **Firewall**: Only allow necessary ports
2. **SSH**: Use SSH keys, disable password login
3. **Updates**: Keep system updated
4. **Backups**: Set up regular backups
5. **Environment Variables**: Never commit `.env` file

## Cost Comparison

| Item | Cost |
|------|------|
| Hostinger VPS (1GB) | ~$5/month |
| Hostinger VPS (2GB) | ~$8/month |
| Domain (almed.org.in) | ~$10-15/year |
| SSL Certificate | Free (Let's Encrypt) |
| **Total** | **~$5-8/month** |

**vs Railway:** ~$5-20/month (but easier setup, less maintenance)

---

## Recommendation

**Unless you need full server control, stick with Railway.**

Railway provides:
- ✅ Easier setup (10 minutes vs 2-4 hours)
- ✅ Automatic deployments
- ✅ Built-in monitoring
- ✅ Less maintenance
- ✅ Similar pricing

Hostinger VPS only if:
- You need specific server configurations
- You want full control
- You're comfortable with Linux

