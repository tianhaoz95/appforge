# MicroForge: Implementation Task Report

This report outlines the tasks and subtasks required to build **MicroForge**, a "Vibe Coding" platform, based on the `init-draft-design.md` specification.

---

## **Phase 1: Project Infrastructure & Cloud Setup**
**Objective:** Establish the foundation for the Flutter app and Firebase backend.

*   **Task 1.1: Initialize Flutter Workspace**
    *   [x] Create a new Flutter project (`flutter create appforge`).
    *   [x] Add dependencies: `firebase_core`, `cloud_firestore`, `firebase_auth`, `webview_flutter`, `flutter_ai_toolkit` (or equivalent `LlmChatView` provider).
*   **Task 1.2: Configure Firebase Services**
    *   [x] Set up Firebase Project in the Google Cloud Console.
    *   [x] Enable **Firebase Authentication** (Anonymous or Email/Google).
    *   [x] Enable **Cloud Firestore** and configure initial security rules.
    *   [x] Enable **Firebase App Check** to protect AI Inference endpoints.
*   **Task 1.3: Integrate AI Logic**
    *   [x] Configure **Firebase AI Logic** with `gemini-3.1-flash-lite-preview` via Gemini Developer API.
    *   [x] Implement `FallbackLlmProvider` to gracefully handle "High Demand" (503) errors by switching to `gemini-2.0-flash`.
    *   [x] Verify model connectivity and fallback logic.

---

## **Phase 2: Flutter Shell & UI Architecture**
**Objective:** Build the main "IDE" interface for chat and app management.

*   **Task 2.1: Main Scaffold Development**
    *   [x] Implement `AppBar` with "New Chat" and "Live Preview" actions.
    *   [x] Build the `AppVaultDrawer` (Left Sidebar) for history and saved apps.
*   **Task 2.2: AI Chat Integration**
    *   [x] Integrate `LlmChatView` with the `FirebaseProvider`.
    *   [x] Implement persistent conversation logic using the `conversations` collection.
*   **Task 2.3: The "Vibe" Detector**
    *   [x] Create a `VibeDetector` widget to intercept `<forge>` tags in AI responses.
    *   [x] Add a "Deploy to App Bar" button within the message bubble UI.

---

## **Phase 3: Runtime Execution & WebView Bridge**
**Objective:** Create the environment where micro-apps come to life.

*   **Task 3.1: WebView Implementation**
    *   [x] Configure `webview_flutter` with unrestricted JavaScript.
    *   [x] Implement `DraggableScrollableSheet` as the "Live Preview" container.
*   **Task 3.2: Alpine.js & Tailwind Shell**
    *   [x] Create a base HTML template that injects Alpine.js and Tailwind CSS via CDN.
    *   [x] Develop the logic to "hot-swap" the `<div id="forge-target">` content.
*   **Task 3.3: The Forge Bridge (JS <-> Dart)**
    *   [x] Implement `window.MicroForge.saveData` to call back to Flutter via `JavaScriptChannel`.
    *   [x] Implement `window.MicroForge.getLocation` to expose Flutter geolocation to micro-apps.
    *   [x] Implement `window.MicroForge.closeApp` to dismiss the preview sheet.

---

## **Phase 4: Persistence & The App Vault**
**Objective:** Ensure micro-apps are saved and accessible across sessions.

*   **Task 4.1: Data Layer Implementation**
    *   [x] Implement the `micro_apps` Firestore schema as specified.
    *   [x] Create repository logic for saving, updating, and fetching apps.
*   **Task 4.2: The Vault Gallery**
    *   [x] Build the tile-based gallery in the Drawer.
    *   [x] Implement "Tap to Load" logic to inject saved HTML blobs into the WebView.

---

## **Phase 5: Refinement & Testing**
**Objective:** Quality assurance and UX polish.

*   **Task 5.1: End-to-End "Forge" Testing**
    *   [x] Verify: Prompt -> Code Generation -> Detection -> Deployment -> Execution.
*   **Task 5.2: Security & App Check**
    *   [x] Harden Firestore rules and verify App Check is blocking unauthorized requests.
*   **Task 5.3: Performance Optimization**
    *   [x] Optimize WebView memory usage and script injection speed.
