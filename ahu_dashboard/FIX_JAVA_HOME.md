# Fix JDK 17 Requirement for Gradle Language Server

## Problem
Error: "JDK 17 or higher is required. Please set a valid Java home path to 'java.jdt.ls.java.home' setting or JAVA_HOME environment variable."

## Solution Applied ✅

### Java Location Found
Java 21 is installed with Android Studio at:
- **Path:** `C:\Program Files\Android\Android Studio\jbr`
- **Version:** OpenJDK 21 (build 21.0.8+)

### Configuration Updates

**1. Cursor/VS Code Settings** (`.vscode/settings.json`)
```json
{
    "java.jdt.ls.java.home": "C:\\Program Files\\Android\\Android Studio\\jbr",
    "java.home": "C:\\Program Files\\Android\\Android Studio\\jbr"
}
```

**2. System Environment Variable**
- **JAVA_HOME** set to: `C:\Program Files\Android\Android Studio\jbr`
- Set permanently for your user account

## What Was Done

1. ✅ Found Java installation (Android Studio's bundled JDK)
2. ✅ Configured Cursor settings for Gradle Language Server
3. ✅ Set JAVA_HOME environment variable permanently

## Restart Required

**Restart Cursor/VS Code** for the Java configuration to take effect:
1. Close Cursor completely
2. Reopen Cursor
3. The error should disappear

## Verification

After restarting Cursor:
1. Open any Gradle file (e.g., `android/app/build.gradle`)
2. The Gradle Language Server should start without errors
3. Java syntax highlighting and IntelliSense should work

## Alternative: If Error Persists

If the error still appears after restarting:

1. **Check Java version:**
   ```powershell
   &"C:\Program Files\Android\Android Studio\jbr\bin\java.exe" -version
   ```
   Should show: `openjdk version "21.x.x"`

2. **Verify JAVA_HOME:**
   ```powershell
   echo $env:JAVA_HOME
   ```
   Should show: `C:\Program Files\Android\Android Studio\jbr`

3. **Manual Cursor settings:**
   - Press `Ctrl+Shift+P`
   - Type: "Preferences: Open Settings (JSON)"
   - Verify the Java paths are correct

---

**The configuration is complete!** Just restart Cursor to apply the changes.


