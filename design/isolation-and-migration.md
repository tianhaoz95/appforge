# Design Document: Immutable Versioning & Data Migration

## Overview
MicroForge is transitioning from an "In-Place Update" model to an **"Immutable Versioning with Read-Only Migrations"** model. This architecture ensures that every time a micro-app is "forged" or "enhanced," it operates on a completely fresh and isolated data bucket, while providing a safe, AI-driven mechanism to transition state from previous versions.

## 1. Core Concepts

### 1.1 Immutable Versions
- **Legacy Model**: 1 App = 1 `appId`. Updates modified the same storage bucket.
- **New Model**: 1 Forge Event = 1 unique `appId`. 
- Every enhancement generates a statistically unique deployment ID (UUID v4).
- This provides "Data Time Travel": switching to an older version of an app shows exactly the state that version had when it was last used.

### 1.2 Data Isolation
- Data is stored in the `micro_app_data` table.
- Primary Key: `(appId, key)`.
- Isolation is enforced at the repository level. A micro-app can only `saveData` or `getData` within its own `appId` scope.

### 1.3 Lineage Tracking
- The `micro_apps` table includes a `parentAppId` column.
- This creates a linked list (or tree) representing the evolution of the app.
- The platform uses this link to identify the "source of truth" for migrations.

---

## 2. Migration Architecture

### 2.1 The Migration Trigger
When a new version is deployed with a `parentAppId`, the platform enters a **Migration Phase** before the user can interact with the app.

### 2.2 Read-Only Sandbox
To prevent a new version from corrupting old data, the migration happens in a restricted environment:
1.  **Extraction**: The Flutter layer fetches all keys/values associated with the `parentAppId`.
2.  **Freezing**: This data is injected into a temporary JavaScript Runtime as a frozen object: `window.MicroForge.oldData`.
3.  **Restriction**: During this phase, the `saveData` API is routed to the **new** `appId` storage only. The `parentAppId` storage remains physically read-only.

### 2.3 AI-Generated Migration Scripts
Gemini is instructed to provide a `<migration>` block when enhancing an app.
Example:
```javascript
// Transform v1 schema {user_name} to v2 schema {profile: { name }}
const legacy = MicroForge.oldData['settings'];
if (legacy) {
  MicroForge.saveData('profile', { name: legacy.user_name });
}
```

---

## 3. Data Inspection UI

### 3.1 The Database Tab
A new tab in the `PreviewSheet` provides transparency into the "Black Box" of micro-app storage.
- **Live View**: Shows all keys currently stored for the active `appId`.
- **JSON Inspector**: Formatted view of complex objects.
- **Storage Stats**: Displays resource usage (key count, payload size).

### 3.2 Lineage Explorer
If a version was migrated, the UI allows the user to peek at the "Parent Data." This helps the user (and developers) debug migration failures or verify that the AI correctly transformed their history.

---

## 4. Implementation Details

### 4.1 Schema Update (LocalDatabase)
- Table: `micro_apps`
- New Column: `parentAppId TEXT`
- Migration Version: 12

### 4.2 Bridge Protocol (PreviewSheet)
The migration bridge requires a robust handshake to handle the asynchronous nature of QuickJS:
1. `MigrationStarting`: JS notifies Flutter it has begun.
2. `getOldData`: JS requests the parent data bucket.
3. `saveData`: JS writes transformed data to the new bucket.
4. `MigrationFinished`: JS notifies Flutter to dispose of the migration runtime and launch the main app.

---

## 5. Failure Recovery
- **Timeout**: If a migration script hangs, the platform defaults to an empty state for the new version and logs the failure.
- **Manual Retry**: Users can trigger a "Re-run Migration" from the Database tab.
- **Rollback**: Since the parent data is never touched, the user can simply switch back to the previous version in the version selector to recover their original state.
