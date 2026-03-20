# App Store Screenshot Generation Solutions

For App Store publishing, Apple requires specific device sizes. MicroForge handles this by using Flutter's `integration_test` package to capture high-fidelity screenshots across different iOS simulators.

## Required Device Sizes

The App Store Connect requires at least:
- **iPhone 6.5"** (e.g., iPhone 15 Pro Max, iPhone 14 Pro Max)
- **iPhone 5.5"** (e.g., iPhone 8 Plus)
- **iPad 12.9"** (e.g., iPad Pro (12.9-inch))

## Automated Solution

We use a combination of:
1.  **Generic Screenshot Test:** `app/integration_test/screenshot_test.dart` captures 5 key screens.
2.  **Configurable Screenshot Driver:** `app/test_driver/screenshot_driver.dart` supports an environment variable for the output directory.
3.  **App Store Generation Script:** `app/scripts/generate_app_store_screenshots.sh` automates the process of running tests for multiple devices and organizing the output.

## Usage Instructions (on macOS)

1.  List your available simulators to find the IDs/names:
    ```bash
    flutter devices
    ```

2.  Run the generation script for the required device sizes:
    ```bash
    ./app/scripts/generate_app_store_screenshots.sh 
        "iPhone 15 Pro Max" 
        "iPhone 8 Plus" 
        "iPad Pro (12.9-inch) (6th generation)"
    ```

The script will automatically create:
- `app/screenshots/ios/iPhone_15_Pro_Max/`
- `app/screenshots/ios/iPhone_8_Plus/`
- `app/screenshots/ios/iPad_Pro_12.9-inch_6th_generation/`

Each directory will contain the 5 required screenshots:
- `1_home_empty.png`
- `2_home_prompt.png`
- `3_home_generated.png`
- `4_forge_preview.png`
- `5_app_vault.png`

## Tips for Better Screenshots
- Ensure `debugShowCheckedModeBanner: false` is set in `MaterialApp` (already handled in `app/lib/main.dart`).
- If you're using a physical device, make sure the status bar is clean (e.g., full battery, clear carrier). On simulators, this is usually handled automatically or can be configured via `xcrun simctl status_bar`.
