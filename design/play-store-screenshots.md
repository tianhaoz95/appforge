# Play Store Screenshot Generation Solutions

Generating high-quality screenshots for the Play Store (and App Store) is a critical part of the release process. For MicroForge, we need a solution that can capture the chat interface, the "forge" process, and the resulting micro-apps.

## Potential Solutions

### 1. Flutter Integration Test + `integration_test` Package (Recommended)
This is the most "Flutter-native" approach. It uses the `integration_test` package to run the app on a device or emulator and captures screenshots using the `binding.takeScreenshot()` method.

**Pros:**
*   Uses existing testing infrastructure.
*   Full control over app state (e.g., using `MockLlmProvider` to simulate specific outputs).
*   Can be automated as part of CI/CD.

**Cons:**
*   Requires writing Dart code for navigation.
*   Doesn't automatically handle device frames (though this can be added).

### 2. Fastlane + Screengrab
Fastlane is the industry standard for mobile app automation. `screengrab` is its Android-specific tool for capturing screenshots.

**Pros:**
*   Standard tool for Play Store automation.
*   Handles multiple locales and device sizes well.
*   Integrates with the rest of the Fastlane suite (metadata, deployment).

**Cons:**
*   Requires Ruby environment.
*   Setup can be complex for Flutter-specific logic.

### 3. Third-Party Packages (e.g., `screenshot` package)
There are several packages on pub.dev designed to simplify screenshot capturing.

**Pros:**
*   Often provide simpler APIs than raw `integration_test`.
*   Some include device frame wrapping.

**Cons:**
*   Adds external dependencies.
*   May not always keep up with Flutter's internal changes.

---

## Proposed Implementation Plan

We have implemented **Solution 1** using a dedicated integration test.

### Step 1: Created a Screenshot Test
We've created `app/integration_test/screenshot_test.dart` that:
1.  Navigates through key screens:
    *   Main Chat Screen (empty state).
    *   Chat Screen with a prompt.
    *   Chat Screen with a generated app (displaying `<forge>` tags).
    *   The "Forge" Preview Sheet (WebView).
    *   The App Vault (History).
2.  Uses `binding.takeScreenshot()` at each step.

### Step 2: Created a Driver Script
We've created `app/test_driver/screenshot_driver.dart` that:
1.  Handles the `onScreenshot` callback from the integration test.
2.  Saves the received bytes to the `app/screenshots/` directory as PNG files.

### Step 3: Created a Shell Script Wrapper
The script `app/scripts/generate_screenshots.sh` will:
1.  Verify that a device or emulator is connected.
2.  Run `flutter drive` with the integration test and driver.
3.  Automatically save the screenshots to `app/screenshots/`.

## Usage Instructions

To generate screenshots:
1.  Ensure an Android emulator or iOS simulator is running.
2.  Execute the script from the project root:
    ```bash
    ./app/scripts/generate_screenshots.sh
    ```

The generated files will be available in `app/screenshots/`.

### Screens Captured:
- `1_home_empty.png`
- `2_home_prompt.png`
- `3_home_generated.png`
- `4_forge_preview.png`
- `5_app_vault.png`

### Enhancement (Optional)
In the future, we can add a post-processing step to wrap the raw screenshots in high-quality device frames using a tool like `frameit` (Fastlane) or a custom Dart script using the `image` package.
