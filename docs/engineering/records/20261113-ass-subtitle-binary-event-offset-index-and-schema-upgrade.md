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

- **ASS/SSA Binary Event Offset Builder & Multi-Encoding Byte Slicing (`ASSEventOffsetIndex.swift`, `ASSParser.swift`, `SubtitleTextDecoder.swift`)**:
  - Extended `SubtitleTextDecoder` with `decodeWithResolvedEncoding(_:format:)`, BOM-less UTF-16/UTF-32 endianness refinement, BOM byte-length detection, and stable round-trip `stringEncoding(named:)` lookup.
  - Implemented `ASSEventOffsetIndexer` (`currentAlgorithmVersion = 2`) for all valid indexed `.ass` and `.ssa` files with no file-size threshold:
    - Scans raw file bytes by encoding code-unit width (`1` byte for UTF-8 and ASCII-newline-safe legacy encodings such as GB18030 / Shift-JIS / Big5, `2` bytes for UTF-16 LE/BE, `4` bytes for UTF-32 LE/BE) so recorded `(byte_offset, byte_length)` slices decode cleanly without splitting multi-byte characters or trailing `\r\n`/`\n` terminators.
    - Extracts normalized initialization `header_text` up through `[Events]` and its `Format:` declaration while ignoring `Comment:` lines and all non-core metadata sections (`[Aegisub ...]`, `[Extradata]`, `[Project Garbage]`, etc.).
    - Allows trailing or empty `[Fonts]` / `[Graphics]` placeholder headers (containing only whitespace or `;` / `!:` comments), marking files `status = 'ineligible'` only when `[Fonts]` / `[Graphics]` contain actual non-comment embedded data, when mid-stream `Format:` changes occur after `Dialogue:`, when core sections appear out of order after `[Events]`, or when stateful shift encodings are used (bound to `algorithm_version`, `file_size`, and `modified_at` with `NULL` `compressed_events` so repeat `Index` runs skip rescanning unchanged ineligible files).
    - Aligns timestamp parsing (`ASSParser.milliseconds`) with `libass` to accept colon-separated fractional seconds (`0:01:23:45`) and `> 3` fractional digits (truncating beyond millisecond precision without integer overflow).
    - Retains all renderable `Dialogue:` events where `end_ms > start_ms` (including short-duration particle bursts and `\p1` vector drawings) in exact source-file line order, packed as 16-byte little-endian records (`[start_ms: Int32, end_ms: Int32, byte_offset: UInt32, byte_length: UInt32]`) compressed with `NSData.CompressionAlgorithm.zlib`, with `multipliedReportingOverflow(by: 16)` protection during both packing and unpacking.

- **Index-Only Persistence, Backfill & Lifecycle Maintenance (`SubtitleIndexer.swift`, `IndexingDatabase.swift`)**:
  - Wired `ASSEventOffsetIndexer.build` into `SubtitleIndexer` (with injectable `WebDAVSubtitleCache = .shared`) for all ASS/SSA files during both `.fullIndex` and lightweight `.supplementalMetadataRefresh` (when an upgraded pre-Schema-67 ASS/SSA row is missing a current `ass_event_offset_indexes` entry, backfilling it on the next `Index` without churning cues, FTS, facets, `CueID`s, or Excerpts).
  - Persisted rows via `upsertASSEventOffsetIndex` inside `publishLibraryIndex` and `replaceCueGroupsInCurrentTransaction`, and explicitly cleaned up rows in `removeIndexedDataInCurrentTransaction` and `deleteIndexedSubtitlePath` alongside `ON DELETE CASCADE`.
  - Keying by `subtitle_file_id` preserves binary offset index validity across in-App file-group and folder renames (`LibraryRenamer`) without re-indexing.

- **Read-Only Fingerprint Validation, Remote Cache Support & Coalesced Chunk Reading (`PlaybackSubtitleDatabase.swift`, `ASSEventOffsetIndex.swift`)**:
  - Exposed session-oriented read-only `validatedASSEventOffsetIndex(forSubtitleFile:...)` and `hasCurrentASSEventOffsetIndex(forSubtitleFile:fileSize:modifiedAt:)` on `PlaybackSubtitleDatabase` and `PlaybackSubtitleRenderCacheProviding`, with read-only SQLite connection reuse in `PlaybackSubtitleRenderCacheReader` so callers validate and `zlib`-decompress once per episode session and filter subsequent windows purely in memory (`overlappingEvents(in:)` / `activeEvents(atMilliseconds:)`).
  - Supported injectable `WebDAVSubtitleCache` (`.shared` by default) for remote media URLs (`http`/`https` WebDAV, `smb://`, `ftp://`, `nfs://`), validating local cached file existence and byte size against `storedFileSize` read-only with zero implicit network downloads or database writes.
  - Coalesced adjacent and nearby (`gap <= 32 KB`) `ASSEventByteRange` items into contiguous sequential `FileHandle` chunk reads in `readAndDecodeEventLines`, slicing in memory while strictly preserving the caller's original `eventRanges` order and guarding `byteOffset + byteLength` against integer overflow and EOF bounds.

- **Automated Tests (`DatabaseBootstrapTests.swift`, `ASSEventOffsetIndexTests.swift`, `ASSParserTests.swift`, `WebDAVSupportTests.swift`)**:
  - Verified fresh schema `67` creation and lossless `66 -> 67` migration across isolated `debug/CueSeeker.sqlite` and `release/CueSeeker.sqlite` fixtures without touching media files on disk.
  - Verified small and 5,001-event heavy particle ASS/SSA indexing without size threshold, 3,200-event coalesced chunk reading + arbitrary caller order preservation + overflow/EOF guards, remote cached subtitle validation/slicing across WebDAV/SMB/FTP/NFS (hit, cache miss, size mismatch, zero network I/O), `PlaybackSubtitleRenderCacheReader` connection reuse + decompression count overflow guards, empty `[Fonts]`/`[Graphics]` vs non-empty embedded data + `[Extradata]`/`[Project Garbage]` + `0:01:23:45` and `> 3` fractional digit timestamps, multi-encoding slicing, legacy backfill preserving `CueID` and Excerpts, external edit invalidation, file/folder removal cleanup, and in-App `LibraryRenamer` preservation.

## Verification

- `swift test --package-path apps/macos-native --filter "ASSEventOffsetIndexTests|ASSParserTests|WebDAVSupportTests|SMBSupportTests|FTPNFSSupportTests|DatabaseBootstrapTests"` — 75 tests passed, 0 failures.
- `swift test --package-path apps/macos-native --filter "SubtitleIndexerTests|LibraryRenameTests|FileDetailDatabaseTests|PlaybackRequestTests|CASSRenderingTests"` — 100 tests passed, 0 failures.
- `swift build --package-path apps/macos-native` — Build complete, 0 errors.
