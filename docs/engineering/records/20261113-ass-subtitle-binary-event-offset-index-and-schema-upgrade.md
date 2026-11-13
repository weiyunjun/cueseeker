# ASS Subtitle Binary Event Offset Index And Schema Upgrade Implementation Record

- Date: 2026-11-13
- Related Requirement: `docs/human/requirements/20261113-Engineering-ASS Subtitle Binary Event Offset Index And Schema Upgrade.md`
- Related Design Reference: `docs/human/design/data/Data.md`
- Scope: SQLite schema upgrade (`66 -> 67`), Index-only ASS/SSA binary event offset index creation and lifecycle maintenance, and read-only fingerprint validation + time-window byte-range query APIs in `CueSeekerCore` (zero playback rendering behavior changes in `CueSeekerPlayback`).

## Changes Made

- **Database Schema `67` & Smooth Lossless Migration (`DatabaseBootstrap.swift`, `DatabaseBootstrap+Migrations.swift`, `SQLiteDatabase.swift`, `docs/engineering/05_database_rules.md`)**:
  - Bumped `DatabaseBootstrap.currentSchemaVersion` from `66` to `67`.
  - Added `ass_event_offset_indexes` (`subtitle_file_id PRIMARY KEY REFERENCES subtitle_files(id) ON DELETE CASCADE`, `algorithm_version`, `file_size`, `modified_at`, `status` (`ready` | `ineligible`), `encoding`, `header_text`, `event_count`, `compressed_events BLOB`, `updated_at`) to fresh schema creation and added `migrateSchema66To67(on:)` (fixing `previousVersion <= 65` fallthrough into `previousVersion <= 66`).
  - Migration executes purely in SQLite metadata without scanning external media files, preserving 100% of libraries, videos, subtitles, cues, Excerpts, watch states, playback history, covers, and task records across both `debug` and `release` database paths.
  - Added binary BLOB binding (`bind(_ value: Data, at:)`) and nullable BLOB reading (`nullableBlobColumn(_:)`) to `SQLiteStatement`.

- **ASS/SSA Binary Event Offset Builder & Multi-Encoding Byte Slicing (`ASSEventOffsetIndex.swift`, `SubtitleTextDecoder.swift`)**:
  - Extended `SubtitleTextDecoder` with `decodeWithResolvedEncoding(_:format:)`, BOM-less UTF-16/UTF-32 endianness refinement, BOM byte-length detection, and stable round-trip `stringEncoding(named:)` lookup.
  - Implemented `ASSEventOffsetIndexer` (`currentAlgorithmVersion = 1`) for all valid indexed `.ass` and `.ssa` files with no file-size threshold:
    - Scans raw file bytes by encoding code-unit width (`1` byte for UTF-8 and ASCII-newline-safe legacy encodings such as GB18030 / Shift-JIS / Big5, `2` bytes for UTF-16 LE/BE, `4` bytes for UTF-32 LE/BE) so recorded `(byte_offset, byte_length)` slices decode cleanly without splitting multi-byte characters or trailing `\r\n`/`\n` terminators.
    - Extracts normalized initialization `header_text` up through `[Events]` and its `Format:` declaration while omitting `[Aegisub ...]` sections and `Comment:` lines.
    - Marks files containing `[Fonts]`, `[Graphics]`, mid-stream `Format:` changes after `Dialogue:`, unsupported section ordering after `[Events]`, or stateful shift encodings as `status = 'ineligible'` (bound to `algorithm_version`, `file_size`, and `modified_at` with `NULL` `compressed_events`) so repeat `Index` runs skip rescanning unchanged ineligible files.
    - Retains all renderable `Dialogue:` events where `end_ms > start_ms` (including short-duration particle bursts and `\p1` vector drawings) in exact source-file line order, packed as 16-byte little-endian records (`[start_ms: Int32, end_ms: Int32, byte_offset: UInt32, byte_length: UInt32]`) compressed with `NSData.CompressionAlgorithm.zlib`.

- **Index-Only Persistence, Backfill & Lifecycle Maintenance (`SubtitleIndexer.swift`, `IndexingDatabase.swift`)**:
  - Wired `ASSEventOffsetIndexer.build` into `SubtitleIndexer` for all ASS/SSA files during both `.fullIndex` and lightweight `.supplementalMetadataRefresh` (when an upgraded pre-Schema-67 ASS/SSA row is missing a current `ass_event_offset_indexes` entry, backfilling it on the next `Index` without churning cues, FTS, facets, `CueID`s, or Excerpts).
  - Persisted rows via `upsertASSEventOffsetIndex` inside `publishLibraryIndex` and `replaceCueGroupsInCurrentTransaction`, and explicitly cleaned up rows in `removeIndexedDataInCurrentTransaction` and `deleteIndexedSubtitlePath` alongside `ON DELETE CASCADE`.
  - Keying by `subtitle_file_id` preserves binary offset index validity across in-App file-group and folder renames (`LibraryRenamer`) without re-indexing.

- **Read-Only Fingerprint Validation & Time-Window Query Foundation (`PlaybackSubtitleDatabase.swift`, `ASSEventOffsetIndex.swift`)**:
  - Added read-only `validatedASSEventOffsetIndex(forSubtitleFile:...)`, `assEventByteRanges(forSubtitleFile:inMilliseconds:...)`, and `hasCurrentASSEventOffsetIndex(forSubtitleFile:fileSize:modifiedAt:)` to `PlaybackSubtitleDatabase` and `PlaybackSubtitleRenderCacheProviding`.
  - Validates subtitle path, `status == 'ready'`, `algorithm_version`, `file_size`, and `modified_at` against the live file on disk, returning `nil` immediately when unindexed, ineligible, missing, or externally edited, and returning overlapping `ASSEventByteRange` slices + `FileHandle.seek` line decoding in strict original source-file order when valid.

- **Automated Tests (`DatabaseBootstrapTests.swift`, `ASSEventOffsetIndexTests.swift`)**:
  - Verified fresh schema `67` creation and lossless `66 -> 67` migration across isolated `debug/CueSeeker.sqlite` and `release/CueSeeker.sqlite` fixtures without touching media files on disk.
  - Verified small and 5,001-event heavy particle ASS/SSA indexing without size threshold, exact source-file line order preservation across overlapping `\pos`/`\p1` layers, exact byte-slice decoding across UTF-8 BOM / UTF-16 LE / UTF-16 BE / UTF-32 LE / GB18030 with CRLF boundaries, `[Fonts]` and mid-stream `Format:` ineligible caching on repeat `Index`, legacy backfill preserving `CueID` and Excerpts, external edit invalidation, file/folder removal cleanup, and in-App `LibraryRenamer` preservation.

## Verification

- `swift test --package-path apps/macos-native --filter "ASSEventOffsetIndexTests|DatabaseBootstrapTests"` — 41 tests passed, 0 failures.
- `swift test --package-path apps/macos-native --no-parallel --filter "CueSeekerPlaybackTests"` — Passed with 0 failures.
