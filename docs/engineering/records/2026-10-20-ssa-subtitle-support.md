# Implementation Record: SSA Subtitle Support

- **Date**: 2026-10-20
- **Requirement**: `docs/human/requirements/20261020-Feature-SSA Subtitle Support.md`
- **Design References**:
  - `docs/human/design/func/Library Management.md`
  - `docs/human/design/func/Subtitle Standardization & Indexing.md`
  - `docs/human/design/func/Subtitle Language Recognition.md`
  - `docs/human/design/func/Player & Playback.md`
  - `docs/human/design/ui/UI Components - Dialogs & Overlays.md`

## Summary of Changes

1. **Subtitle Format Model, Scanning, and Same-Name Default Priority (`Sources/CueSeekerCore/SubtitleEntry.swift`, `SubtitleFileScanner.swift`, `LibraryDatabaseModels.swift`)**:
   - Added `.ssa` to `SubtitleFormat`, extended `SubtitleFormat(fileExtension:)` to recognize `.ssa`, updated `sortPriority` to `ass > ssa > srt > vtt`, and added `usesASSSemantics`.
   - Added `"ssa"` to `SubtitleFileScanner.supportedSubtitleExtensions` so local, WebDAV, SMB, FTP, and NFS folder scanning and video matching discover `.ssa` subtitle files.
   - Updated `VideoSubtitles.init` documentation and sorting behavior so same-named subtitles follow `ass > ssa > srt > vtt` before falling back to Finder file name order.

2. **SSA Parsing, Alignment Normalization, Style-Scoped Language Recognition, and 4-Part Change Detection (`Sources/CueSeekerCore/ASSParser.swift`, `SubtitleTextDecoder.swift`, `SubtitleIndexer.swift`, `ASSRenderSegmenter.swift`, `SubtitleLanguageAnalyzer.swift`, `CueLineLanguages.swift`, `CueIdentityReconciler.swift`, `IndexingDatabase.swift`)**:
   - Extended `ASSParser` (`parseCueGroups` and `parseCueGroupsForIndexing`) with `format: SubtitleFormat = .ass` and propagated `sourceFormat: format` to parsed `SubtitleCueLine` entries.
   - Added `[V4 Styles]` section parsing alongside `[V4+ Styles]`, converted legacy SSA style `Alignment` values (`1..3` bottom, `5..7` top, `9..11` middle, plus VSFilter `4`/`8`) to numpad alignment (`1..9`), and supported inline `\a` alignment override tags in addition to `\an`.
   - Canonicalized style names by stripping leading `*` characters in both style definition lookup and style-based language recognition so `*Default` and `Default` resolve as the same style.
   - Routed `.ssa` through ASS-style cue group grouping, vertical display ordering, font intent extraction, large-file render segmentation, playback finish primary-style metadata, and 4-part (`style + timestamp + content + remainder`) cue identity reconciliation.

3. **Playback Rendering, Screenshot/Collage/Anki Export, and File Detail Integration (`Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`, `PlaybackSubtitleFocusSessionStore.swift`, `Sources/CueSeekerPlayback/SubtitleScreenshotExporter.swift`)**:
   - Mapped `.ssa` to the `libass`-backed `.ass` playback subtitle source format so playback rendering, subtitle track switching, screenshot export, collage preview/export, and Anki export render `.ssa` subtitles natively via `libass`.

## Verification

- Verified `ASSParserTests` (including `parsesSSADialogueWithV4StylesLeadingStarAndLegacyAlignment`, `ordersSameNamedVideoSubtitlesWithAssBeforeSsaBeforeSrtBeforeVtt`, and `reconcilesSSACueIdentityUsingFourPartRules`), `SubtitleFileScannerTests`, and `SubtitleIndexerTests` (`indexesSSASubtitleFileAndSkipsUnchangedOnSecondPass`) via `swift test`.
