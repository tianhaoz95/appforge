# appforge

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Screenshot Generation

MicroForge includes automated scripts to capture high-fidelity screenshots for App Store and Play Store publishing using Flutter's integration testing framework.

### Prerequisites

- A running emulator or connected device.
- For iOS screenshots, you must be on **macOS** with Xcode and simulators installed.

### Capturing Screenshots

1.  **General Screenshots:** Captures a standard set of screenshots in `app/screenshots/general/`.
    ```bash
    ./scripts/generate_screenshots.sh
    ```

2.  **App Store Screenshots (Multiple Sizes):** Captures and organizes screenshots for specific iOS device sizes required by Apple.
    ```bash
    # List available simulators to find names/IDs
    flutter devices

    # Run for required device sizes
    ./scripts/generate_app_store_screenshots.sh "iPhone 15 Pro Max" "iPhone 8 Plus"
    ```

### Detailed Documentation

For more information on required device sizes and how the automation works, see:
- [App Store Screenshot Guide](../design/app-store-screenshots.md)
- [Play Store Screenshot Guide](../design/play-store-screenshots.md)
