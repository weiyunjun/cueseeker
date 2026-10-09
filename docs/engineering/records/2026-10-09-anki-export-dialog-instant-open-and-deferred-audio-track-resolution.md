# Anki Export Dialog Instant Open And Deferred Audio Track Resolution

Human-owned documents:

- `docs/human/requirements/20261009-Bug-Anki Export Dialog Instant Open And Deferred Audio Track Resolution.md`
- `docs/human/requirements/20260912-Feature-Export To Anki Dialog And Card Content.md`

## Why

1. **Main Thread Freeze on Export to Anki**:
   - When selecting a large number of search results or excerpts (e.g. several hundred to 1,500+ items) and clicking `Export to Anki`, the UI froze for several seconds (up to ~1.9s on 1,491 items).
2. **Timing Misalignment (Process Issue)**:
   - The Anki export dialog (`AnkiExportDialog`) only configures export parameters (cue text side, optional fields, file name, destination directory). It does not render individual items, row counts, video files, or audio tracks.
   - Previously, `openAnkiExportDialog` eagerly iterated through all items on the `@MainActor` to resolve `defaultAudioTrackIndex` for each video file, triggering hundreds of synchronous SQLite queries and JSON track decodings before presenting the dialog.
3. **Deferred Resolution Architecture**:
   - The dialog presentation path should remain purely lightweight (< 1ms).
   - Audio track index resolution is deferred to the background export runner (`configureAnkiExportRunner`) when the user confirms export and the background worker queue executes the job.

## What changed

1. **Lightweight Dialog Presentation (`AppCoordinator+AnkiExport.swift`)**:
   - Removed synchronous `defaultAudioTrackIndex` queries from `openAnkiExportDialog`. Items keep their initial audio track index (0), allowing the dialog session to initialize and present immediately (< 1ms).
2. **Background Audio Track Resolution (`AppCoordinator+AnkiExport.swift`)**:
   - Added `nonisolated static func resolveDefaultAudioTracks(in:using:)` to query `libraryDatabase.videoAudioTracks` off the main thread with caching per video path.
   - Updated `configureAnkiExportRunner` so `tasks.runExport` resolves default audio tracks in the background execution closure before passing items to `TaskQueueStore.ankiExportRunner`.
3. **Unit Tests (`AnkiPackageExporterTests.swift`)**:
   - Added `ankiExportResolvesDefaultAudioTracksInBackground()` to verify that default audio tracks are resolved correctly from `LibraryDatabase` in the background runner.

## Verification

- `swift build --package-path apps/macos-native`: succeeded.
- `swift test --package-path apps/macos-native --filter AnkiPackageExporterTests`: passed (10/10 tests passed).
- `swift test --package-path apps/macos-native --filter TaskQueueStoreTests`: passed (29/29 tests passed).
- End-to-end performance verification:
  - Excerpt (396 rows): dialog open cost reduced from 453.7 ms to 0.20 ms; total cost reduced from 530.1 ms to 69.9 ms.
  - Search (1491 rows): dialog open cost reduced from 1850.7 ms to 0.38 ms; total cost reduced from 1877.3 ms to 33.4 ms.
