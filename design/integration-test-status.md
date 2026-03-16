# Integration Test Status Report: Todo App & Migration

## 1. Test Overview
**File**: `integration_test/todo_app_test.dart`  
**Purpose**: To verify the end-to-end flow of creating a micro-app, persisting data, enhancing it to a new version, and successfully migrating data between isolated versions.

## 2. Mocking Strategy
The test aims for **High Fidelity**, using real database instances rather than mocks where possible.

| Component | Status | Reasoning |
|-----------|--------|-----------|
| **SQLite (sqflite)** | **REAL** | Uses a real local database file to verify schema migrations and isolation. |
| **JS Runtime (flutter_js)** | **REAL** | Uses the actual QuickJS engine to execute migration scripts. |
| **WebView (webview_flutter)** | **SKIPPED** | `PreviewSheet.skipWebViewForTesting` is used to avoid the complexity of rendering a headless WebView in a CI/CD-like environment, focusing on the logic bridge instead. |
| **Firebase** | **STUBBED** | `Firebase.initializeApp` is called with default options to satisfy dependency requirements, but no live network calls are made. |
| **AI (LlmProvider)** | **OMITTED** | The test uses **hardcoded JS blobs** for the apps and migration scripts to ensure predictability and avoid non-deterministic AI responses. |

## 3. Tested Execution Path
The test follows a "Linear Evolution" path:

1.  **Seed Phase**:
    - Programmatically save "Todo App v1.0.0" to the repository.
    - Manually inject `v1` data (`todos: [{text, done}]`) into the `micro_app_data` table scoped to `appId_v1`.
2.  **Forge Phase**:
    - Programmatically save "Todo App v1.1.0" with `parentAppId` pointing to `v1`.
3.  **Migration Phase (The Bridge)**:
    - Initialize `PreviewSheet` with the new version and a transformation script.
    - Trigger `_runMigration` in Dart.
    - **JS Action**: Fetch `oldData` from Dart via bridge.
    - **JS Action**: Map `todos` (v1) to `items` (v2).
    - **JS Action**: Call `saveData` to write to `appId_v2`.
4.  **Verification Phase**:
    - Query SQLite for `appId_v2` to ensure `items` key exists and contains transformed data.
    - Query SQLite for `appId_v1` to ensure original data is untouched (Isolation check).
    - UI check: Verify the "Database" tab and "Lineage" sheet are visible and contain correct keys.

## 4. Current Blockers & Challenges
The latest runs identified a synchronization bottleneck in the **QuickJS Bridge**:

- **Signal Timing**: The transition from Dart evaluation to JS async execution sometimes causes the `completer` to timeout before the JS `finally` block can signal back.
- **Data Serialization**: Passing large JSON objects across the `flutter_js` message channel sometimes results in type mismatches (Map vs. String) depending on the platform's native implementation of the bridge.
- **Warmup Latency**: QuickJS requires a non-trivial amount of time to initialize its internal state before it can reliably handle `sendMessage` calls.

## 5. Next Steps for Stabilization
- **Polling Fallback**: Implement a Dart-side check that periodically queries the database for migration results if the signal hasn't arrived.
- **Handshake Optimization**: Refactor the initial data injection to happen via a dedicated initialization call rather than string interpolation.
