# Cleanup Guide - Free Up Storage Space

The Android build process can use a lot of storage. Here's how to clean up:

## Quick Cleanup (Run these commands)

```bash
cd android_app

# Clean Flutter build cache
flutter clean

# Clean Gradle cache (can free several GB)
cd android
./gradlew clean
cd ..

# Remove build folders
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\app\build -ErrorAction SilentlyContinue
```

## Deep Cleanup (More Space)

### 1. Clean Android SDK Cache
```powershell
# Clean Android SDK cache (can free 5-10GB)
Remove-Item -Recurse -Force $env:LOCALAPPDATA\Android\Sdk\.cache -ErrorAction SilentlyContinue
```

### 2. Clean Gradle Cache (Global)
```powershell
# Clean global Gradle cache (can free 2-5GB)
Remove-Item -Recurse -Force $env:USERPROFILE\.gradle\caches -ErrorAction SilentlyContinue
```

### 3. Clean Flutter Cache
```powershell
# Clean Flutter cache
flutter pub cache clean
```

### 4. Remove Unused Android SDK Components
Open Android Studio → Tools → SDK Manager → SDK Tools
- Uncheck unused NDK versions (keep only the latest)
- Uncheck unused build tools versions
- Uncheck unused platform versions (keep only what you need)

## Estimated Space Recovery

- Flutter clean: ~500MB - 1GB
- Gradle cache: ~2-5GB
- Android SDK cache: ~5-10GB
- Build folders: ~1-2GB

**Total: ~8-18GB can be recovered**

## After Cleanup

Rebuild will re-download only what's needed:
```bash
cd android_app
flutter pub get
flutter build apk --debug
```

## Prevent Future Issues

1. **Use build cache cleanup regularly**
2. **Remove unused Android SDK components**
3. **Consider using a smaller NDK version** (if not needed)
4. **Clean build folders after successful builds**

