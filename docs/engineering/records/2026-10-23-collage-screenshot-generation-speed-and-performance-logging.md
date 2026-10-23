# 2026-10-23 Collage Screenshot Generation Speed And Performance Logging

## Requirement Reference
- `docs/human/requirements/20261023-Engineering-Collage Screenshot Generation Speed And Performance Logging.md`

## Summary of Changes
1. **Video-Only Frame Extraction & Controlled `ffmpeg` Resolution (`SubtitleScreenshotExporter.swift`)**:
   - Updated `ffmpegExecutable()` to prioritize the bundled helper (`Contents/Helpers/ffmpeg`), `CUESEEKER_MEDIA_RUNTIME_ROOT/bin/ffmpeg`, and `.build/media-runtime/arm64-macos13/bin/ffmpeg` before system fallbacks.
   - Updated `videoFrameArguments(...)` to pass `-nofind_stream_info` before `-i`, conditionally pass `-cueseeker_skip_internal_subtitles 1` before `-i` for Matroska/WebM inputs (`mkv`, `mk3d`, `mka`, `mks`, `webm`) when supported by the runtime binary, and pass `-an`, `-sn`, `-dn` after `-frames:v 1` so embedded subtitles, attachments, chapters, audio, and data streams are skipped during frame extraction.
2. **Session-Level ASS Preparation Reuse & Single-Pass Irrelevant Content Stripping (`SubtitleScreenshotExporter.swift`, `PlaybackCollagePreviewStore.swift`)**:
   - Added `SubtitleCollageRenderSession` so a Collage session decodes the external `.ass` file, builds `PreparedASSRenderScript`, and resolves `requestedFontNames` once on the first group render and reuses them in memory across subsequent group renders.
   - Implemented `PreparedASSRenderScript` to scan the ASS UTF-8 bytes once, retain only `[Script Info]` and `[V4* Styles]` non-comment lines plus `[Events]` header and `Format:`, strip `Comment:` lines, `;` / `!:` comments, and unsupported sections (`[Aegisub Project Garbage]`, `[Aegisub Extradata]`, `[Fonts]`, `[Graphics]`), index `Dialogue:` byte ranges by `eventIndex`, and match stacked gradient copies via $O(1)$ selected-index lookup and zero-allocation early-exit byte comparison (`matchesGlyphSignature`).
3. **Local Collage Performance Logging (`PlaybackCollagePreviewStore.swift`)**:
   - Added `PlaybackCollagePerformanceLogger` writing append-only single-line timing records (`total_ms`, `sub_load_ms`, `frame_grab_ms`, `sub_render_ms`, `compose_ms`) to `~/Library/Application Support/CueSeeker/logs/collage-performance.log` with a 2 MB file size cap that trims the oldest half of lines on overflow.
   - Integrated `SubtitleCollageGroupRenderMetrics` and `PlaybackCollagePerformanceLogger` into `PlaybackCollagePreviewStore` to log `initial` and `incremental` Collage group commits.

## Verification
- Updated and added unit tests in `SubtitleScreenshotExporterTests.swift` and `PlaybackCollagePreviewTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter SubtitleScreenshotExporterTests` (6/6 passed) and `swift test --package-path apps/macos-native --filter PlaybackCollagePreview` (14/14 passed).
- Outcome matched expectations.
