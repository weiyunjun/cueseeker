# Scope and Milestones

Status: Draft

## 1. Scope Philosophy

The native rewrite should be built in small milestones.

Each milestone must produce a reviewable result. Features that are not required for the current milestone should not block the current milestone.

The provisional minimum supported system version is macOS 13.0 Ventura. This may be revised before implementation if core architecture decisions require a newer version.

## 2. M0: Governance and Baseline

Goal:

- Confirm project governance.
- Confirm product documentation structure.
- Initialize Git if needed.
- Freeze the existing Flutter implementation.
- Archive the Flutter implementation for reference.

Acceptance criteria:

- Project governance document is reviewed.
- Product documents exist under `docs/product/`.
- Git baseline exists.
- Existing Flutter code is preserved.
- Archived Flutter code is available for reference.

## 3. M1: Native macOS Minimal Loop

Goal:

- Create a native macOS application.
- Select one or more local subtitle folders.
- Scan `.srt` files.
- Parse subtitle entries.
- Match subtitle files to same-directory local video files.
- Write subtitle entries to SQLite + FTS5.
- Search subtitle text.
- Click a search result to open the matching local video at the matching timestamp.
- Provide an embedded playback experience inside the app window.
- Provide a usable native macOS shell with Search and Settings navigation.

Acceptance criteria:

- The app does not depend on Flutter.
- The app can run on the documented minimum supported macOS version.
- The app can index local `.srt` files.
- The app can search indexed subtitle content.
- The app can open a matching local video from a search result.
- The app can seek to the subtitle start timestamp.
- The matching video renders inside the native app window, not in an external player window.
- Clicking a search result enters a playback page for that result.
- Returning from the playback page stops playback.
- Clicking the embedded video toggles play/pause.
- Repeated selection within the same video should seek rather than reload the video when practical.
- Search and Settings are available through the native app shell.
- Remote playback and advanced visual effects are out of scope.

Current M1 status:

- The legacy Flutter implementation is archived under `archive/flutter/`.
- The active native macOS app lives under `apps/macos-native/`.
- Core subtitle scanning, parsing, same-directory video matching, SQLite persistence, FTS5 search, incremental reindexing, and basic settings are implemented.
- Embedded playback uses `libmpv` with the render API and an `NSOpenGLView` bridge.
- The app shell has moved to a custom native shell with AppKit titlebar controls and SwiftUI content.
- UI polish is still in progress. The current shell, search result presentation, and playback page are usable but not final M1 visual design.

## 4. M2: macOS Experience Polish

Goal:

- Improve native macOS behavior around windows, menus, keyboard shortcuts, file permissions, and core UI quality.

Expected areas:

- Native menu bar.
- Keyboard shortcut model.
- Window sizing and restoration.
- File access persistence.
- Error presentation.
- App settings.
- Packaging preparation.
- Signing and notarization preparation if needed.

Acceptance criteria:

- The core local workflow feels stable and native.
- Common keyboard interactions do not conflict with text input.
- Folder permissions remain available after app restart if required.
- User-facing errors are understandable.

## 5. M3: Favorites and Personal Learning Flow

Goal:

- Add a lightweight personal learning layer on top of the local search and playback workflow.

Expected areas:

- Favorite a subtitle line.
- View favorite lines.
- Remove favorites.
- Jump from a favorite to the matching video timestamp.
- Preserve favorite identity across reindexing when possible.

Acceptance criteria:

- Favorites persist locally.
- Favorites remain linked to source subtitle timing.
- Favorite actions are available through UI and keyboard interaction.

## 6. Explicitly Deferred

The following are deferred until the local-first product is stable:

- Remote subtitle indexing.
- Remote video playback.
- Local HTTP proxy.
- Remote cache management.
- Anki integration.
- Vocabulary book workflows.
- Advanced real-time video visual effects.
- Cross-platform support.
- Public release work.
