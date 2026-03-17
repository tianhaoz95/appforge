# GEMINI.md - MicroForge Context

## Project Overview
**MicroForge** is a "Vibe Coding" platform built with Flutter that enables users to "forge" functional micro-apps using natural language via Gemini AI. The project consists of two primary components:
- **Mobile App (`/app`):** The core chat interface for forging and interacting with micro-apps.
- **Admin Portal (`/portal`):** A landing page and management interface for configuring AI models and subscriptions.

The project leverages the **Flutter AI Toolkit** for a high-fidelity chat interface and a **Firebase-backed architecture** for persistence and intelligence.

### Key Technologies
- **Frontend:** Flutter (Dart)
- **AI/LLM:** 
  - **Firebase AI Logic (Gemini API):** Primary model is `gemini-3.1-flash-lite-preview`.
  - **Fallback System:** Automatically switches to `gemini-2.0-flash` if the primary model is overloaded (503 errors).
  - **Hybrid Inference:** Supports on-device model status checks via a custom `MethodChannel`.
- **Runtime Environment:** `webview_flutter` executing **Alpine.js** and **Tailwind CSS** (via CDN) for instant, no-build micro-app rendering.
- **Backend:** Cloud Firestore for storing `conversations` and `micro_apps`.
- **State Management:** `provider` package.

### Architecture
- **Repositories:** `MicroAppRepository` handles Firestore interactions for saving and retrieving forged apps.
- **Providers:** `FallbackLlmProvider` manages the logic for switching between primary and secondary AI models. `HybridInferenceManager` handles on-device AI capabilities.
- **Widgets (App):** 
  - `VibeDetector`: Intercepts AI responses to identify code wrapped in `<forge>...</forge>` tags.
  - `PreviewSheet`: A sliding sheet containing a WebView to render and interact with forged apps.
  - `AppVaultDrawer`: Side drawer for accessing history and the gallery of forged apps.
- **Portal:** 
  - **Landing Page:** Public-facing site for the MicroForge project.
  - **Admin Interface:** Allows users to choose the AI backbone model and subscribe to paid AI quota and other settings.

---

## Building and Running
To get started with development or to run the project:

### Mobile App
- **Fetch Dependencies:**
  ```bash
  cd app && flutter pub get
  ```
- **Run the App:**
  ```bash
  cd app && flutter run
  ```
- **Run Tests:**
  ```bash
  cd app && flutter test
  ```

### Admin Portal
- **Fetch Dependencies:**
  ```bash
  cd portal && flutter pub get
  ```
- **Run the Portal:**
  ```bash
  cd portal && flutter run -d chrome
  ```

---

## Deployment to Firebase App Distribution
Follow these steps to deploy a new Android build to Firebase App Distribution:

1. **Boost Version:** Before building, increase the version name and build number in `app/pubspec.yaml` (e.g., `1.1.2+5` becomes `1.1.3+6`).
2. **Build APK:**
   ```bash
   cd app && flutter build apk
   ```
3. **Distribute:**
   Use the Android App ID (from `app/lib/firebase_options.dart`) and run from the project root:
   ```bash
   firebase appdistribution:distribute app/build/app/outputs/flutter-apk/app-release.apk \
        --app 1:146390824855:android:34ecddc19ce2738da436d2 \
        --release-notes "Detailed description of the current feature or improvement" \
        --groups "dev"
   ```
   *Note: Always replace the release notes with a clear, specific description of the changes being released.*

---

## Development Conventions
- **App ID / Package Name:** `com.hejitech.appforge`
- **AI Response Format:** AI is instructed via a system prompt to wrap micro-app code (HTML/Alpine.js/Tailwind) inside `<forge>...</forge>` tags.
- **Interoperability:** The micro-apps can communicate back to the Flutter layer using a `window.MicroForge` JavaScript bridge (e.g., `saveData`, `closeApp`).
- **Error Handling:** Use the `FallbackLlmProvider` to gracefully handle transient AI model failures.
- **On-Device AI:** Check model status before attempting on-device operations.
- **Firebase Configuration:** Firebase is initialized in `app/lib/main.dart` using `DefaultFirebaseOptions` from `app/lib/firebase_options.dart`.

---

## Key Files
- `app/lib/main.dart`: Entry point for the mobile app UI scaffold.
- `portal/lib/main.dart`: Entry point for the landing page and admin portal.
- `app/lib/providers/fallback_llm_provider.dart`: Multi-model fallback logic.
- `app/lib/providers/hybrid_inference_manager.dart`: Interface for on-device AI.
- `app/lib/repositories/micro_app_repository.dart`: Firestore data layer.
- `app/lib/widgets/vibe_detector.dart`: AI response parsing and deployment trigger.
- `app/lib/widgets/preview_sheet.dart`: WebView-based app runner.
- `app/android/app/build.gradle.kts`: Android configuration and App ID.
- `app/ios/Runner.xcodeproj/project.pbxproj`: iOS configuration and Bundle ID.
