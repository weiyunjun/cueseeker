# 2026-10-23 Remove ASS Render Segment Cache And Bound Subtitle Render Memory

## Requirement Reference
- `docs/human/requirements/20261023-Engineering-Remove ASS Render Segment Cache And Bound Subtitle Render Memory.md`

## Summary of Changes
1. **Database Schema 59 & Removal of SQLite ASS Render Segment Cache (`ASSRenderSegmenter.swift`, `DatabaseBootstrap.swift`, `DatabaseBootstrap+Migrations.swift`, `PlaybackSubtitleDatabaseModels.swift`, `PlaybackSubtitleDatabase.swift`, `SubtitleIndexer.swift`, `IndexingDatabase.swift`)**:
   - Upgraded `DatabaseBootstrap.currentSchemaVersion` from `58` to `59` and added `migrateSchema58To59` to drop `idx_ass_render_segments_lookup` and `ass_render_segments`.
   - Removed `ASSRenderSegmenter.swift` and all indexing/playback code paths that generated, persisted, queried, or deleted segmented ASS script copies in SQLite.
2. **Zero-Copy File Mapping, Bounded `libass` Caches, and Windowed Track Event Management (`SFXASSRenderer.h`, `SFXASSRenderer.m`, `SourceFaithfulASSSubtitleOverlayView.swift`, `ASSFontAliasResolver.swift`, `SubtitleTextDecoder.swift`)**:
   - Configured `ass_set_cache_limits(_renderer, 128, 4)` on `libass` renderer instances to cap glyph and bitmap cache growth during dense ASS visual-effect sequences.
   - Updated `SFXASSRendererSession` to map UTF-8 `.ass` files read-only via `mmap` (`0.0 MB` dirty heap footprint), index `Dialogue:` event byte ranges into compact `SFXASSEventSlice` entries, rewrite font aliases only on the header and active-window `\fn` lines, and refresh 5-second event windows with `malloc_zone_pressure_relief(NULL, 0)` to reclaim transient renderer and font allocations immediately after dense scenes.
   - Optimized `ASSFontAliasRewriter` and `SubtitleTextDecoder` to avoid whole-script UTF-16 `NSString` bridging and `[Events]` line splitting.

## Verification
- Updated unit tests in `DatabaseBootstrapTests.swift`, `PlaybackSubtitleDatabaseTests.swift`, and `SubtitleIndexerTests.swift`.
- Ran `swift test --package-path apps/macos-native --filter "DatabaseBootstrapTests|PlaybackSubtitleDatabaseTests|SubtitleIndexerTests|SubtitleTextDecoderTests|CASSRenderingProbeTests|PlaybackRequestTests"` (all 127 tests passed).
- Verified 60-second real-playback `ri_phys_footprint` benchmarks on `BanG Dream! It's MyGO!!!!!` EP05 (`95s–155s`, avg `73.2 MB -> 51.8 MB`) and `Cosmic Princess Kaguya` (`4855s–4915s`, avg `111.8 MB -> 59.8 MB`, 0.1s peak `280.9 MB -> 102.7 MB`).
