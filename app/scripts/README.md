# AppForge Scripts

## Screenshot Generation

To generate screenshots for the Play Store/App Store listing:

1.  **Start an emulator or connect a device.**
    *   For Android, a high-resolution emulator (e.g., Pixel 7 Pro) is recommended.
    *   For iOS, use a Simulator (e.g., iPhone 15 Pro Max).
2.  **Run the script:**
    ```bash
    ./app/scripts/generate_screenshots.sh
    ```

The script will run an integration test (`app/integration_test/screenshot_test.dart`) that navigates through key features of the app and captures screenshots.

The generated screenshots will be saved in `app/screenshots/`.

### Screens Captured:
1.  `1_home_empty.png`: Initial chat screen.
2.  `2_home_prompt.png`: Chat screen with a user prompt.
3.  `3_home_generated.png`: Chat screen with AI response and "Deploy" button.
4.  `4_forge_preview.png`: The "Forge" WebView preview of a micro-app.
5.  `5_app_vault.png`: The App Vault history drawer.
