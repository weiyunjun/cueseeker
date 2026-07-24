# Database Identity, Indexing, And Persistent Data Safety

## Human-Owned Source

- `docs/human/requirements/20260724-Engineering-Database Identity Indexing And Persistent Data Safety.md`

## Scope

Implement permanent resource identity, safe Library index publication, Cue
identity reconciliation, SRT-to-ASS rendering, referenced-Cue Tombstones, and
the Shiori lifecycle UI without using paths or display order as durable
identity.

## Steps

### 1. Schema 35 Foundation

- Added stable binding metadata for Libraries, folders, videos, and subtitles.
- Added Library folder IDs and per-Library index publication tokens.
- Added ASS identity-remainder storage, Cue Tombstones, one-generation change
  notices, and binding-conflict records.
- Removed the destructive Cue foreign-key cascade from Shiori while preserving
  Shiori IDs and tag assignments during migration.
- Updated the product data model and database schema rules.

### 2. Stable File Identity And Path Binding

- Added opaque platform resource identities for Libraries, folders, videos, and
  subtitles, plus complete SHA-256 fingerprints for subtitle copy/delete
  recovery.
- Preserved IDs across same-volume moves and renames while treating a new
  resource at an old path as a new object.
- Added unique-content subtitle rebinding, explicit multi-candidate conflicts,
  and a user-confirmed conflict resolution operation.
- Kept playback history and watch state attached to VideoID when paths move,
  and released the old path before a replacement video can acquire new state.
- Advanced the schema to 36 so generated and user-selected folder covers follow
  FolderID and cannot leak to a replacement folder at the old path.

### 3. Atomic Library Index Publication

- Separated filesystem scanning, subtitle reading, parsing, render preparation,
  and language analysis from database publication.
- Published all changed, unchanged, and stale-file decisions for one Library in
  one immediate transaction, rebuilding derived Search data only after the
  complete batch succeeds.
- Added monotonically increasing per-Library publication tokens so a stale scan
  cannot overwrite a newer result.
- Made unreadable roots, incomplete enumeration, unreadable files, malformed
  SRT blocks, and malformed ASS Dialogue records cancel publication while the
  previous successful Index remains active.

### 4. Cue Identity Reconciliation

- Added format-aware Cue reconciliation that locks exact matches before
  considering local edits and never uses Event Index or Display Order.
- Enforced ASS Style as a hard identity boundary and allowed inheritance only
  for an unambiguous single-part change among timestamp, cleaned text, and the
  canonical remaining Dialogue fields.
- Added canonical ASS remainder persistence for Layer, Name, margins, Effect,
  and any other non-time/non-text/non-Style Event fields.
- Kept unique SRT one-to-one edits on the original CueID while assigning new
  CueIDs to ambiguous same-time multi-edit results.
- Preserved CueID, Shiori relations, tags, and speaker assignments across
  accepted edits and file moves; added one-successful-index text-change
  notices.
- Advanced the Cue indexing algorithm version to 4 so existing subtitle files
  are reconciled through the new rules.

### 5. SRT To ASS / libass Rendering

- Added a rendering-only SRT parse path that preserves duplicate and short
  subtitle blocks without changing database-level Cue deduplication.
- Converted the complete SRT track into ASS Dialogues with the confirmed IINA
  default Style before passing it to libass.
- Routed SRT playback, subtitle refresh, and subtitle screenshot export through
  the same libass pipeline while leaving native ASS Styles unchanged.
- Submitted simultaneous SRT blocks together for libass collision handling and
  removed the former one-Cue-at-a-time text renderer.
- Rendered SRT against the full playback viewport so fullscreen letterbox
  placement and window-size scaling follow the confirmed defaults.

### 6. Referenced Cue And Shiori Lifecycle

- Retained Tombstones only for Cues referenced by Shiori, removed the last
  unreferenced Tombstone with its final Shiori, and restored the original CueID
  when the same Cue returned.
- Preserved exact multiline Primary Cue and Cue Group snapshots, time ranges,
  display metadata, ASS identity fields, and current resource state without
  accumulating one Tombstone per index revision.
- Distinguished unavailable Library, video, subtitle, combined file, and Cue
  states; restored missing-video bindings only when platform resource identity
  proves that the original object returned.
- Hid confirmed unavailable videos from current Library, Search, and Recent
  projections while preserving playback history, watch state, covers, and
  Shiori records.
- Added Shiori Content Changed and Unavailable indicators, anchored hover tips,
  muted unavailable rows, read-only tags, state-aware row actions, and exact
  snapshot copy behavior.
- Kept Copy Cue Text, Copy Cue Group Text, Copy Time Range, Remove Shiori, and
  conditionally Open Subtitle Folder available while blocking Play, Context,
  Move, and Duplicate for unavailable rows.
- Excluded unavailable Shiori rows from Playback result reels and navigation
  without removing them from table results, counts, or Library cover badges.

### 7. Incremental Index Publication

- Split subtitle-content changes from video-binding and video-metadata changes
  so an unchanged subtitle never enters parsing or Cue reconciliation.
- Batched video matching by directory and retained only lightweight file
  metadata checks for change discovery.
- Rebuilt Search Order and Library presentation rows only for affected folders;
  changed subtitle files continue to replace only their own FTS rows.
- Scoped video metadata inspection, generated covers, display renditions, and
  folder-cover reference updates to affected videos and folders.
- Deferred Search, Library, Playback, and Shiori invalidation until publication
  reports an actual change. A no-op Index now preserves resident UI state.
- Kept one-successful-index Cue change notices as a targeted lifecycle write;
  their removal refreshes Shiori without triggering unrelated media or Search
  work.
- Retained full empty-derived-table cleanup only when all active Libraries have
  been removed, where no unchanged indexed resources remain.

## Verification

- `swift build`
  - Passed.
- `swift test --filter 'SubtitleIndexerTests|VideoMatcherTests|LibraryDatabaseTests'`
  - 55 tests passed.
  - Covered no-op publication without Cue, FTS, Search Order, or video writes;
    one-folder mutation isolation; video-only metadata changes; scoped cover
    queries; and batched video matching.
- `swift test --filter 'SearchDatabaseTests|IndexingDatabaseTests|LibraryCoverDisplayRenditionTests|DatabaseMaintenanceTests'`
  - 66 Search, Indexing Database, and display-rendition tests passed in the
    concurrent run.
  - The maintenance test was affected by concurrent database load and passed
    when rerun independently.
- `swift test --filter 'LibraryFolderRemovalTests|CueGroupRefreshScopeIntegrationTests'`
  - 22 tests passed.
  - Covered no-op Index preservation of loaded Search state and delayed
    invalidation after a confirmed content removal.
- `swift test --filter preservesCueLineSpeakersWhenReplacingCueGroups`
  - 1 test passed after aligning its stale assertion with the human-owned rule
    that an exact Cue match preserves CueID.
- `swift test --filter DatabaseBootstrapTests`
  - 13 tests passed.
  - Covered fresh schema creation, schema 33 and 34 migration, Shiori/tag
    preservation, and removal of the destructive Cue foreign key.
- `swift test --filter IndexingDatabaseTests`
  - 16 tests passed.
  - Covered Library/folder/media moves, path replacement, unique and ambiguous
    subtitle copies, user-confirmed rebinding, playback history isolation, and
    folder-cover isolation.
- `swift test --filter LibraryDatabaseTests`
  - 18 tests passed.
- `swift test --filter SubtitleIndexerTests`
  - 23 tests passed.
  - Covered whole-Library rollback after an injected mid-publication failure,
    malformed-subtitle rollback, stale-token rejection, unchanged-file
    handling, stable ASS identities after adding another Style, ambiguous SRT
    replacements, one-index change notices, successful SRT/ASS publication,
    referenced-Cue Tombstones, exact ASS Cue Group snapshots, missing-resource
    state transitions, current-result hiding, and CueID restoration.
- `swift test --filter SubtitleFileScannerTests`
  - 2 tests passed.
  - Covered recursive supported-file discovery and rejection of an invalid
    Library root.
- `swift test --filter SRTParserTests`
  - 6 tests passed.
  - Covered rendering preservation of duplicate and short blocks, exact IINA
    Style defaults, and multiline Dialogue conversion.
- `swift test --filter ASSParserTests`
  - 7 tests passed.
- `swift test --filter CueIdentityReconcilerTests`
  - 4 tests passed.
  - Covered Event Index/Display Order exclusion, ASS Style and single-part
    boundaries, exact-first SRT matching, and ambiguous SRT replacement.
- `swift test --filter ShioriDatabaseTests`
  - 13 tests passed.
  - Covered CueID, Shiori ID, tag, and metadata preservation after an accepted
    content edit.
- `swift test --filter CASSRenderingProbeTests`
  - 8 tests passed.
  - Covered complete converted SRT tracks and simultaneous blocks rendering
    through libass.
- `swift test --filter PlaybackSubtitleRefreshLifecycleTests`
  - 1 test passed.
  - Covered SRT playback-source construction and speaker-display metadata.
- `swift test --filter PlaybackRequestTests`
  - 30 tests passed.
- `swift test --filter SubtitleScreenshotExporterTests`
  - 6 tests passed.
- `swift test --filter SearchDatabaseTests`
  - 45 tests passed.
- `swift test --filter DatabaseMaintenanceTests`
  - 1 test passed.
- `swift test --filter TableSandboxRowModelStoreTests`
  - 37 tests passed.
  - Covered exact unavailable snapshots, Content Changed and Unavailable row
    state, and exclusion of unavailable rows only from Playback scope.
- `swift test --filter SubtitleTableRowActionMenuTests`
  - 10 tests passed.
  - Covered state-specific action availability, status symbols, and
    right-first/left-fallback Hover Tip placement.
- `swift test --filter SubtitleTableVirtualRowTests`
  - 91 tests passed.
  - Covered unavailable Cue and Tag pointer behavior plus state-aware menu
    dispatch without regressing the existing virtual table interaction suite.
- `swift test --filter SubtitleTableClipboardTests`
  - 12 tests passed.
- `swift test --filter LibraryFolderRemovalTests`
  - 7 tests passed.
  - Covered preservation of an unavailable Shiori row while canonical live Cue
    content is removed with the Library index.
- `swift test --filter ShioriPresentationTests`
  - 3 tests passed.
- `swift test --filter PlaybackEntryAndShioriNavigationTests`
  - 6 tests passed.
- `swift test --filter PlaybackShioriOverlayTests`
  - 6 tests passed.
- `swift test`
  - Ran 887 tests.
  - The concurrent run reported 18 issues across 11 tests under aggregate
    media, AppKit, and database load.
  - The Speaker test exposed one stale expectation and passed after it was
    aligned with the accepted exact-Cue identity rule.
  - The remaining 10 media/UI/database timing tests passed either in their
    affected group or when rerun individually. The changed indexing, Search,
    Library, Shiori lifecycle, and cover suites listed above passed
    independently.

## Result

- Implementation is complete.
- No reproducible regression remains in the changed areas. The full concurrent
  suite still exposes pre-existing timing sensitivity under aggregate load.
