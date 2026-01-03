# Testing Web Dashboard on EC2 - Complete Guide

## Part 1: Test Git Pull Permissions

### Step 1: Fix ownership (if you haven't already)
```bash
cd ~/Almed_ahu_webapp
sudo chown -R ec2-user:ec2-user .
```

### Step 2: Pull the latest code
```bash
git pull origin main
```

You should see:
```
Updating 85f4eb9..d6bdc4f
Fast-forward
 EC2_GIT_PULL_FIX.md          | 85 ++++++++++++++++++++++++++++++++++++++++++
 web_dashboard/app.py          |  1 +
 2 files changed, 86 insertions(+)
 create mode 100644 EC2_GIT_PULL_FIX.md
```

If you see "Already up to date", that means the code is already synced. The permission fix worked!

---

## Part 2: Test Web Server and Operating Buttons

### Step 1: Check if the web server is running

```bash
# Check if the Flask app is running
ps aux | grep "python.*app.py" | grep -v grep

# Or check if something is listening on port 5000 (HTTP) or 443 (HTTPS)
sudo netstat -tlnp | grep -E ':(5000|443)'
# OR
sudo ss -tlnp | grep -E ':(5000|443)'
```

### Step 2: Navigate to the web dashboard directory

```bash
cd ~/Almed_ahu_webapp/web_dashboard
```

### Step 3: Check if the server is running as a service

```bash
# Check for systemd service
systemctl status almed-webapp
# OR
systemctl status flask-app
# OR check all services
systemctl list-units --type=service | grep -i almed
systemctl list-units --type=service | grep -i flask
systemctl list-units --type=service | grep -i web
```

### Step 4: Start/Restart the web server

#### Option A: If running as a systemd service
```bash
# Restart the service
sudo systemctl restart almed-webapp
# OR whatever your service name is

# Check status
sudo systemctl status almed-webapp

# View logs
sudo journalctl -u almed-webapp -f
```

#### Option B: If running manually (not as a service)

First, find and stop any existing process:
```bash
# Find the process
ps aux | grep "python.*app.py" | grep -v grep

# Kill it if found (replace PID with actual process ID)
kill <PID>
# OR force kill
kill -9 <PID>
```

Then start the server:
```bash
cd ~/Almed_ahu_webapp/web_dashboard

# Start in background
nohup python app.py > webapp.log 2>&1 &

# OR start in screen/tmux session (better for debugging)
screen -S webapp
python app.py
# Press Ctrl+A then D to detach

# OR using tmux
tmux new -s webapp
python app.py
# Press Ctrl+B then D to detach
```

### Step 5: Check server logs

```bash
# If running with nohup
tail -f ~/Almed_ahu_webapp/web_dashboard/webapp.log

# If running as service
sudo journalctl -u almed-webapp -f

# If running in screen
screen -r webapp

# If running in tmux
tmux attach -t webapp
```

### Step 6: Test the web dashboard

1. **Find your EC2 public IP or domain:**
   ```bash
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

2. **Access the dashboard:**
   - If using HTTP: `http://your-ec2-ip:5000`
   - If using HTTPS: `https://your-domain.com` or `https://your-ec2-ip`
   - If using a custom domain: `https://app.almedequipments.in` (based on your config)

3. **Login:**
   - Default passcode is usually `1234` (check your `config.py`)

4. **Test the Operating Buttons:**
   - Navigate to the **AHU Control** page
   - Look for operating buttons (Start, Stop, Auto, Manual, etc.)
   - Try clicking the buttons to verify they respond
   - Check the browser console (F12) for any JavaScript errors

### Step 7: Verify server is accessible

```bash
# Test from EC2 itself
curl http://localhost:5000
# Should return HTML or redirect

# Test from outside (if security group allows)
# Use your browser or:
curl http://your-ec2-ip:5000
```

---

## Troubleshooting

### Server won't start

1. **Check Python dependencies:**
   ```bash
   cd ~/Almed_ahu_webapp/web_dashboard
   pip install -r requirements.txt
   ```

2. **Check config file:**
   ```bash
   ls -la config.py
   # Make sure it exists and has correct permissions
   ```

3. **Check port availability:**
   ```bash
   sudo lsof -i :5000
   # If something is using port 5000, kill it or change PORT in config.py
   ```

4. **Check AWS credentials:**
   ```bash
   # Make sure AWS credentials are set in config.py or environment
   cat config.py | grep AWS_ACCESS_KEY
   ```

### Buttons not working

1. **Check browser console (F12)** for JavaScript errors
2. **Check WebSocket connection** - look for SocketIO connection status
3. **Check server logs** for any errors when clicking buttons
4. **Verify MQTT/IoT Core connection** - buttons send commands via MQTT

### Permission errors

If you get permission errors when starting the server:
```bash
# Make sure you own the files
sudo chown -R ec2-user:ec2-user ~/Almed_ahu_webapp

# Check file permissions
ls -la ~/Almed_ahu_webapp/web_dashboard/
```

---

## Quick Reference Commands

```bash
# Fix git permissions
cd ~/Almed_ahu_webapp && sudo chown -R ec2-user:ec2-user . && git pull origin main

# Check if server is running
ps aux | grep "python.*app.py" | grep -v grep

# Restart server (if systemd service)
sudo systemctl restart almed-webapp && sudo systemctl status almed-webapp

# Start server manually
cd ~/Almed_ahu_webapp/web_dashboard && nohup python app.py > webapp.log 2>&1 &

# View logs
tail -f ~/Almed_ahu_webapp/web_dashboard/webapp.log

# Get EC2 public IP
curl http://169.254.169.254/latest/meta-data/public-ipv4
```

