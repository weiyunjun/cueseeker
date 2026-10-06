# AppIconStore Tinted Cache Stale On System Accent Color Change

Human-owned documents:

- `docs/human/requirements/20261006-Bug-AppIconStore Tinted Cache Stale On System Accent Color Change.md`
- `docs/human/design/UI Design System.md`

## Why

1. **Problem**:
   - When a user changes the macOS system accent color (e.g. from blue to purple), the SwiftUI table header checkbox updates immediately, but AppKit table row checkboxes remain stuck in the previous accent color until the application is restarted.
2. **Root Cause**:
   - `AppIconStore.tintedImage` caches offscreen-rasterized tinted icons in `tintedCache` keyed by `color.hashValue`.
   - `NSColor.controlAccentColor`'s hash value does not change across system accent color updates, and `AppIconStore` had no observer for `NSColor.systemColorsDidChangeNotification`.
   - `SubtitleTableView`'s document view was not notified to invalidate visible rows when the system accent color changed in selection mode.

## What changed

1. **AppIcon Store (`AppIcon.swift`)**:
   - Added `NSColor.systemColorsDidChangeNotification` observation in `AppIconStore` to clear `tintedCache` whenever system colors or accent color change.
   - Clears tinted cache synchronously on the main thread and asynchronously when notified off-main-thread.
   - Added `#if DEBUG` test hooks (`clearTintedCacheForTesting()`, `tintedCacheCountForTesting()`).
2. **Table Sandbox Coordinator (`SubtitleTableView.swift`)**:
   - Registered `NSColor.systemColorsDidChangeNotification` observer in `SubtitleTableView.Coordinator.attach`.
   - In `systemColorsDidChange`, checks `guard isSelectionMode else { return }` and invalidates the visible document area (`invalidateVisibleDocument()`).
   - Updated `invalidateVisibleDocument()` to fall back to `documentView.needsDisplay = true` when `visibleRect.isEmpty` (e.g. during offscreen unit test scenarios).
3. **Tests**:
   - `AppIconAssetTests.swift`: Added `systemColorsDidChangeClearsTintedCache` verifying `AppIconStore.tintedCache` is cleared when `NSColor.systemColorsDidChangeNotification` is posted.
   - `SubtitleTableVirtualRowTests.swift`: Added `systemColorsDidChangeInvalidatesVisibleDocumentOnlyInSelectionMode` verifying that table document invalidation triggers only when in selection mode upon system color change notification.

## Verification

- Automated tests:
  - `swift test --filter AppIconAssetTests`: 6/6 passed.
  - `swift test --filter SubtitleTableVirtualRowTests`: 101/101 passed.
