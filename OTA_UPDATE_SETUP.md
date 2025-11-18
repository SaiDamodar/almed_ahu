# OTA Update System Setup Guide

## Overview

This system allows you to push firmware updates to ESP32 devices over the air (OTA) via the web dashboard. The workflow is:

1. **Upload/Paste firmware code** in the web dashboard
2. **Push code to GitHub** repository
3. **Send MQTT command** to ESP32 to download and install the update

## Architecture

```
Web Dashboard → GitHub Repository → MQTT Command → ESP32 → GitHub Download → OTA Update
```

## Prerequisites

1. **GitHub Account** with a private repository for ESP32 firmware
2. **GitHub Personal Access Token** with `repo` permissions
3. **ESP32 device** connected to WiFi and AWS IoT Core
4. **Web dashboard** running and configured

## Step 1: Create GitHub Repository

1. Create a new **private** repository on GitHub (e.g., `almed-esp32-firmware`)
2. Create a folder structure:
   ```
   firmware/
     └── esp32_main.ino
   ```
3. Note your repository details:
   - Owner/Username: `your-username`
   - Repository name: `almed-esp32-firmware`
   - Branch: `main` (or `master`)

## Step 2: Generate GitHub Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name: `ALMED-OTA-Updates`
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again!)

## Step 3: Configure Web Dashboard

Edit `web_dashboard/config.py`:

```python
# GitHub OTA Configuration
GITHUB_TOKEN = 'ghp_your_token_here'  # Your GitHub Personal Access Token
GITHUB_REPO_OWNER = 'your-username'  # Your GitHub username
GITHUB_REPO_NAME = 'almed-esp32-firmware'  # Repository name
GITHUB_REPO_BRANCH = 'main'  # Branch name
GITHUB_FIRMWARE_PATH = 'firmware/esp32_main.ino'  # Path to firmware file in repo
```

**Security Note:** In production, use environment variables:
```python
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN', '')
```

## Step 4: Install Python Dependencies

```bash
cd web_dashboard
pip install -r requirements.txt
```

This will install `PyGithub==2.1.1` for GitHub API integration.

## Step 5: ESP32 Firmware

The ESP32 firmware (`esp32_main.ino`) already includes:
- ✅ OTA update handler
- ✅ MQTT command listener
- ✅ GitHub API client
- ✅ Status reporting

**No additional configuration needed** - the ESP32 will automatically handle OTA commands received via MQTT.

## Step 6: Using the OTA System

### Via Web Dashboard

1. Navigate to **OTA Updates** page (`/ota`)
2. **Select a device** from the dropdown
3. **Upload or paste firmware code**:
   - Click the upload area to select a `.ino` file, OR
   - Drag and drop a file, OR
   - Paste code directly into the editor
4. **Enter commit message** (optional, defaults to "OTA firmware update")
5. **Click "Push to GitHub"**:
   - Code is pushed to your GitHub repository
   - Commit SHA is saved for tracking
6. **Click "Send OTA Update"**:
   - MQTT command is sent to the selected ESP32 device
   - Device downloads firmware from GitHub
   - Device installs update and reboots

### Monitoring Update Status

- **Web Dashboard**: Status log shows progress
- **ESP32 Serial Monitor**: Detailed update progress
- **MQTT**: OTA status messages published to `esp32/pub` topic

## MQTT Command Format

The OTA command sent to ESP32:

```json
{
  "type": "ota_update",
  "github_url": "https://raw.githubusercontent.com/owner/repo/branch/path",
  "github_api_url": "https://api.github.com/repos/owner/repo/contents/path",
  "github_token": "ghp_token_here",
  "version": "latest",
  "commit_sha": "abc123...",
  "repo_owner": "your-username",
  "repo_name": "almed-esp32-firmware",
  "repo_branch": "main",
  "firmware_path": "firmware/esp32_main.ino"
}
```

## ESP32 OTA Status Messages

ESP32 publishes status updates during OTA:

```json
{
  "type": "ota_status",
  "status": "downloading|installing|success|error",
  "message": "Status description",
  "thing": "AHU_ESP2",
  "ts": 1234567890
}
```

## Troubleshooting

### "GitHub configuration is missing"
- Check `config.py` has all GitHub settings configured
- Verify `GITHUB_TOKEN`, `GITHUB_REPO_OWNER`, and `GITHUB_REPO_NAME` are set

### "Failed to push to GitHub"
- Verify GitHub token has `repo` permissions
- Check repository name and owner are correct
- Ensure repository exists and is accessible

### "HTTP error: 401" (Unauthorized)
- GitHub token may be expired or invalid
- Regenerate token and update `config.py`

### "HTTP error: 404" (Not Found)
- Check repository path is correct
- Verify `GITHUB_FIRMWARE_PATH` matches actual file path in repo
- Ensure branch name is correct

### ESP32 not receiving OTA command
- Verify ESP32 is connected to WiFi
- Check ESP32 is subscribed to `esp32/sub` topic
- Verify AWS IoT Core connection is active
- Check MQTT message is being published correctly

### OTA update fails on ESP32
- Check Serial Monitor for detailed error messages
- Verify WiFi connection is stable during download
- Ensure firmware file size is within ESP32 flash limits
- Check GitHub URL is accessible from ESP32 network

## Security Considerations

1. **GitHub Token Security**:
   - Never commit tokens to version control
   - Use environment variables in production
   - Rotate tokens periodically
   - Use tokens with minimal required permissions

2. **Private Repository**:
   - Keep firmware repository private
   - Token is sent to ESP32 via MQTT (encrypted by AWS IoT Core)
   - Consider using separate tokens for different environments

3. **Firmware Validation**:
   - Always test firmware before pushing OTA updates
   - Consider adding firmware signature verification (future enhancement)

## Future Enhancements

- [ ] Firmware version tracking
- [ ] Rollback capability
- [ ] Batch updates (multiple devices)
- [ ] Update scheduling
- [ ] Firmware signature verification
- [ ] Update progress percentage
- [ ] Raspberry Pi OTA support (as mentioned)

## API Endpoints

### POST `/api/ota/push-to-github`
Push firmware code to GitHub repository.

**Request:**
```json
{
  "code": "// ESP32 firmware code...",
  "message": "OTA firmware update"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Firmware pushed to GitHub successfully",
  "commit_sha": "abc123...",
  "commit_url": "https://github.com/..."
}
```

### POST `/api/ota/trigger-update`
Send MQTT command to ESP32 to trigger OTA update.

**Request:**
```json
{
  "device_id": "AHU_ESP2",
  "version": "latest",
  "commit_sha": "abc123..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "OTA update command sent to device",
  "device_id": "AHU_ESP2",
  "firmware_url": "https://raw.githubusercontent.com/..."
}
```

## Notes

- ESP32 does **NOT** check for updates on boot - updates are only triggered via MQTT command
- The system supports both public and private GitHub repositories
- For private repos, the GitHub token is sent to ESP32 via MQTT (encrypted)
- ESP32 uses GitHub API with `Accept: application/vnd.github.v3.raw` header to get raw content
- Update process: Download → Install → Reboot (automatic)

