# Shared Core Architecture Plan

Status: Accepted

Implementation status: Paused.

Rust shared-core implementation is paused while CueSeeker continues native
macOS product polishing. The accepted architecture direction remains valid, but
the project should not add new Rust shared-core scaffold, fixtures, FFI,
shadow-mode code, or production replacement until the project owner explicitly
restarts this migration.

During the pause, macOS code must still be written along future shared-core
boundaries. Durable product semantics should remain isolated in the macOS
product-domain layer so they can later move to Rust if Windows reuse makes that
necessary. SwiftUI/AppKit should own presentation and platform interaction;
native playback should own media execution; neither layer should become the only
place where database, indexing, Search, Library, Shiori, alias, or playback
intent semantics are enforced.

## Background

CueSeeker now has an active native macOS implementation and an early Windows
client bootstrap. The Windows bootstrap has shown that quickly recreating
database, indexing, Library, Search, Shiori, and playback-intent behavior in a
second app shell creates a high risk of product drift.

The goal of this proposal is to define a path where macOS and Windows can share
domain behavior without forcing a shared UI framework or a shared native
playback renderer.

This proposal does not change the accepted native-only playback direction. It
keeps macOS and Windows playback backends platform-native while moving product
semantics toward shared contracts and, where practical, shared source code.

## Goals

- Avoid implementing CueSeeker's core product behavior twice.
- Preserve native macOS UI and native Windows UI.
- Preserve platform-native playback backends.
- Treat the current macOS implementation as the behavioral baseline before
  shared-core migration begins.
- Define which macOS behavior must be retested when shared architecture changes
  land.
- Provide an incremental migration path that does not destabilize the current
  macOS app in one large rewrite.

## Non-goals

- Do not replace the native macOS app with a web UI or Tauri shell in this
  proposal.
- Do not replace the Windows WinUI 3 direction with a web UI in this proposal.
- Do not replace the macOS playback backend as part of the shared-core work.
- Do not replace the Windows native playback backend with `mpv`, VLC,
  GStreamer, or another third-party player framework.
- Do not make the shared core responsible for video decoding, native rendering,
  audio output, or platform window management.

## Accepted Direction

CueSeeker will move toward native UI per platform, a shared core for product
semantics, and platform-native playback backends.

Accepted rules:

- macOS keeps its native SwiftUI and AppKit shell.
- Windows keeps its native C# and WinUI 3 shell.
- macOS and Windows playback rendering, audio output, hardware decode,
  fullscreen, native surfaces, DPI behavior, and window management remain
  platform-specific.
- Shared core is the preferred home for database, indexing, Search, Library,
  Shiori, and playback-intent semantics.
- Rust is the preferred shared-core implementation language.
- The first shared-core migration phase is limited to database, folder
  indexing, subtitle parsing, subtitle-to-video matching, Search, Library,
  Shiori, and playback intent resolution.
- The first shared-core migration phase must not migrate native playback
  rendering, video decode, audio output, or native renderer surface ownership.
- The current macOS implementation is the behavioral fact standard until this
  proposal or a later accepted document explicitly changes the product
  semantics.
- Shared-core migration is macOS-first: macOS must complete shared-core
  validation and manual acceptance before Windows consumes the shared core as
  the product path.
- Windows architecture work should pause at the bootstrap boundary during the
  macOS shared-core migration, except for blocker-level playback or build fixes.

## Proposed Architecture

The preferred architecture is native UI per platform, shared core for product
semantics, and platform-native playback backends:

```text
macOS App
  SwiftUI and AppKit shell
  macOS-specific file access, windows, keyboard routing, and settings surface
  macOS native playback adapter

Windows App
  C# and WinUI 3 shell
  Windows-specific file access, windows, keyboard routing, and settings surface
  Windows native playback adapter

Shared Core
  Product-domain contracts
  SQLite schema and migrations
  Folder indexing
  Subtitle parsing and search projection
  Video/subtitle matching semantics
  Library presentation model
  Shiori domain model
  Playback intent, command, event, and failure contracts

Platform Playback Backends
  macOS: FFmpeg, VideoToolbox, native display, AVAudioEngine, libass
  Windows: FFmpeg, D3D11VA/DXVA, Direct3D, WASAPI, libass
```

The likely shared-core implementation language is Rust because it can expose a
stable C ABI to Swift and C#, can own SQLite and parsing code, and can be tested
with the same fixtures on both platforms. This proposal does not require moving
every module into Rust at once. The migration should be slice-by-slice and
fixture-driven.

## Boundary Rules

Shared core should own:

- Database schema versioning and migrations.
- Indexed folder configuration semantics.
- Subtitle scanning rules.
- Subtitle-to-video matching rules.
- SRT and ASS searchable cue parsing.
- Cue group and cue line projection.
- FTS query planning and line-level search validation.
- Library folder and video presentation snapshots.
- Library playback-history semantics.
- Shiori identity, persistence, and validity semantics.
- Playback target resolution from Search, Library, and Shiori.
- Versioned playback command, event, error, and report contracts.

Platform app shells should own:

- Native UI layout, visual design, and UX details.
- Native folder pickers and file-access permission flows.
- Settings window presentation.
- Keyboard event plumbing.
- Clipboard and platform integrations.
- Window, titlebar, fullscreen, DPI, and resize behavior.
- Calling the shared core and rendering returned view models.

Platform playback backends should own:

- Media open, demux, decode, render, audio output, and clock precision.
- Native video surface ownership and resize behavior.
- `libass` renderer integration and native overlay composition.
- Hardware decode probing and fallback implementation.
- Platform-specific playback diagnostics.

The shared core may define playback intent and command contracts, but it must
not render frames, own native windows, or depend on platform rendering APIs.

## macOS Current Behavioral Baseline

The current macOS implementation is the fact standard for shared-core migration
until this proposal or a later ADR changes the product semantics.

Primary reference files:

- `apps/macos-native/Sources/CueSeekerCore/SubtitleDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/SubtitleIndexer.swift`
- `apps/macos-native/Sources/CueSeekerCore/SubtitleFileScanner.swift`
- `apps/macos-native/Sources/CueSeekerCore/VideoMatcher.swift`
- `apps/macos-native/Sources/CueSeekerCore/SRTParser.swift`
- `apps/macos-native/Sources/CueSeekerCore/ASSParser.swift`
- `apps/macos-native/Sources/CueSeekerApp/AppState.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/PlaybackTypes.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/`
- `apps/macos-native/Tests/CueSeekerPlaybackTests/`

### Database

- The current native schema version is `15`.
- SQLite uses `PRAGMA user_version`.
- SQLite connections use WAL mode, synchronous normal, and a configured busy
  timeout.
- The schema includes `search_paths`, `subtitle_files`, `video_files`,
  `subtitle_video_matches`, `subtitle_cue_groups`, `subtitle_cue_lines`,
  `subtitle_cue_groups_fts`, `subtitle_cue_lines_fts`,
  `ass_render_segments`, `ass_font_resources`,
  `library_playback_history`, `library_video_rows`, and `shioris`.
- Derived subtitle index data is rebuildable.
- Shiori and Library playback history are durable user state and must survive
  indexed-folder removal.

### Folder Indexing

- Selected folders are loaded from user defaults and reconciled with the
  database at startup.
- Indexing adds the selected folder to `search_paths`.
- Subtitle scanning supports `.srt` and `.ass`.
- The scanner recurses under the selected folder, skips hidden files, skips
  symbolic-link directories, requires regular files, and sorts subtitle paths
  lexically.
- Indexing skips subtitle files that do not have a matched video.
- Indexing skips unchanged subtitle files when subtitle path metadata, file
  size, modification time, matched video path, and required ASS render segment
  cache state are unchanged.
- Reindexing removes stale derived entries under the indexed folder while
  preserving durable state.
- Indexing also prepares ASS font-resource manifests, indexes video duration,
  and rebuilds the persisted Library presentation snapshot.

### Subtitle-to-Video Matching

- Supported video extensions are `mp4`, `mkv`, `webm`, `avi`, and `mov`.
- Matching is same-directory basename matching.
- The first candidate is the full subtitle basename.
- The second candidate strips a simple language suffix matching
  `.[A-Za-z]{2,5}` or `.[A-Za-z]{2,5}-[A-Za-z]{2,5}`.
- Examples:
  - `Movie.srt` may match `Movie.mkv`.
  - `Movie.en.srt` may match `Movie.mp4`.
  - `Movie.scjp.ass` may match `Movie.mp4`.
- If no candidate video exists, the subtitle file is not indexed.

### SRT Parsing

- SRT parsing removes UTF-8 BOM, normalizes CRLF and CR newlines to LF, and
  splits blocks by blank lines.
- Sequence numbers are optional.
- Timecodes accept comma or dot millisecond separators.
- Invalid timecodes, invalid ranges, and empty text blocks are skipped.
- Each valid SRT block becomes one cue group with one cue line.

### ASS Parsing

- ASS parsing reads `[Script Info]`, `[V4+ Styles]`, and `[Events]`.
- Only `Dialogue:` events are indexed.
- Event field order is driven by the active `Format:` line.
- Invalid timecodes, invalid ranges, and empty cleaned text are skipped.
- Override blocks are removed from searchable text.
- `\N` and `\n` become newlines in searchable text.
- Cue groups are keyed by exact source file, exact start time, and exact end
  time. Near-equal timestamps are not grouped by tolerance.
- Cue lines preserve event index, source style, source layer, timing, cleaned
  content, and approximate display order.
- ASS display order is derived from inline `\pos`, `\move`, inline alignment,
  style alignment, style margins, event margins, and event index fallback.
- Group search content is the cue lines joined with newlines.
- Large ASS files at or above the documented segmentation threshold may produce
  derived render segments during indexing. Segmentation is a cache, not a
  rewrite of source semantics.

### Search

- Search uses SQLite FTS5 over cue-group search content.
- Indexed CJK characters are segmented for practical Han, hiragana, katakana,
  and halfwidth-katakana matching.
- Empty queries return no results.
- Explicit FTS syntax is passed to SQLite and then line-validated.
- CJK queries use phrase-style FTS candidate lookup plus substring validation
  against individual cue lines.
- Multi-token Latin queries use `AND` candidate lookup plus ordered whole-token
  validation against individual cue lines.
- Single-token Latin queries use prefix candidate lookup plus prefix validation
  against individual cue lines.
- A cue group must not match only because query terms are split across
  different cue lines.
- Search results are scoped to currently selected folders.
- Search results are sorted by friendly display title, subtitle path, start
  time, end time, and cue group id.
- File summaries are derived from the sorted result set and use the same
  friendly display-title ordering.

### Library

- Library is driven by indexed playable video metadata, not by UI-only grouping.
- Library startup hydrates from the persisted `library_video_rows` snapshot when
  the database is available.
- The Library snapshot groups videos by the matched video file's parent folder.
- Folder ordering uses Finder-like natural comparison by folder title, then
  folder path.
- Video ordering uses the current natural comparison helper in the macOS
  database layer.
- Duplicate video paths are folded to one Library video, selecting the
  naturally earliest subtitle path for that video.
- `library_video_rows.display_title` uses the folder title plus a one-based
  zero-padded sequence, such as `Show - 01`.
- Library folder collapse and expand state is current-session presentation
  state.
- Library playback history is keyed by video path and is written only for
  Library-launched playback sessions.
- Search-result playback must not read or overwrite Library playback history.

### Shiori

- Shiori rows are stored in `shioris`.
- Shiori identity is `subtitle_path`, `start_ms`, and `end_ms`.
- Creating Shiori for an existing cue updates associated metadata but does not
  create a duplicate row.
- Existing `created_at` is preserved on duplicate upsert.
- Removing an indexed folder removes derived search and Library rows but
  preserves Shiori rows.
- Playback Shiori toggling uses the active or nearest previous cue selection at
  the current playback timestamp.
- Shiori content uses cue-line text when available and falls back to group
  search content.

### Playback Intent

- Search result open selects the result, clears Library and Shiori selection,
  stops Library playback-history tracking, opens or seeks the matched video,
  seeks to the cue group's `start_ms`, and starts playback.
- If the selected Search result is in the currently open video, macOS prefers
  loading the subtitle source and seeking instead of reopening the video.
- Library video open clears Search and Shiori selection, starts from Library
  resume history or `0`, and starts Library playback-history tracking.
- Shiori open selects the Shiori record, clears Search and Library selection,
  opens or seeks the saved video, seeks to the saved `start_ms`, and starts
  playback.
- `PlaybackRequest` requires a local file URL, rejects missing video files, and
  clamps negative start times to `0`.
- ASS playback requests include the source ASS file, matched video URL, optional
  prepared font-resource directory, a bounded subtitle preparation time window,
  and the render-cache database URL.
- SRT playback may use indexed cue data for the app-owned simple subtitle track.
- ASS playback rendering uses the source-faithful `libass` path, not the
  database search projection.

## Migration Plan

## Recovery Plan After Scaffold Revert

Status: Active migration procedure.

The initial Rust scaffold and distributed fixture batch has been reverted. The
next shared-core attempt must restart from the macOS implementation at commit
`26a52f0` plus this documented procedure.

The reason for the restart is structural: isolated module fixtures can show that
small pieces are locally correct, but they cannot prove that the product path is
correct when indexing, database state, Library, Search, Shiori, playback intent,
and native playback behavior interact. During this migration, distributed
end-to-end checks are not an acceptance method. They may be used only as
debugging aids after a full vertical acceptance failure has identified the
failing domain.

### Recovery Rules

- Do not migrate playback runtime ownership into the shared core.
- Do not move video decode, audio output, frame queues, sample buffers, pixel
  buffers, renderer surfaces, fullscreen, DPI, resize, or per-frame subtitle
  rendering into Rust.
- Do not add a Rust shared-core implementation before the macOS control baseline
  has been captured.
- Do not accept isolated parser, matcher, Search, Library, Shiori, or playback
  intent tests as migration acceptance.
- Do not switch macOS production code to Rust until the full macOS vertical
  shadow run is equal to the Swift baseline.
- Windows must not consume the shared core until macOS has passed production
  replacement and manual acceptance.

### macOS Control Baseline

Before rebuilding the shared core, capture a control baseline from the current
native macOS implementation.

The baseline must include:

- A real fixture media folder that exercises SRT, ASS, language-suffix matching,
  Library rows, Search results, Shiori, and playback intent.
- A full data snapshot produced by one run of the current macOS path:
  scanning, matching, parsing, database writes, stale cleanup, Search, Library,
  Shiori, and playback intent.
- A native playback memory profile using the current macOS playback backend.
  The memory profile must cover continuous playback long enough to expose the
  historical leak pattern where memory rises every few seconds.
- The exact media file, decode mode, subtitle type, playback duration, sampling
  interval, starting memory, maximum memory, ending memory, and observed memory
  delta.

This baseline is the control group. Any future shared-core change that changes
the full data snapshot or worsens the playback memory profile fails migration
acceptance until the difference is explained and accepted.

### Full Vertical Snapshot

The primary acceptance artifact is one full vertical snapshot, not separate
module outputs.

The snapshot must be generated from one fixture folder and must include:

```text
selected folders
search paths
subtitle files
video files
subtitle-video matches
cue groups
cue lines
ASS render segment metadata
ASS font-resource manifest metadata
Search pages and file summaries
Library presentation rows
Library playback history rows
Shiori rows
playback intents for Search, Library, and Shiori actions
```

The Swift macOS implementation produces the baseline snapshot first. Rust may
only be accepted for a domain after the Rust path can reproduce the same full
vertical snapshot, or after an intentional product behavior change is documented
before implementation.

### Revised Phase Order

1. Capture the macOS control baseline and native playback memory profile.
2. Build a snapshot exporter for the current Swift macOS path.
3. Define the Rust shared-core boundary from the snapshot schema, not from
   isolated module convenience.
4. Implement Rust schema and migration support first.
5. Implement Rust folder indexing, including unchanged-file skip, stale cleanup,
   ASS render segment metadata, font-resource manifest metadata, and video
   metadata propagation.
6. Implement Rust Search, Library, Shiori, and playback intent against the same
   persistent database state.
7. Run Rust in macOS shadow mode and compare the full vertical snapshot against
   the Swift baseline.
8. Replace macOS production modules behind narrow adapters only after shadow
   equality is reached.
9. Re-run the native playback memory profile after each production replacement
   that can affect playback intent, subtitle source selection, ASS preparation,
   or app state routing.
10. Start Windows shared-core integration only after macOS production
    replacement and manual acceptance pass.

### Windows Scope After Shared Core

After the shared core is accepted through macOS, Windows should still implement
only platform-specific ownership:

- WinUI shell, navigation, panel state, and visual presentation.
- Windows file pickers, path permissions, settings storage, and process
  lifecycle.
- C#/WinUI adapters that call the shared core and map returned models to
  ViewModels.
- Windows native playback backend, renderer hosting, D3D surface ownership,
  fullscreen, DPI, WASAPI audio, and Windows `libass` overlay integration.
- Keyboard focus, shortcuts, logging, installer, signing, crash reporting, and
  Windows-specific diagnostics.

Windows must not independently implement database semantics, migrations,
indexing semantics, subtitle parsing semantics, subtitle-to-video matching,
Search semantics, Library semantics, Shiori semantics, or playback intent
semantics once those domains are accepted in the shared core.

### macOS-First Feature Development

After the shared core is accepted through macOS, macOS may continue as the
primary product development platform while Windows UI and UX work pauses for
WinUI research. Windows does not need to mirror every macOS feature immediately
during that pause, but Windows must not become a second independent source of
product semantics.

Every new feature must be classified before implementation:

- Product semantics must be implemented in the shared core first. This includes
  database state, indexing rules, matching rules, Search behavior, Library
  behavior, Shiori identity and persistence, alias contracts, and playback
  intent resolution.
- Platform UI and UX belong to the platform app shell. macOS layout, panel
  behavior, menus, animations, AppKit fullscreen behavior, and keyboard routing
  may be implemented in SwiftUI or AppKit without requiring immediate Windows
  UI work.
- Platform playback execution belongs to the platform playback backend. Video
  surfaces, hardware decode, audio output, ASS overlay lifecycle, fullscreen,
  DPI, resize, and playback memory lifecycle must remain outside the shared
  core.
- Cross-platform playback features should put only their durable product
  contract in the shared core. For example, a frame export feature may define an
  export intent, timestamp, subtitle source, and output contract in the shared
  core, while macOS and Windows execute the actual seek, decode, render,
  composite, encode, and file write through their native playback backends.

If a new feature contains product semantics that are not yet modeled by the
shared core, the shared-core contract and fixtures must be added before the
macOS production path relies on that behavior. Swift-only implementations are
acceptable only for platform-specific UI, platform integration, or native
playback execution.

When classification is unclear, document the boundary decision before
implementation. The default bias is to keep durable product meaning in the
shared core and keep presentation, windowing, and playback execution in the
platform layer.

### Memory Regression Gate

Playback memory is a platform-backend gate, not a shared-core domain. However,
shared-core migration can still fail this gate if it changes playback intent,
subtitle source selection, ASS preparation windows, Shiori opening, Library
resume behavior, or app state routing in a way that causes the native playback
backend to retain more resources.

Every macOS production replacement phase must answer:

- Did the native playback backend code change?
- Did playback intent or subtitle source selection change?
- Did ASS source, font-resource, render-cache, or preparation-window selection
  change?
- Did Search, Library, or Shiori selection routing change?
- Does the memory profile remain within the accepted control baseline?

If the answer to the final question is no, the migration step is rejected even
when all data snapshots match.

### Phase 0: Contract Freeze

- Document shared-core boundaries and macOS baseline behavior.
- Identify existing macOS tests that become cross-platform contract tests.
- Add small repository fixtures where needed for behavior that currently exists
  only in larger local media libraries.

### Phase 1: macOS Baseline Fixtures

- Convert the current macOS behavior into shared fixtures and expected outputs.
- Cover subtitle/video matching, SRT parsing, ASS parsing and grouping,
  indexing, Search, Library snapshots, Shiori identity, and playback intent.
- Keep these fixtures app-shell independent so they can later run against the
  Rust shared core, macOS adapters, and Windows adapters.

### Phase 2: Shared Core Scaffold

- Add a Rust shared-core workspace with tests that run without either app shell.
- Start with pure domain behavior and SQLite access.
- Expose a C ABI or other stable bridge only after the internal Rust API is
  covered by fixtures.
- Prefer JSON-compatible contract shapes at the app boundary during bootstrap
  unless a measured performance issue requires a more compact ABI.
- Keep per-frame playback data out of the shared core boundary.

### Phase 3: macOS Shadow Validation

- Move schema creation, migration, subtitle scanning, video matching, SRT/ASS
  parsing, indexing, Library snapshot generation, and Search behavior into the
  shared core.
- Add a macOS comparison path that can run the shared core against selected
  fixtures and compare results with the current Swift implementation.
- Do not switch the production macOS app module until the relevant fixture set
  is equal or an explicit product decision accepts a behavior change.
- Windows does not participate in manual acceptance during this phase.

### Phase 4: macOS Module Replacement

- Replace macOS modules behind narrow adapters, one responsibility at a time.
- Suggested order:
  1. Database migrations and schema access.
  2. Folder indexing and stale-entry cleanup.
  3. Search query and result grouping.
  4. Library snapshot hydration.
  5. Shiori persistence.
  6. Playback intent resolution.
- After each replacement, run the corresponding macOS automated regression
  tests and the scoped macOS manual smoke checks.

### Phase 5: macOS Product Acceptance

- Run the full macOS manual acceptance path after all first-phase shared-core
  modules are active in the macOS app.
- Confirm adding folders, indexing, Library display, Search, Search
  click-to-playback, Library playback resume, Shiori save/open/remove, Settings
  state isolation, and basic playback controls still behave as expected.
- Treat successful macOS acceptance as the point where the shared core becomes
  the product fact for the migrated domain modules.

### Phase 6: Windows Shared-Core Integration

- Resume Windows architecture work only after macOS acceptance.
- Remove or bypass Windows bootstrap implementations of database, indexing,
  Search, Library, Shiori, and playback-intent semantics.
- Wire WinUI Settings to shared-core folder management and indexing.
- Wire WinUI Library to shared-core Library snapshots.
- Wire WinUI Search to shared-core query and result contracts.
- Wire Search, Library, and Shiori actions through shared-core playback intent
  resolution, then pass the resolved request to the Windows native playback
  backend.
- Limit Windows manual acceptance at this stage to platform integration issues:
  paths, encoding, process lifetime, DPI, WinUI state, native renderer surface,
  D3D/WASAPI/libass playback, and Windows-specific failure reporting.

### Phase 7: Playback Contract Alignment

- Keep macOS and Windows playback backends separate.
- Define a shared playback command and event vocabulary.
- Make platform backends report comparable open, seek, play, pause, subtitle,
  decode-path, capability, and failure events.
- Keep native renderer resize, fullscreen, audio, and hardware decode behavior
  platform-specific.

## macOS Retest Requirements

Any change that touches shared core contracts, database semantics, indexing,
search, Library, Shiori, or playback intent resolution must trigger macOS
regression testing.

During the shared-core migration, the project owner should not need to perform
full manual acceptance on both platforms at every step. The required manual
acceptance platform is macOS until Phase 5 is complete. Windows manual
acceptance resumes in Phase 6, after the shared core has been accepted through
the macOS app.

### Required Automated Retests

- Fresh database migration reaches schema version `10` or the documented next
  schema version.
- Existing database migrations preserve selected folders, Shiori rows, and
  Library playback history.
- SQLite WAL, busy timeout, and synchronous mode remain as documented.
- Subtitle scanning preserves extension support, hidden-file behavior,
  symlink-directory behavior, and path sorting.
- Subtitle-to-video matching preserves exact basename and simple language-suffix
  behavior.
- SRT parsing preserves optional sequence numbers, newline normalization, comma
  and dot timecode parsing, and malformed-block skipping.
- ASS parsing preserves exact-time grouping, line ordering, cleaned searchable
  text, style/layer metadata, and layout projection.
- Indexing preserves stale-entry removal, unchanged-file skipping, skipped
  missing-video accounting, and unreadable-file accounting.
- Search preserves FTS behavior, CJK behavior, Latin prefix behavior, multi-token
  behavior, explicit FTS behavior, line-level validation, folder scoping,
  sorting, and file summaries.
- Library preserves deduplication, natural ordering, persisted snapshot
  hydration, display-title numbering, and duration propagation.
- Shiori preserves unique identity, duplicate upsert behavior, created-at
  preservation, removal, and survival across indexed-folder removal.
- Playback request tests preserve missing-file rejection, local-file requirement,
  start-time clamping, ASS source metadata, font-resource metadata, and
  preparation-window metadata.

### Required Manual macOS Smoke Tests

- Launch the macOS app with an existing database.
- Confirm Library is visible from the persisted snapshot before manual
  reindexing.
- Open Settings, add a folder, remove a folder, and run indexing.
- Confirm Settings does not clear Search, selected results, Shiori selection, or
  playback state.
- Search indexed subtitle text with Latin, CJK, and a multi-token query.
- Expand a grouped Search file and click a result.
- Confirm playback opens or seeks the matched video at the cue start time.
- Click another cue in the same video and confirm the app seeks instead of
  unnecessarily replacing the whole playback session when practical.
- Open a Library video and confirm resume behavior is Library-only.
- Save and remove Shiori from playback.
- Open a Shiori row and confirm it resolves to the saved video and cue time.
- Toggle side panels and enter or exit playback fullscreen when playback code or
  playback intent contracts are touched.

### Retest Scope by Change Type

- Database or migration changes require the full automated data-model suite and
  manual startup smoke test.
- Indexing or parser changes require scanning, matching, parser, index,
  Library, Search, Shiori-survival, and playback-intent smoke tests.
- Search-only changes require Search automated tests and manual grouped Search
  click-to-playback smoke tests.
- Library-only changes require Library snapshot, ordering, resume-history, and
  manual Library playback tests.
- Shiori-only changes require Shiori persistence tests and manual save, remove,
  and open tests.
- Playback backend-only changes require playback tests and manual playback
  smoke tests, but do not require full indexing retests unless playback intent
  or subtitle-source resolution changes.
- UI-only platform changes do not require shared-core retests unless they alter
  state ownership, command routing, or product semantics.

## Implementation Acceptance Criteria

The first shared-core migration phase is complete when:

- The shared core implements the accepted first-phase domain modules.
- macOS production code uses the shared core for the migrated modules.
- macOS automated regression tests pass for database, indexing, Search,
  Library, Shiori, and playback intent.
- macOS manual acceptance passes for the required smoke-test path.
- Any intentional behavior difference from the previous macOS implementation is
  documented before it becomes product behavior.
- Windows has not been required to carry parallel architecture acceptance during
  the macOS migration.

## Decision

Accepted.
