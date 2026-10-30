# Local Application Logging and Debug/Release Isolation

## Requirement

- `docs/human/requirements/20261030-Engineering-Local Application Logging And Debug Release Isolation.md`

## Scope

- Introduce unified local file logging (`AppLogger`) in `CueSeekerCore` with Debug (`~/Library/Application Support/CueSeeker/logs/debug/`) and Release (`~/Library/Application Support/CueSeeker/logs/release/`) directory isolation, daily file rotation (`cueseeker-YYYY-MM-DD.log`), 10 MB per-file size trimming, and 14-day retention cleanup on application startup.
- Standardize single-line structured log entries (`YYYY-MM-DD HH:mm:ss.SSS [LEVEL] [Category] Message | key=value ...`) across four levels (`ERROR`, `WARN`, `INFO`, `DEBUG`) and seven categories (`App`, `Database`, `Task`, `Playback`, `Export`, `Network`, `System`).
- Merge `PlaybackCollagePerformanceLogger` into the daily log under the `Playback` category and remove legacy `collage-performance.log` files on startup.
- Instrument application lifecycle, database initialization/migration/compaction/errors, background tasks (`add_folder`, `reindex`, `remove_folder`, `rename`, `export`), playback open/decode fallback/track selection/errors, collage & Anki export results, remote folder connections, and system events (URL scheme, game controller, memory pressure) while omitting credentials, user search queries, subtitle text, and high-frequency UI events.
- Keep unit and integration test processes isolated from local disk log directories (`AppLogger.defaultIsEnabled == false` during `swift test`).

## Steps

1. Created `apps/macos-native/Sources/CueSeekerCore/AppLogger.swift` defining `AppBuildConfiguration`, `AppLogLevel`, `AppLogCategory`, and `AppLogger` with daily file resolution, 10 MB size cap trimming, 14-day retention cleanup, legacy `collage-performance.log` cleanup, and unit-test process isolation.
2. Updated `PlaybackCollagePreviewStore.swift` so `PlaybackCollagePerformanceLogger` writes `[INFO] [Playback] Collage rendered` entries through `AppLogger` and recorded collage clipboard/file export outcomes under `Export`.
3. Instrumented `DatabaseBootstrap`, `WebDAVSupport`, `PlaybackPlayer`, `AppDelegate`, `AppCoordinator` (and its Indexing, Playback, Library, Excerpt, AudioTrack, Subtitle, SubtitleFocus, RemoteFolderDialogs, and URLScheme extensions), `TaskQueueStore`, `GameControllerInputMonitor`, `AppMemoryPressureRelief`, `LibraryPlaybackHistoryWriter`, `LibraryStore+Execution`, and `ExcerptStore+Execution` with structured `AppLogger` calls replacing ad-hoc `print` / `NSLog` diagnostics.
4. Updated `PlaybackCollagePreviewTests.swift` and added `AppLoggerTests.swift` to verify Debug/Release directory isolation, daily file naming, structured single-line formatting, minimum level filtering, 10 MB size trimming, and 14-day startup retention cleanup.

## Verification

- Ran `swift test --package-path apps/macos-native --filter "AppLoggerTests|PlaybackCollagePreviewTests"` and the full `swift test --package-path apps/macos-native` test suite.
- Verified zero test residue in `~/Library/Preferences/`, `$TMPDIR`, and `~/Library/Application Support/CueSeeker/logs/`.

## Outcome

- Local application logs are isolated by Debug/Release build mode, rotated daily, capped at 10 MB per file, cleaned up after 14 days, and formatted consistently across all seven categories without leaking sensitive or high-frequency data.

## Follow-ups

- After user runs the Release build for several minutes and reviews the generated daily log output, adjust verbosity or fields if needed.
