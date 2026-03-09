## **Product Design Document: AppForge**

**Project Name:** AppForge

**Author:** AI Collaborator

**Date:** March 2026

**Stack:** Flutter, Firebase AI Logic (Gemini Developer API), Alpine.js, Tailwind CSS.

---

## **1. Executive Summary**

**AppForge** is a "Vibe Coding" platform that turns natural language into functional, persistent micro-apps. By combining the **Flutter AI Toolkit** for high-fidelity chat with a **Firebase-backed cloud architecture**, users can "forge" utilities (calculators, dashboards, interactive forms) that are instantly rendered via **Alpine.js** and saved to a cross-device **App Vault**.

---

## **2. System Architecture**

### **A. Intelligence & Persistence (The Cloud)**

* **Inference:** Uses **Firebase AI Logic** (Gemini 3.1 Flash Lite Preview) via the **Gemini Developer API**. This provides high-speed, cost-effective "vibe" generation protected by **Firebase App Check**.
* **Database:** **Cloud Firestore** manages three primary collections:
* `conversations`: Multi-turn history for the AI Toolkit.
* `micro_apps`: Metadata, versioned Alpine.js/HTML blobs, and owner IDs.
* `user_profiles`: Preferences and pinned apps.



### **B. Runtime Layer (The Execution)**

* **Host:** `webview_flutter` running an **unrestricted JavaScript** environment.
* **UI Framework:** **Alpine.js** (loaded via CDN) for no-build reactivity.
* **Styling:** **Tailwind CSS** (Play CDN) to allow the LLM to style components using standard classes.

---

## **3. Detailed UI Design**

### **A. Main Screen: The Forge Interface**

The UI follows a classic "Productivity IDE" layout built entirely in Flutter.

* **App Bar:**
* **New Chat (Icon):** Resets the `LlmProvider` to start a fresh forging session.
* **Live Preview (Rocket Icon):** Slides up a `DraggableScrollableSheet` containing the WebView. This allows users to keep the chat open while interacting with the forged app.


* **Left Sidebar (The Vault):**
* **Recent Chats:** Chronological list of AI interactions.
* **Forged Apps:** A tile-based gallery of saved micro-apps. Tapping a tile injects that specific code blob into the WebView.


* **Center Stage (Chat):**
* Powered by `LlmChatView`.
* **Custom Interceptor:** When the AI streams code wrapped in `<forge>...</forge>` tags, the UI displays a **"Deploy to App Bar"** button in the message bubble.



---

## **4. Data Schema & Integration**

### **Firestore Schema: `micro_apps**`

```json
{
  "appId": "uuid_123",
  "name": "NPU Hardware Monitor",
  "ownerId": "firebase_user_abc",
  "version": 1.2,
  "html_blob": "",
  "created_at": "2026-03-08T17:10:00Z",
  "icon": "speed"
}

```

### **The Forge Bridge (Flutter to Alpine)**

AppForge uses a global JS object to allow the micro-app to talk back to the Firebase/Flutter layer.

```javascript
window.AppForge = {
  saveData: (key, val) => { /* Calls Flutter channel to update Firestore */ },
  closeApp: () => { /* Tells Flutter to hide the WebView sheet */ }
};

```

---

## **5. Technical Implementation: Step-by-Step**

### **Step 1: The Flutter Scaffold**

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('AppForge'),
    actions: [
      IconButton(icon: const Icon(Icons.add), onPressed: _createNewForge),
      IconButton(icon: const Icon(Icons.rocket_launch), onPressed: _togglePreview),
    ],
  ),
  drawer: AppVaultDrawer(), // Sidebar for history and saved apps
  body: LlmChatView(
    provider: FirebaseProvider(
      model: FirebaseAI.instance.generativeModel(model: 'gemini-3.1-flash'),
    ),
    // Custom widget to detect and "forge" the Alpine code
    responseBuilder: (context, message) => VibeDetector(message: message),
  ),
);

```

### **Step 2: The Alpine Injection**

When a "vibe" is deployed, the WebView loads a standard shell:

```html
<script src="https://cdn.tailwindcss.com"></script>
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
<div id="forge-target">
  </div>

```

---

## **6. Key Benefits of AppForge**

1. **Instant Deployment:** No `npm install`, no `flutter build`. Code runs the second the LLM finishes typing.
2. **Persistent Utility:** Tools built in the chat aren't ephemeral; they are saved to the Vault for long-term use.
3. **Low Overhead:** By using Alpine.js instead of React, the "forged" apps consume minimal memory on the device.
