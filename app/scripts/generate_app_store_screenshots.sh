#!/bin/bash

# Exit on any error
set -e

# Change to app directory
cd "$(dirname "$0")/.."

# Function to run screenshots for a specific device
run_screenshots() {
  local device_id=$1
  local output_dir=$2
  
  echo "------------------------------------------------------------"
  echo "📸 Capturing screenshots for device: $device_id"
  echo "📂 Output directory: $output_dir"
  echo "------------------------------------------------------------"
  
  mkdir -p "$output_dir"
  
  # Run flutter drive with the SCREENSHOTS_DIR environment variable
  # Note: Ensure test_driver/screenshot_driver.dart supports this env var
  SCREENSHOTS_DIR="$output_dir" flutter drive 
    --driver=test_driver/screenshot_driver.dart 
    --target=integration_test/screenshot_test.dart 
    -d "$device_id" 
    --no-pub # Skip pub get for faster execution
}

# Main execution
echo "🚀 App Store Screenshot Generator"

# If no arguments are provided, show usage and available devices
if [ $# -eq 0 ]; then
  echo ""
  echo "Usage: ./scripts/generate_app_store_screenshots.sh <DEVICE_ID_1> [DEVICE_ID_2] ..."
  echo ""
  echo "Suggested App Store Device Sizes:"
  echo "  - 6.5" iPhone: 'iPhone 15 Pro Max' or 'iPhone 14 Pro Max'"
  echo "  - 5.5" iPhone: 'iPhone 8 Plus'"
  echo "  - 12.9" iPad:  'iPad Pro (12.9-inch)'"
  echo ""
  echo "Current available devices:"
  flutter devices
  exit 0
fi

# Iterate through provided device IDs
for device in "$@"; do
  # Sanitize device name for directory
  DIR_NAME=$(echo "$device" | tr ' ' '_' | tr -d '()')
  run_screenshots "$device" "screenshots/ios/$DIR_NAME"
done

echo ""
echo "✅ Screenshot generation complete!"
echo "📍 Screenshots are located in app/screenshots/ios/"
ls -R screenshots/ios/
