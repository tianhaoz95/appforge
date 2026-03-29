# MicroForge UI Improvements Report

This report outlines 10 strategic UI improvements for the MicroForge platform to enhance user experience, visual appeal, and functional clarity.

## 1. "Forging" Animation for App Previews
**Description:** Add a "shimmer" or "energy pulse" animation around the `MiniAppPreview` in `VibeDetector` when an app is first detected or being updated.
**Tasks:**
- [ ] Create a custom painter for an "energy border" effect.
- [ ] Integrate `AnimationController` to drive the pulse effect.
- [ ] Apply the animation to the `VibeDetector` widget.

## 2. Enhanced Console Logging in PreviewSheet
**Description:** Improve the "Console" tab in `PreviewSheet` with better syntax highlighting for logs and colored labels for different log levels (Info, Warning, Error).
**Tasks:**
- [ ] Implement a custom log viewer with `RichText`.
- [ ] Add filters for log levels.
- [ ] Improve scroll-to-bottom behavior for real-time logs.

## 3. Visual App Cards in AppVault
**Description:** Transform the `AppVaultDrawer` list tiles into more visual "App Cards" that show a placeholder screenshot or a generated icon based on the app's category.
**Tasks:**
- [ ] Design a card-based layout for micro-apps in the drawer.
- [ ] Add a "screenshot" field to the `MicroApp` model and repository.
- [ ] Implement a fallback to category-specific icons (e.g., a calculator icon for math apps).

## 4. Modern Dashboard Layout for Portal
**Description:** Refresh the `DashboardScreen` in the portal with better spacing, subtle shadows, and a more responsive layout for the navigation rail.
**Tasks:**
- [ ] Increase padding and use `Card` widgets with elevation for content blocks.
- [ ] Add smooth transitions between dashboard tabs.
- [ ] Improve the "Model Selection" UI with more descriptive cards.

## 5. Unified "MicroForge" Branding
**Description:** Ensure consistent use of the brand's primary colors, custom fonts, and logo treatment across both the mobile app and the portal.
**Tasks:**
- [ ] Define a central `ThemeData` extension for brand-specific styles.
- [ ] Audit all screens to ensure they use the brand's color palette (e.g., specific orange/blue accents).
- [ ] Standardize logo placement and sizing.

## 6. Interactive "Blueprint" Mode
**Description:** Add a toggle in `PreviewSheet` to show a "Blueprint" overlay that displays the design document and architecture notes directly over the app preview.
**Tasks:**
- [ ] Create an overlay widget that renders markdown with a semi-transparent background.
- [ ] Add a "Blueprint" icon to the `PreviewSheet` header.
- [ ] Link the overlay to the `designDoc` data.

## 7. Categorized Settings Screen
**Description:** Reorganize the `SettingsScreen` in the mobile app into logical sections (Account, AI Model, Appearance, System) with clearer icons and better layout.
**Tasks:**
- [ ] Use `SliverList` or grouped `ListTile`s for settings.
- [ ] Add visual dividers and section headers.
- [ ] Implement a "Usage" section with a progress bar for AI quota.

## 8. Haptic Feedback Integration
**Description:** Add subtle haptic feedback to key interactions to make the app feel more responsive and "alive".
**Tasks:**
- [ ] Add `HapticFeedback.mediumImpact()` when an app is forged.
- [ ] Add `HapticFeedback.selectionClick()` when switching tabs in `PreviewSheet`.
- [ ] Add `HapticFeedback.lightImpact()` on button presses.

## 9. Accessibility Audit & Fixes
**Description:** Improve the accessibility of both platforms by ensuring proper `Semantics` tags, high-contrast text, and screen reader support.
**Tasks:**
- [ ] Wrap key interactive elements in `Semantics` with descriptive labels.
- [ ] Ensure all text meets WCAG AA contrast guidelines.
- [ ] Add "skip to content" links for web/portal.

## 10. Branded Error States
**Description:** Replace generic error messages with branded, illustrative error pages or dialogs (e.g., a "Gemini is resting" illustration for 503 errors).
**Tasks:**
- [ ] Design 2-3 custom error illustrations.
- [ ] Create an `ErrorScaffold` widget for common failure states.
- [ ] Update `FallbackLlmProvider` to trigger these branded error views.
