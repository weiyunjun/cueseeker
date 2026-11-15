# 2026-11-15 HDR Metadata Indexing, File Card Badge, and File Info Display

## Covering Requirement

- `docs/human/requirements/20261115-Feature-HDR Metadata Indexing File Card And File Info Display.md`
- Branch: `main` (prior commit `db00640`, requirement commit `c010af5`, initial feature commit `8e97adb`)

## Summary of Implementation & Post-Review Fixes

1. **Structured Raw HDR Domain Model & SQLite Schema 69 (`CueSeekerCore` / `CueSeekerPlayback`)**
   - Added `VideoHDRStandard` and `VideoHDRMetadata` in `LibraryDatabaseModels.swift`, storing only structured raw HDR attributes (standards list, Dolby Vision profile and signal compatibility ID, color primaries token, transfer characteristic token, mastering display primaries and luminance range, MaxCLL, and MaxFALL) without pre-formatted localized strings.
   - Bumped `DatabaseBootstrap.currentSchemaVersion` to `69` and added `migrateSchema68To69(on:)`, adding nullable `hdr_metadata TEXT` to `video_files` and setting `duration_retry_pending = 1` on existing rows without scanning external media files during migration.
   - Propagated `hdrMetadata` across `SFXMediaMetadata`, `ProbedVideoMediaMetadata`, `PlaybackVideoMetadataIndexer`, `LibraryDatabase.updateVideoMetadata` (clearing `duration_retry_pending = 0` for both HDR and confirmed plain SDR `nil` writes), `IndexedContentObject`, and `FileDetailVideoInfo`, while preserving `hdr_metadata` across in-app file-group and folder renames.
   - Updated `IndexingDatabase.pendingVideoMetadataPaths(libraryID:under:)` to also read `hdr_metadata` and schedule automatic re-probing when an already-indexed `.dolbyVision` record is missing `colorPrimaries` or `transferFunction` (`colorPrimaries == nil || transferFunction == nil`), clearing once complete metadata is written back.

2. **FFmpeg Container/Stream Probing, Dolby Vision RPU Parsing & Bounded Sampling (`CNativePlayback`)**
   - Added `SFXMediaHDRMetadata` in `SFXNativePlaybackPlayer.h` and `SFXInspectVideoHDRMetadata` in `SFXMediaMetadataInspector.m`.
   - Prioritized stream-level `codecpar` color properties and `coded_side_data` (`AV_PKT_DATA_DOVI_CONF`, `AV_PKT_DATA_MASTERING_DISPLAY_METADATA`, `AV_PKT_DATA_CONTENT_LIGHT_LEVEL`, and `AV_PKT_DATA_DYNAMIC_HDR10_PLUS`), plus bounded frame-level inspection when needed.
   - Added `AV_FRAME_DATA_DOVI_METADATA` (`AVDOVIMetadata`) extraction in `SFXHDRMergeDOVIMetadata` using `<libavutil/dovi_meta.h>` inline accessors (`av_dovi_get_ext` and `av_dovi_get_color`):
     - Level 9 (`AVDOVIDmLevel9`): classifies `source_display_primaries` (`display_p3`, `dci_p3`, `bt2020`, `bt709`) via shared CIE 1931 xy tolerance matching (`SFXHDRClassifyCIExyPrimaries`) when mastering primaries are unset and denominators are positive.
     - Level 6 (`AVDOVIDmLevel6`): extracts exact mastering luminance (`min_luminance / 10000.0` .. `max_luminance`) with precedence over RPU PQ estimates, plus `max_cll` / `max_fall`.
     - RPU Color Header (`AVDOVIColorMetadata`): derives fallback mastering luminance from `source_min_pq` / `source_max_pq` using SMPTE ST 2084 EOTF rounded to `0.0001` nit precision (integer nit rounding for max values `>= 10.0` nits), allowing subsequent exact SEI or Level 6 values to override PQ estimates.
   - Aligned `SFXBuildHDRMetadataFromState` with `SFXHDRColorPipeline.m` Dolby Vision color resolution: for `hasDOVI` streams with unspecified primaries or single-layer `dv_profile == 5` / `AVCOL_SPC_IPT_C2`, derives `"bt2020"` and `"smpte2084"` (or `"arib-std-b67"` for Profile `8.4`).
   - Tightened broadcast/raw stream mid-stream sampling:
     - Removed `"flv"` from `SFXIsBroadcastOrRawStreamFormatName` and gated mid-stream decode/seek on HDR-capable broadcast/streaming codecs (`AV_CODEC_ID_HEVC`, `AV_CODEC_ID_AV1`, `AV_CODEC_ID_VP9`, `AV_CODEC_ID_VVC`), bit depth `>= 10`, or unresolved pixel formats (`bitDepth <= 0 && pixelFormat == AV_PIX_FMT_NONE`), ensuring zero extra seeks or decodes for plain 8-bit SDR H.264/MPEG-2/MPEG-1 TS/MPEG/FLV videos while keeping spliced 8-bit SDR-to-HLG HEVC TS detection working.
     - Made mid-stream sampling strictly mutually exclusive (`didMidStreamSample`): prefers direct `AVSEEK_FLAG_BYTE` seeks (`0.35`, `0.70`), falls back to timestamp seeks only when byte seeking was unavailable or failed, and falls back to sequential reading only if neither seek strategy sampled.

3. **Pure-Logic Formatting, UI Reuse & Localization (`CueSeekerCore` / `CueSeekerApp`)**
   - Added `MediaDetailFormatter.shortHDRStandardText` (priority: Dolby Vision > `HDR10+` > `HDR10` > `HLG`) and `MediaDetailFormatter.hdrProperties` (rendering up to 6 conditional rows with `.0`-free profile formatting, zero-trimming on mastering nits, no thousands separators, and suppression of missing or zero `MaxCLL` / `MaxFALL` items).
   - Updated `FileCardSubtitleFormatter.videoSubtitle(for:locale:)` in `WorkbenchFileView.swift` and `WorkbenchFileDetailDialog.hdrPropertyItems(for:locale:)` in `WorkbenchFileDetailDialog.swift`, reusing existing `FileDetailRow` / `SettingsRowDivider` controls and `AppLocalizationStore` / `languageRevision` live locale refresh with `en`, `zh-Hans`, and `zh-Hant` keys in `Localizable.strings`.
   - Updated `docs/engineering/05_database_rules.md` (documenting Schema `68` and `69`) and `docs/changelog.md`.

## Compilation & Pure-Logic Test Verification

- Ran filtered headless pure-logic unit tests after the final code and test edits:
  `swift test --package-path apps/macos-native --filter "DatabaseBootstrapTests|FileDetailDatabaseTests|LibraryRenameTests|IndexedContentDatabaseTests|IndexingDatabaseTests|PlaybackVideoMetadataIndexerTests|FileRouteNavigationTests|hdrPropertyItemsAndLocalizationBundlesSwitchCleanly"`
  - Result: `106` tests executed, `106` passed (`0` failures, `0` skipped), covering Schema `68 -> 69` migration, `duration_retry_pending` clearing and incomplete Dolby Vision re-probing, rename preservation, synthetic FFmpeg SDR MP4/MPEG-TS/FLV fast paths, HDR10 static metadata, spliced broadcast SDR-to-HLG MPEG-TS sampling, card subtitle priority, `File Info` 6-row formatting, and live `en`/`zh-Hans`/`zh-Hant` localization switching.
- End-to-end UI rendering and real-world HDR media file verification remain with the human owner for acceptance testing.
