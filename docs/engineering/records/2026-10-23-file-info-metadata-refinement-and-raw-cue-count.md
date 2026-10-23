# 2026-10-23 File Info Metadata Refinement And Raw Cue Count

## Requirement Reference
- `docs/human/requirements/20261023-UI-File Info Metadata Refinement And Raw Cue Count.md`

## Summary of Changes
1. **Native FFmpeg Metadata Inspection (`SFXNativePlaybackPlayer.h`, `SFXMediaMetadataInspector.m`, `PlaybackVideoMetadataIndexer.swift`)**:
   - Added `videoBitDepth` (`bits_per_raw_sample` falling back to `av_pix_fmt_desc_get(pixFmt)->comp[0].depth`) and `videoPixelFormat` (`av_get_pix_fmt_name`) to `SFXMediaMetadata`.
   - Added `sampleRate` (`sample_rate`) and `bitDepth` (`bits_per_raw_sample` falling back to `av_get_bits_per_sample`) to `SFXMediaAudioTrack` and `VideoAudioTrack`.
2. **Database Schema 59 -> 60 & Indexing (`DatabaseBootstrap.swift`, `DatabaseBootstrap+Migrations.swift`, `SubtitleIndexer.swift`, `IndexingDatabase.swift`, `LibraryDatabase+FileDetail.swift`)**:
   - Upgraded SQLite schema version from `59` to `60`, adding `raw_cue_count INTEGER` to `subtitle_files` and `video_bit_depth INTEGER`, `video_pixel_format TEXT` to `video_files`, and marking existing `video_files` rows with `duration_retry_pending = 1` on upgrade.
   - Added `SubtitleRawCueCounter.count(in:format:)` (using a zero-copy single-pass line scanner) to count uncleaned `Dialogue:` events in `[Events]` for `.ass`/`.ssa` and `-->` timestamp lines for `.srt`/`.vtt`, persisted `raw_cue_count` during indexing, excluded unpaired and unchanged subtitles from Stage 2 (`Indexing subtitles`) progress counts, and backfilled existing unchanged subtitles with `raw_cue_count IS NULL` via a lightweight single-column update without re-parsing cues or running language analysis.
3. **File Info Dialog UI & Localization (`WorkbenchFileDetailDialog.swift`, `AppCoordinator+FileDetail.swift`, `Localizable.strings`)**:
   - Updated Video section to remove aspect ratio from Resolution (`1920 × 1080`) and display Bit Depth (`8 bit`) and Pixel Format (`yuv420p`) in order: Resolution, Frame Rate, Codec, Bit Depth, Pixel Format, Bitrate, Duration.
   - Updated Audio section to format Channels as `<N>ch`, add Sample Rate (`48,000 Hz`) and Bit Depth (`24 bit`, omitted when absent), and format Language using `AppLocalization.locale` without trailing code parentheses.
   - Updated Subtitle Specifications section to display Encoding, Raw Lines, and Valid Lines.

## Verification
- Added and updated unit tests in `DatabaseBootstrapTests.swift`, `FileDetailDatabaseTests.swift`, and `FileDetailDialogTests.swift`.
- Verified with `swift test` across `DatabaseBootstrapTests` (29/29), `FileDetailDatabaseTests` (4/4), `SubtitleIndexerTests` (36/36), `PlaybackVideoMetadataIndexerTests` (1/1), and `FileDetailDialogTests` (4/4).
- Outcome matched expectations.
