#!/bin/bash
set -euo pipefail

DEVICE_NAME="${1:-iPhone 17 Pro Max}"
DEST="${HOME}/Documents/iphone ss"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$DEST"
export SCREENSHOT_DIR="$DEST"

cd "$APP_DIR"
flutter pub get

echo "Resetting app on simulator for a clean login..."
xcrun simctl uninstall "$DEVICE_NAME" com.almed.ahu >/dev/null 2>&1 || true

echo "Running screenshot integration test on $DEVICE_NAME..."
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "$DEVICE_NAME"

echo "Saved screenshots:"
ls -la "$DEST"
