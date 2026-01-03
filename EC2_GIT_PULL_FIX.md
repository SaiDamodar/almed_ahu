# Fixing Git Permission Error on EC2

## Problem
When you try to `git pull` on EC2, you get:
```
error: cannot open '.git/FETCH_HEAD': Permission denied
```

This happens when git files were created/modified by a different user (often root via `sudo`).

## Solution

### Step 1: Navigate to your repository
```bash
cd ~/Almed_ahu_webapp
```

### Step 2: Check current ownership
```bash
ls -la .git/ | head -20
```

You'll likely see files owned by `root` instead of `ec2-user`.

### Step 3: Fix ownership of the entire repository
```bash
sudo chown -R ec2-user:ec2-user .
```

This changes ownership of all files in the repository to `ec2-user`.

### Step 4: Verify the fix
```bash
ls -la .git/ | head -5
```

You should now see `ec2-user` as the owner.

### Step 5: Pull the latest code
```bash
git pull origin main
```

This should now work without permission errors!

## Alternative: If you need to use sudo for git operations

If you absolutely must use `sudo` for git (not recommended), you can use:
```bash
sudo git pull origin main
```

But the better approach is to fix the ownership as shown above, so you don't need `sudo` for git operations.

## Prevention

To prevent this issue in the future:
- **Never use `sudo` with git commands** unless absolutely necessary
- If you need to install system dependencies, use `sudo` only for those commands
- Always run `git pull`, `git push`, `git checkout`, etc. as your regular user (`ec2-user`)

## Complete Workflow for Updating Code on EC2

```bash
# 1. Navigate to your repository
cd ~/Almed_ahu_webapp

# 2. Check git status
git status

# 3. Fix ownership if needed (only if you get permission errors)
sudo chown -R ec2-user:ec2-user .

# 4. Pull latest code
git pull origin main

# 5. If you have local changes you want to discard:
# git reset --hard origin/main

# 6. Restart your web application (if using systemd service)
sudo systemctl restart your-service-name
# OR if running manually:
# python app.py
```

