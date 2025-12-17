# Upload API Key from Windows to EC2

Since you're on Windows, here are the methods to upload your key file.

## Method 1: Using PowerShell (Recommended)

### Step 1: Open PowerShell

Press `Win + X` → Select "Windows PowerShell" or "Terminal"

### Step 2: Upload Key File

```powershell
# Replace /path/to/your-key.pem with your actual key file path
# The key file should be AuthKey_F3WU9KJ42M.p8

scp -i C:\path\to\your-key.pem `
  C:\Users\YourUsername\Downloads\AuthKey_F3WU9KJ42M.p8 `
  ec2-user@13.233.138.87:~/.appstoreconnect/private_keys/
```

**Note**: If `scp` command not found, install OpenSSH:
- Settings → Apps → Optional Features → Add "OpenSSH Client"

---

## Method 2: Using WSL (Windows Subsystem for Linux)

If you have WSL installed:

```bash
# In WSL terminal
scp -i /mnt/c/path/to/your-key.pem \
  /mnt/c/Users/YourUsername/Downloads/AuthKey_F3WU9KJ42M.p8 \
  ec2-user@13.233.138.87:~/.appstoreconnect/private_keys/
```

---

## Method 3: Using PuTTY pscp

1. **Download PuTTY**: https://www.putty.org/
2. **Open Command Prompt** (cmd)
3. **Navigate to PuTTY folder** (usually `C:\Program Files\PuTTY\`)
4. **Run**:

```cmd
pscp -i C:\path\to\your-key.ppk ^
  C:\Users\YourUsername\Downloads\AuthKey_F3WU9KJ42M.p8 ^
  ec2-user@13.233.138.87:~/.appstoreconnect/private_keys/
```

**Note**: PuTTY uses `.ppk` format. If you have `.pem`, convert it:
- Use PuTTYgen to convert `.pem` to `.ppk`

---

## Method 4: Using WinSCP (GUI - Easiest)

1. **Download WinSCP**: https://winscp.net/
2. **Install and open WinSCP**
3. **Connect to EC2**:
   - **Host name**: `13.233.138.87`
   - **User name**: `ec2-user`
   - **Private key file**: Select your `.pem` or `.ppk` file
   - Click "Login"
4. **Navigate to**: `/Users/ec2-user/.appstoreconnect/private_keys/`
5. **Drag and drop** `AuthKey_F3WU9KJ42M.p8` from Windows to that folder

---

## Method 5: Using FileZilla (SFTP)

1. **Download FileZilla**: https://filezilla-project.org/
2. **File → Site Manager → New Site**
3. **Configure**:
   - **Protocol**: SFTP
   - **Host**: `13.233.138.87`
   - **Logon Type**: Key file
   - **User**: `ec2-user`
   - **Key file**: Browse to your `.pem` file
4. **Connect**
5. **Navigate to**: `/Users/ec2-user/.appstoreconnect/private_keys/`
6. **Upload** `AuthKey_F3WU9KJ42M.p8`

---

## After Uploading

Once the file is uploaded, go back to your EC2 terminal and run:

```bash
cd /Users/ec2-user/Desktop/Almed/almed_ahu/android_app
./check_key_file.sh
./upload_to_testflight.sh
```

---

## Quick PowerShell Command (Copy-Paste Ready)

Replace `C:\path\to\your-key.pem` with your actual key path:

```powershell
scp -i C:\path\to\your-key.pem C:\Users\$env:USERNAME\Downloads\AuthKey_F3WU9KJ42M.p8 ec2-user@13.233.138.87:~/.appstoreconnect/private_keys/
```

