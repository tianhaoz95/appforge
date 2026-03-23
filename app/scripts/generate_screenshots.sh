#!/bin/bash

# Exit on any error
set -e

# Change to app directory
cd "$(dirname "$0")/.."

# Check if an emulator or device is connected
if ! flutter devices | grep -q "•"; then
  echo "Error: No devices found. Please launch an emulator or connect a device."
  exit 1
fi

# Create screenshots directory
mkdir -p screenshots

echo "🚀 Starting screenshot generation..."

# Set a default screenshots directory if not provided
export SCREENSHOTS_DIR=${SCREENSHOTS_DIR:-"screenshots/general"}
mkdir -p "$SCREENSHOTS_DIR"

# Run the integration test with the screenshot driver
flutter drive \
  --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/screenshot_test.dart

echo "✅ Screenshots generated in app/$SCREENSHOTS_DIR/"
ls -lh "$SCREENSHOTS_DIR"
