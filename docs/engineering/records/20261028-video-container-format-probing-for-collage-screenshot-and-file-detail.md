# 2026-10-28 Video Container Format Probing For Collage Screenshot And File Detail

## Requirement Reference
- `docs/human/requirements/20261028-Bug-Video Container Format Probing For Collage Screenshot And File Detail.md`

## Summary of Changes
1. **Background Video Container Probing & Persistence (`SFXNativePlaybackPlayer.h`, `SFXMediaMetadataInspector.m`, `DatabaseBootstrap.swift`, `DatabaseBootstrap+Migrations.swift`, `LibraryDatabaseProtocols.swift`, `LibraryDatabase.swift`, `PlaybackVideoMetadataIndexer.swift`)**:
   - Extended `SFXMediaMetadataInspector` to capture the FFmpeg demuxer `formatName` and ISO container `major_brand` during background video metadata indexing.
   - Bumped database schema version from `63` to `64` (`migrateSchema63To64`), adding `container_format TEXT` to `video_files` and marking existing rows for background metadata backfill (`duration_retry_pending = 1`).
   - Updated `PlaybackVideoMetadataIndexer` and `LibraryDatabase.updateVideoMetadata` to persist the resolved container format extension into `video_files.container_format`.
2. **File Detail Format Display Without Main-Thread I/O (`LibraryDatabase+FileDetail.swift`, `WorkbenchFileDetailDialog.swift`)**:
   - Updated `LibraryDatabase.fileDetailVideoInfo(for:)` to read `vf.container_format` directly from SQLite and pass it to `WorkbenchFileDetailDialog` and `MediaDetailFormatter.fileFormatText(path:containerFormat:)`, avoiding any synchronous file or network I/O when opening the File Detail dialog on the main thread.
   - Added `MediaDetailFormatter.resolvedVideoContainerExtension(formatName:majorBrand:videoCodec:fallbackExtension:)` to map FFmpeg container families (`matroska,webm` with `vp8`/`vp9`/`av1` WebM disambiguation, `flv`, `avi`, `mpegts`, `mpeg`/`vob`, `asf`, `rm`, `ogg`, and ISO `mov,mp4,m4a,3gp,3g2,mj2` with `major_brand`) to their canonical extension while preserving same-family extensions.
3. **Collage Frame Extraction Container Probing & Fallback Retry (`SubtitleScreenshotExporter.swift`, `SFXMediaMetadataInspector.m`)**:
   - Added `SFXMediaMetadataInspector.containerProbe(atMediaPath:httpHeaders:)` (`avformat_open_input` only, without `avformat_find_stream_info`) returning `formatName` and `hasHeaderVideoParameters`.
   - Updated `SubtitleCollageRenderSession` to serialize and cache playable input resolution and container probing once per session across concurrent group renders.
   - Updated `SubtitleScreenshotExporter` to enable `-cueseeker_skip_internal_subtitles 1` only when the probed container is Matroska/WebM, enable `-nofind_stream_info` only when header video dimensions are already present for Matroska/WebM or ISO containers, and automatically retry frame extraction once without fast-path flags if initial extraction fails.

## Verification
- Added and updated unit tests in `DatabaseBootstrapTests.swift`, `FileDetailDatabaseTests.swift`, `FileDetailDialogTests.swift`, `PlaybackVideoMetadataIndexerTests.swift`, and `SubtitleScreenshotExporterTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "DatabaseBootstrapTests|FileDetailDatabaseTests|FileDetailDialogTests|PlaybackVideoMetadataIndexerTests|SubtitleScreenshotExporterTests"`.
- Outcome matched expectations.
