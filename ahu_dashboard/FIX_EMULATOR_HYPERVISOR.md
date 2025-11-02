# Fix Android Emulator Hypervisor Driver Error

## Problem
The Android Emulator hypervisor driver failed to install with error `4294967201`.

## What This Means
- The emulator will still work, but may be slower
- You'll get better performance if this is fixed
- This is a common Windows issue with virtualization

## Solutions

### Option 1: Use Windows Hyper-V (Windows 11 Recommended)

**If you're on Windows 11:**
1. Open **Windows Features**:
   - Press `Win + R`
   - Type: `optionalfeatures` and press Enter
   
2. **Enable these:**
   - ✅ Windows Hypervisor Platform
   - ✅ Virtual Machine Platform
   - ✅ Windows Subsystem for Linux (optional, if you use WSL)
   
3. **Click OK** and **restart** your computer

4. **After restart**, the emulator will use Hyper-V instead of the hypervisor driver

### Option 2: Disable Hyper-V and Use Hypervisor Driver

**If you want to use the Android Emulator hypervisor driver instead:**

1. **Disable Hyper-V:**
   ```powershell
   # Run PowerShell as Administrator
   Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
   ```

2. **Restart** your computer

3. **Install hypervisor driver again:**
   - Go to: Android Studio → Tools → SDK Manager
   - SDK Tools tab
   - Check "Android Emulator Hypervisor Driver for AMD Processors" (AMD) or install Intel HAXM (Intel)
   - Click Apply

### Option 3: Run Emulator Without Hypervisor (Works but Slower)

The emulator will work without the hypervisor driver, just slower:

```powershell
# Just start emulator normally
flutter emulators --launch Medium_Phone_API_36.1
flutter run
```

It will use software acceleration instead of hardware acceleration.

### Option 4: Use Android Studio's Built-in Emulator

1. **Open Android Studio**
2. **Tools → Device Manager**
3. **Click Play** on your emulator
4. **Close Android Studio** (emulator stays running)
5. **Run from Cursor:**
   ```powershell
   cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"
   flutter run
   ```

## Recommended Solution for Windows 11

**Enable Hyper-V Platform** (Option 1):
1. Press `Win + R`
2. Type: `optionalfeatures`
3. Check: ✅ **Windows Hypervisor Platform**
4. Check: ✅ **Virtual Machine Platform**
5. Click OK → Restart
6. After restart, emulator will work faster with Hyper-V

## Quick Test

After fixing, test the emulator:

```powershell
cd "e:\dev files\New folder\almed_ahu\ahu_dashboard"

# Start emulator
flutter emulators --launch Medium_Phone_API_36.1

# Wait for boot, then:
flutter run
```

## Troubleshooting

### Still Getting Errors?

1. **Restart computer** after enabling Hyper-V
2. **Check BIOS settings:**
   - Enable Virtualization (VT-x or AMD-V)
   - Enable Virtualization-based Security
3. **Run as Administrator:**
   - Right-click PowerShell → Run as Administrator
   - Try installing hypervisor driver again

### Performance Still Poor?

- **Increase emulator RAM:**
  - Android Studio → Device Manager
  - Edit your AVD
  - Change RAM allocation (2048 MB minimum)
  
- **Use x86_64 system image** (faster than ARM)
- **Enable hardware acceleration** in AVD settings

## What I Recommend

**For Windows 11:** Enable Windows Hypervisor Platform (Option 1) - it's the modern way and works better.

**For Windows 10:** If you have AMD processor, use Hyper-V. If Intel, you can try Intel HAXM but Hyper-V is usually better.

---

**Bottom line:** The emulator will work even with this error, just enable Hyper-V for better performance!

