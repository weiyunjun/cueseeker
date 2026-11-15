# 2026-11-14 File Card Rich Metadata and Unified Zero-Padded Duration Format

- **Covering Requirement**: `docs/human/requirements/20261114-Feature-File Card Rich Metadata And Unified Duration Format.md`
- **Branch / Baseline**: `main` (`a5f5de7`)

## Summary of Changes

1. **Database Schema 68 and query boundary fixes (`CueSeekerCore`)**
   - `DatabaseBootstrap.swift` / `DatabaseBootstrap+Migrations.swift`: Bumped `currentSchemaVersion` to `68`, added `migrateSchema67To68(on:)` and table index `idx_subtitle_cue_lines_subtitle_file ON subtitle_cue_lines(subtitle_file_id)`, guarding migration execution against actual `subtitle_cue_lines` columns for legacy test fixture compatibility.
   - `IndexedContentDatabaseModels.swift` / `IndexedContentDatabase.swift`: Removed `COALESCE(..., 0)` from SQL queries and switched `IndexedContentObject` and `IndexedContentSubtitle` metadata fields to optionals, loading video width/height, video codec, duration, subtitle `raw_cue_count`, and valid cue counts (`loadValidCueCounts(for:)` grouping directly via the `subtitle_file_id` index without extra joins) so SQL `NULL` remains strictly distinct from real `0` values.

2. **Unified domain formatting and resolution tier mapping (`CueSeekerCore`)**
   - `LibraryDatabase+FileDetail.swift` (`MediaDetailFormatter`):
     - Added `shortResolutionText(width:height:)`: derives 10 simplified resolution tiers from `videoResolutionBenchmarks` (`8K` down to `144P` reference dimensions and widescreen flags), `resolutionCropToleranceRatio = 0.05`, `widescreenMinimumHeightRatio = 0.5`, and `widescreenMaximumAspectRatio = 3.6` — matching every tier when the short side meets `shortSide >= tier.height * 0.95`, applying cropped landscape widescreen matching only when `width > height`, aspect ratio `<= 3.6`, tier is not `2K`, `width >= tier.width * 0.95`, and `height >= tier.height * 0.5`, and falling back to `144P` for positive dimensions below the top 9 tiers.
     - Unified detail dialog and card video codec display names in `videoCodecMappings` (adding `VVC / H.266`), providing `shortVideoCodecText(_:)` while preserving `codecText(_:)` for `File Info`.
     - Extracted `formattedDuration(seconds:)` and `formattedDuration(seconds:roundingRule:)`, unifying two-digit zero-padded `MM:SS` (`< 1h`) and `HH:MM:SS` (`>= 1h`) formatting across playback controls, library covers, and `File Info`, alongside `shortDurationText(_:)`.

3. **Presentation-layer card subtitles, duration reuse, localization, and cache invalidation (`CueSeekerApp`)**
   - `WorkbenchFileView.swift`: Added `FileCardSubtitleFormatter` joining non-empty metadata fields with two ASCII spaces `"  "` into a single subtitle string passed to the existing `WorkbenchFileCard`, without altering shared `WorkbenchSelectableText` or UI layout metrics; real `0` values render normally (`0 B`, `0 raw cues` / `0 条原始台词`, etc.) while `NULL` fields are omitted.
   - `Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`: Added trilingual singular/plural cue count keys `file.card.raw_cue_count.{one,other}` and `file.card.valid_cue_count.{one,other}`.
   - `LibraryCoverViews.swift`, `PlaybackChromeView.swift`, `PlaybackProgressScrubber.swift`: Switched to shared `MediaDetailFormatter.formattedDuration(seconds:...)`.
   - `AppCoordinator+Indexing.swift`: Appended `invalidateFileTreeCache()` in `refreshLibraryAfterAuxiliaryDataMutation()` so background asynchronous video metadata completion invalidates and rebuilds the `File` tree cache on demand.

## Unit Tests & Verification

Executed after the final code edit:

1. **Targeted Core and UI regression suites (8 suites covering resolution boundaries and File cards)**:
   `swift test --package-path apps/macos-native --filter "DatabaseBootstrapTests|IndexedContentDatabaseTests|FileDetailDatabaseTests|LibraryCoverProgressPresentationTests|FileRouteNavigationTests|WorkbenchInvalidationTests|FileDetailDialogTests|FileCardMenuTests"`
   - Result: `87` Swift Testing cases passed (`0` failed).

Prior initial implementation commit (`b525560`) under the same requirement also passed the extended 17 Core/App suites (`229` passed, `0` failed), localization and file size tests (`5` XCTest + `2` Swift Testing passed, `0` failed), and `CueSeekerPlaybackTests` (`135` passed, `0` failed); the subsequent refinement only adjusted resolution tier boundaries and corresponding test cases used by `WorkbenchFileView.FileCardSubtitleFormatter`.
