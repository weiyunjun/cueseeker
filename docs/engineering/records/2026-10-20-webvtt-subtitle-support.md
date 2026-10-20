# Implementation Record: WebVTT Subtitle Support

- **Date**: 2026-10-20
- **Requirement**: `docs/human/requirements/20261020-Feature-WebVTT Subtitle Support.md`
- **Design References**:
  - `docs/human/design/func/Library Management.md`
  - `docs/human/design/func/Subtitle Standardization & Indexing.md`
  - `docs/human/design/func/Subtitle Language Recognition.md`
  - `docs/human/design/func/Player & Playback.md`
  - `docs/human/design/ui/UI Components - Dialogs & Overlays.md`

## Summary of Changes

1. **Subtitle Format Model, Scanning, and Same-Name Default Priority (`Sources/CueSeekerCore/SubtitleEntry.swift`, `SubtitleFileScanner.swift`, `LibraryDatabaseModels.swift`)**:
   - Added `.vtt` to `SubtitleFormat`, added `SubtitleFormat(fileExtension:)`, and defined `sortPriority` (`ass > srt > vtt`).
   - Added `"vtt"` to `SubtitleFileScanner.supportedSubtitleExtensions` so local, WebDAV, and SMB folder scanning and video matching discover `.vtt` subtitle files.
   - Updated `VideoSubtitles.init` to order same-named subtitles (after stripping the last 1 extension) by `ass > srt > vtt` before falling back to Finder order.

2. **WebVTT Parsing, Inline Tag Stripping, Indexing, and 2-Part Change Detection (`Sources/CueSeekerCore/SRTParser.swift`, `SubtitleTextDecoder.swift`, `SubtitleIndexer.swift`, `SubtitleLanguageAnalyzer.swift`, `CueLineLanguages.swift`, `CueIdentityReconciler.swift`)**:
   - Extended `SRTParser` (`parse`, `parseForRendering`, `parseCueGroups`, `hasValidStructure`, and `parseCueGroupsForIndexing`) with `format: SubtitleFormat = .srt`.
   - For `.vtt`, ignored the `WEBVTT` header and header attributes, skipped `NOTE`, `STYLE`, and `REGION` non-cue blocks, located each cue via its `-->` timecode line (ignoring optional identifier lines above the timecode line and layout parameters after the end timecode), supported both `HH:MM:SS.mmm` and hour-omitted `MM:SS.mmm` timecodes, and stripped `<...>` inline tags before applying non-ASS line cleaning, duration filtering (`>= 200ms`), empty-text filtering, and normalized deduplication.
   - Routed `.vtt` through non-ASS single-cue `Cue Group` construction, file-scope language recognition from body text, and 2-part (`timestamp + content`) cue identity reconciliation.

3. **Playback Rendering, Screenshot/Export, and File Detail Integration (`Sources/CueSeekerPlayback/SRTSubtitleRenderer.swift`, `Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`, `AppCoordinator+FileDetail.swift`)**:
   - Updated `SRTSubtitleRenderer` to pass the source file's `SubtitleFormat` into `SRTParser.parseForRendering(data, format:)` so `.vtt` files render and export screenshots with the shared plain-text subtitle style.
   - Mapped `.vtt` to the plain-text playback subtitle source format and preserved `.vtt` metadata in the File detail dialog.

## Verification

- Verified `SRTParserTests`, `SubtitleTextDecoderTests`, `SubtitleFileScannerTests`, `LibraryDatabaseTests` (`videoSubtitlesListSameNamedOnesFirstAssBeforeSrtThenFinderOrder` and `indexesSearchesAndReconcilesWebVTTSubtitleFiles`), and `CueSeekerPlaybackTests` via `swift test`.
