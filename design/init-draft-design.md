## **Product Design Document: AppForge**

**Version:** 1.0 (March 2026)

**Status:** Initial Draft

**Core Stack:** Flutter (3.4x), Firebase (Vertex AI + Firestore), Alpine.js, Snowglobe (Rust-based Edge Inference).

---

## **1. Executive Summary**

**AppForge** is a dual-purpose development and productivity platform that enables "Vibe Coding." It combines a native **Flutter** conversational interface with a lightweight **Alpine.js** micro-app runtime. Users can describe a utility or tool in natural language, and AppForge generates, stores, and executes that tool as a persistent micro-app within the same interface.

---

## **2. Design Philosophy**

* **Zero-Build Reactivity:** Use Alpine.js to eliminate the need for JS compilation, ensuring that LLM-generated UIs are functional within milliseconds of streaming.
* **Conversational Logic:** The primary interaction is a chat. The AI is not just a responder but a "Forge" that hammers out functional UI.
* **Edge-First Performance:** Leveraging the user's **Snowglobe** engine for local inference while using Firebase for cross-device synchronization and cloud-fallback.

---

## **3. Architecture & Tech Stack**

### **A. Frontend (Flutter)**

* **Framework:** Flutter 3.41+ with **Impeller** rendering for 120 FPS fluid interactions.
* **UI Toolkit:** **Flutter AI Toolkit** (`LlmChatView`) for the core conversation interface.
* **State Management:** **Riverpod** for handling asynchronous streams from both Firebase and the local Snowglobe Rust core.
* **Native Bridge:** `flutter_rust_bridge` to connect the UI to high-performance inference logic.

### **B. Backend (Firebase)**

* **AI Engine:** **Firebase Vertex AI Logic** using `gemini-3.1-flash` for rapid UI generation.
* **Database:** **Cloud Firestore** for storing chat threads and the `HTML/JS` blobs of forged micro-apps.
* **Security:** **Firebase App Check** to protect the API endpoints from unauthorized inference calls.

### **C. The Vibe Runtime (Alpine.js)**

* **Engine:** `webview_flutter` or `flutter_inappwebview`.
* **Bridge:** Two-way communication using `JavascriptChannels` to allow Alpine.js micro-apps to call Flutter/Rust functions (e.g., `window.AppForge.runInference()`).

---

## **4. Detailed UI/UX Specification**

### **The Main Screen (The Forge)**

A three-pane design optimized for productivity.

| Component | Description |
| --- | --- |
| **Left Sidebar (Drawer)** | **Chat History:** List of active and archived sessions. <br>

<br> **App Vault:** A grid of cards showing icons for "Forged" apps (e.g., *Property Tax Calc*, *NPU Visualizer*). |
| **Center Panel (Chat)** | Built with `LlmChatView`. Streams the conversation. If a code block containing `x-data` (Alpine) is detected, a **"Launch App"** button appears over the message. |
| **App Bar** | **New Chat:** Resets the LLM provider state. <br>

<br> **Preview Toggle:** A rocket icon that slides up the WebView to overlay the current forged app. |

---

## **5. Feature Modules**

### **I. The Conversational Forge**

* **Function:** The user provides a prompt (e.g., *"Make a dashboard for my OnePlus Open hardware stats"*).
* **AI Output:** The LLM returns a specialized JSON object containing the Alpine.js HTML.
* **Processing:** Flutter extracts the code, saves it to a local `shelf` server directory, and updates the App Bar "Preview" button.

### **II. Hardware Grounding (Snowglobe Integration)**

* AppForge exposes a `window.Snowglobe` object to the Alpine environment.
* **Example Choice:** Micro-apps can call `Snowglobe.getNpuUsage()` to get real-time metrics from the local Snapdragon chip, bypassing the cloud for privacy and speed.

---

## **6. Visual Design Choices**

* **Primary Palette:** "Glacier White" (#F0F8FF) and "Obsidian" (#0B0E14) with "NPU Cyan" (#00E5FF) accents.
* **Typography:** **JetBrains Mono** for code fragments; **Inter** for the conversation.
* **Glassmorphism:** The WebView uses a slightly blurred `BackdropFilter` so the forged apps feel integrated into the Flutter environment.

---

## **7. Roadmap**

1. **Phase 1:** Basic Chat integration with Firebase Vertex AI.
2. **Phase 2:** Alpine.js injection via local `shelf` server.
3. **Phase 3:** Persistent "App Vault" in Firestore for saving generated UIs.
4. **Phase 4:** Full Snowglobe/Rust hardware bridge for edge-native micro-apps.
