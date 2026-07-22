# Database Architecture Refactor

## Human-Owned Source

- `docs/human/requirements/20260722-Engineering-Subtitle Database Refactor And Schema 33 Baseline.md`

## Scope

Decompose the cross-domain `SubtitleDatabase` implementation while preserving
the schema-33 data layout and current product behavior. Retire compatibility
with native schema versions 1 through 32, establish explicit connection and
transaction ownership, move callers onto focused database-domain boundaries,
and remove the old God Object without a permanent forwarding facade.

## Steps

### 1. Accepted Engineering Direction

- Added the accepted database architecture decomposition proposal.
- Recorded schema 33 as the current and minimum supported native schema.
- Defined unsupported lower and higher schema behavior without silent deletion
  or version downgrading.
- Added stable architecture rules for bootstrap-only migration, serialized
  write ownership, read-only feature access, domain-specific persistence
  boundaries, and removal of the old facade.
- Recorded the accepted direction in the Unreleased changelog.

### 2. Schema 33 Compatibility Baseline

- Replaced the historical incremental migration path with one atomic schema-33
  creation transaction for empty databases.
- Made schema 33 validation idempotent and non-mutating.
- Added an explicit unsupported-version error for schema versions 1 through 32
  and versions newer than 33; rejection leaves `user_version` unchanged.
- Removed obsolete migration helpers, compatibility tests, and old-version test
  fixtures now that pre-33 databases are intentionally unsupported.

### 3. Bootstrap, Connection, And Transaction Ownership

- Added `DatabaseBootstrap` as the only production entry point that creates or
  validates the schema; feature code no longer calls migration directly.
- Added explicit read-only and read-write connection access. App background
  Search, Shiori, URL lookup, and Playback rendering readers now open SQLite in
  read-only/query-only mode and cannot create the database. Subtitle Focus uses
  an explicit writer because the same boundary saves Shiori relations.
- Removed migration work from `SubtitleIndexer`; App startup, tools, and test
  fixtures bootstrap before opening feature connections.
- Centralized immediate transaction begin/commit/rollback in `SQLiteDatabase`
  and serialized each complete transaction with a recursive connection lock.
- Replaced all business-level raw transaction-control SQL with the centralized
  transaction executor.

### 4. Domain Models, Schema Ownership, And Dead API Removal

- Moved Indexing, Search, Library, Shiori, Playback/ASS, AI cache, and
  Maintenance data contracts into seven focused source files.
- Moved all schema-33 validation and creation SQL into `DatabaseBootstrap`;
  `SubtitleDatabase` and tests no longer expose or call a migration method.
- Removed the empty Search result-cache invalidation API, its permanently-zero
  statistics model, misleading benchmark output, and tests coupled to those
  no-op interfaces.
- Reduced `SubtitleDatabase.swift` from the original 11,869 lines to 9,044
  lines before persistence operation extraction.

### 5. AI Cache And Maintenance Repositories

- Added `AIChunkCacheDatabase` and moved all AI cache validation, JSON coding,
  lookup, upsert, and invalidation operations out of `SubtitleDatabase`.
- Added `DatabaseMaintenanceDatabase` and moved connection diagnostics,
  storage statistics, WAL checkpointing, and compaction operations out of the
  God Object.
- Updated App maintenance tasks to open feature-owned read-only statistics
  connections and an explicit writer only for compaction.
- Updated App cache-reset behavior and tests to depend directly on the AI cache
  repository.
- Reduced `SubtitleDatabase.swift` further to 8,871 lines.

### 6. Playback Subtitle Data Boundary

- Added read-only-by-default `PlaybackSubtitleDatabase` for Cue timing,
  playback finish metadata, ASS render segments, ASS font references, and the
  remaining font-resource manifest read.
- Updated App playback preparation and Library completion tracking to use the
  focused playback repository.
- Updated subtitle indexing cache validation to query playback-derived data
  through the focused repository instead of retaining those reads on the God
  Object.
- Removed concrete `SubtitleDatabase` dependencies from `CueSeekerPlayback`.
  Cover and video-metadata indexers now accept minimal Sendable persistence
  protocols declared by the owning Library domain.
- Reduced `SubtitleDatabase.swift` further to 8,614 lines.

### 7. Search Query Planning Boundary

- Added the connection-free `SearchQueryPlanner` for query normalization, FTS
  expression generation, Latin/CJK token handling, result-line matching, and
  vocabulary diagnostic term extraction.
- Kept SQLite query execution in the database persistence layer while removing
  pure Search policy and text processing from the God Object.
- Added direct unit tests for Latin prefix, ordered-token, CJK, and vocabulary
  planning behavior.
- Reduced `SubtitleDatabase.swift` further to 8,344 lines.

### 8. Library Cover Repository

- Added `LibraryCoverDatabase` as the dedicated persistence owner for cover
  candidates, generated video/folder cover metadata, display renditions, and
  user-selected video/folder covers.
- Removed every Library Cover operation and its decoding/validation helpers
  from `SubtitleDatabase`; the old type no longer conforms to
  `LibraryCoverPersistence`.
- Updated App startup, indexing, display-rendition backfill, user-cover service,
  Playback cover indexers, and tests to use the focused repository directly.
- Reduced `SubtitleDatabase.swift` further to 7,893 lines.

### 9. Library Media Repository

- Added `LibraryDatabase` with independently owned Library video reads and
  video duration/codec/dimensions/frame-rate updates.
- Moved `PlaybackVideoMetadataPersistence` conformance from the old database
  type to the Library repository and updated App indexing to pass that focused
  dependency to `PlaybackVideoMetadataIndexer`.
- Removed the corresponding public operations from `SubtitleDatabase` while
  retaining its private snapshot rebuild query until Library presentation
  ownership moves.
- Reduced `SubtitleDatabase.swift` further to 7,778 lines.

### 10. Library Playback History Repository

- Moved playback-history reads/writes and explicit watch-state updates into
  `LibraryDatabase`, including video identity upsert and Library-relative path
  preservation.
- Updated the App's serialized playback-history writer and synchronous history
  reads to depend on `LibraryDatabase` instead of the old cross-domain type.
- Removed all public Library playback-history and watch-state operations from
  `SubtitleDatabase`.
- Reduced `SubtitleDatabase.swift` further to 7,611 lines.

### 11. Subtitle Focus Read Boundary

- Moved playback Cue selection, initial focus-window selection, ordinal lookup,
  paged Cue reads, and cancellation probes into `PlaybackSubtitleDatabase`.
- Updated the App focus reader to retain a read-only Playback repository for
  focus data and open the legacy writer only for the not-yet-extracted Shiori
  save operation.
- Removed all Subtitle Focus query methods, row selection types, and SQL helpers
  from `SubtitleDatabase`.
- Reduced `SubtitleDatabase.swift` further to 7,270 lines.

### 12. Shiori Tag Repository

- Added `ShioriDatabase` as the dedicated persistence owner for Shiori tag
  creation, lookup, assignment, removal, deletion, and validation.
- Updated App tag popover and mutation paths to use the focused repository
  instead of the cross-domain database type.
- Kept the existing resident snapshot behavior by composing tag data through a
  read-only Shiori connection.
- Removed the tag operations and their private SQL/validation helpers from
  `SubtitleDatabase`, reducing it further to 7,004 lines.

### 13. Shiori Core Persistence

- Moved Shiori Cue-identity upsert, lookup, and deletion into
  `ShioriDatabase`.
- Reduced the save contract to the Cue selection and creation time that are
  actually persisted, removing four unused subtitle/video arguments.
- Updated Subtitle Focus saving and App deletion to use the focused Shiori
  repository directly; the focus reader no longer opens the cross-domain
  database writer.
- Removed the corresponding operations from `SubtitleDatabase`, reducing it
  further to 6,906 lines.

### 14. Shiori Relationship Reads

- Moved Shiori list, relation, Cue-ID, and subtitle-time lookup operations into
  `ShioriDatabase`.
- Updated App context resolution and database-order playback navigation to use
  the focused Shiori repository.
- Made the remaining legacy resident snapshot compose both relations and tags
  through one read-only Shiori connection.
- Removed the relation decoder and corresponding public reads from
  `SubtitleDatabase`, reducing it further to 6,807 lines.

### 15. Shiori Collection And Navigation Reads

- Moved Shiori collection loading, total count, and adjacent-item navigation
  into `ShioriDatabase`.
- Updated App playlist sizing and fallback Shiori navigation to use the
  focused repository.
- Removed the legacy resolved-Shiori query and corresponding public operations
  from `SubtitleDatabase`, reducing it further to 6,729 lines.

### 16. Shiori Query Completion

- Added read-only `CueContentDatabase` for ordered canonical Cue content,
  including Cue Group lines, language resolution, and speaker assignments.
- Moved the production resident snapshot completely into `ShioriDatabase` and
  updated the App to open that focused read-only repository.
- Removed the database-level Shiori page/filter/index APIs because production
  now filters and pages the resident snapshot in memory; only obsolete tests
  referenced those APIs.
- Removed the retired Shiori page/index models and all Shiori table query
  helpers from `SubtitleDatabase`, reducing it further to 5,977 lines.

### 17. Library Presentation Repository

- Moved Library snapshot rebuilding, recent-watching presentation, complete
  Library summaries/details, and ready presentation reads into
  `LibraryDatabase`.
- Updated App Library hydration and post-index snapshot rebuilding to use the
  focused Library repository directly.
- Moved the remaining index-time video metadata refresh onto
  `LibraryDatabase`; `SubtitleIndexer` no longer calls a Library persistence
  operation through `SubtitleDatabase`.
- Removed the presentation queries, rebuild helpers, and Library sort helper
  from `SubtitleDatabase`, reducing it further to 5,297 lines.

## Verification

### Step 1

- Reviewed the committed human-owned requirement.
- Checked the proposal against the shared-core boundary and minimum sufficient
  design rules.
- Checked that this step changes documentation only and does not alter schema,
  source code, or runtime behavior.

### Step 2

- Ran the six focused schema-baseline tests covering fresh creation, current
  schema idempotence, lower/higher version rejection, and Shiori schema/index
  creation; all passed.
- Ran the complete 829-test Swift suite. Database coverage passed; one unrelated
  shared-preferences migration assertion failed in the combined run and passed
  immediately when rerun in isolation.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 3

- Built all Swift package products successfully.
- Ran seven focused bootstrap/read-only/transaction-path tests; all passed.
- Ran all 16 `SubtitleIndexerTests` after moving bootstrap ownership into the
  fixture boundary; all passed.
- Ran all 17 Playback Subtitle Focus keyboard-action tests after explicitly
  classifying its Shiori-saving connection as a writer; all passed.
- The first complete-suite run exposed the expected missing test-fixture
  bootstrap calls plus the previously observed unrelated shared-preferences
  test flake. The fixture boundary was corrected before the final suite run.
- The final 831-test suite passed all database, indexing, App, and Playback
  coverage. Its only failure was the same unrelated shared-preferences
  migration assertion, which has already passed when run in isolation.

### Step 4

- Built the complete package, including `SearchBench`, after moving the domain
  models and schema implementation.
- Ran 133 database and Subtitle Focus tests; all passed.
- Confirmed there are no remaining `.migrate()` calls and no Search cache API
  declarations or call sites.

### Step 5

- Built every package product after extracting both repositories.
- Ran eight focused AI cache, maintenance, App startup, and settings migration
  tests; all passed.

### Step 6

- Built every package product after extracting playback reads and protocol
  boundaries.
- Ran 27 focused Playback subtitle, ASS, Indexer, font-intent, and Library cover
  tests; all passed.
- Confirmed the `CueSeekerPlayback` target contains no concrete
  `SubtitleDatabase` type reference.

### Step 7

- Built all package products and test targets after extracting the Search query
  planner.
- Ran four direct planner tests and three Search database integration tests;
  all passed.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 8

- Built all package products and test targets after moving Library Cover
  ownership to its independent connection.
- Ran 28 Library Cover/Core/Playback tests and eight user-cover, startup
  backfill, and App snapshot tests; all passed.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 9

- Built every product and test target after extracting Library media reads and
  video metadata updates.
- Ran four focused Library media, indexing refresh, folder-removal, and App
  playback-navigation integration tests; all passed.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 10

- Built all products and test targets after moving playback history and watch
  state ownership.
- Ran ten focused Library history/recent-watching tests and seven playback
  completion, seeking, and natural-next-item regression tests; all passed.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 11

- Built every product and test target after moving Subtitle Focus reads onto
  the read-only Playback connection.
- Ran 112 Subtitle Focus database, cancellation, Cue selection, App session,
  keyboard, virtual-reel, and Shiori-action tests; all passed.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 12

- Built every product and test target after extracting Shiori tag persistence.
- Ran eight focused Shiori tag/schema/App model tests plus three Shiori
  persistence/remapping integration tests; all 11 passed.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 13

- Built every product and test target after moving Shiori core persistence.
- Ran the complete 58-test Shiori-named Core/App regression set; all passed.
- Confirmed Shiori Cue-identity upsert, lookup, and deletion are declared only
  on `ShioriDatabase`.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 14

- Built every product and test target after moving Shiori relationship reads.
- Ran the complete 58-test Shiori-named Core/App regression set; all passed.
- Confirmed Shiori list/relation/Cue-ID APIs are declared only on
  `ShioriDatabase`.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 15

- Built every product and test target after moving Shiori collection and
  navigation reads.
- Ran the complete 58-test Shiori-named Core/App regression set; all passed.
- Confirmed collection/count/adjacent APIs are declared only on
  `ShioriDatabase`.
- Ran `git diff --check`; no whitespace errors were reported.

### Step 16

- Built every product and test target after completing the Shiori query
  boundary.
- Ran 53 Shiori-named Core/App regression tests; all passed.
- Ran three focused CueContent ordering, resident snapshot, and CueID relation
  tests; all passed.
- Ran the complete 830-test Swift suite. Three concurrent timing-sensitive
  Shiori/native-playback tests failed in that loaded run and all three passed
  immediately when rerun together in isolation.
- Confirmed the old database type exposes no Shiori query operation and ran
  `git diff --check` without errors.

### Step 17

- Built every product and test target after extracting Library presentation
  persistence.
- Ran 89 Library- and recent-watching-named Core/App regression tests; all
  passed.
- Ran the complete 830-test Swift suite. Four concurrent timing-sensitive
  native-playback/Subtitle Focus tests failed in that loaded run and all four
  passed immediately when rerun together in isolation.
- Confirmed the moved Library presentation and snapshot operations are
  declared only on `LibraryDatabase` and ran `git diff --check` without errors.

## Outcome

Steps 1 through 17 match the requirement. The runtime now treats schema 33 as
its only supported existing database version, and schema creation, connection
access, transaction ownership, and domain data contracts have explicit
persistence-layer boundaries.

## Follow-ups

- Extract focused domain persistence APIs.
- Record each subsequent implementation and verification step in this file.
