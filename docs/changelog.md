# Changelog

All notable milestone-level project changes are recorded in this file.

This changelog does not replace Git history. Git records concrete file changes. This file records meaningful project progress and milestone outcomes.

## Unreleased

- Accepted and closed Playback Quick Search chunk actions: the current
  sentence row now provides `/chunk` or `/rechunk` plus `/copy`, copies only the
  displayed sentence, and maps selected AI chunks back to the sentence with an
  opacity-only focus treatment that preserves text layout.
- Completed AI Chunking multi-plan merge: the default prompt now requests one
  to three Japanese chunking plans, old saved prompt templates are reset to the
  new contract once, responses validate each plan against the normalized
  sentence, invalid plans are ignored unless all plans fail, valid plans merge
  by splitting the first valid plan with later-plan chunks, and final results
  de-duplicate by sentence position so repeated text at different positions is
  preserved.
- Completed the AI Chunking settings work: Experimental Features now supports
  persisted Translation Language and prompt-template settings, validates
  required `{{sentence}}` / `{{language}}` placeholders before saving, disables
  those controls when AI Chunking is off, logs request duration plus rendered
  request and raw response content, scopes cache entries by translation
  language, clears historical AI Chunking cache data once for the new strategy,
  and keeps prompt edits from invalidating existing language-scoped cache
  entries.
- Accepted the Playback Quick Search chunk count consistency fix: selected
  chunk counts now reuse Search exact totals, run in the background after AI
  chunks render, ignore stale count completions while switching chunks, display
  `xx results`, and resolve the API result count mismatch bug.
- Accepted stricter change traceability rules: AI-performed code and
  documentation changes outside `docs/human/` now require committed
  human-owned requirement or design coverage, an engineering implementation
  record, and commit messages that cite the relevant `docs/human/` path.
- Fixed first-pass Anki export media generation so ffmpeg writes audio and
  image assets through typed temporary filenames before packaging them into
  Anki's extensionless media slots.
- Implemented first-pass Anki export in the native App: Search and Shiori group
  headers now expose a compact `square.and.arrow.up` export action that opens a
  save panel and silently writes `.apkg` packages with Audio/Image/Text cards.
- Accepted the first-pass Anki export scope: Search and Shiori group headers
  can export loaded subtitle moments to `.apkg` decks named
  `CueSeeker::<group display title>`, with one Audio/Image/Text card per row and
  no metadata fields in the initial template.
- Updated Git workflow direction: `main` is now the active integration branch,
  `native-macos-rewrite` and `ui/restructure` are retired for new work, and
  major features should use `feature/<short-topic>` branches from `main`.
- Playback overlay panel visibility now persists across launches and defaults
  to hidden on first use, so the video page opens without the right-side
  Search Results / Subtitles panel unless the user restores it.
- Accepted the current `ui/restructure` Swift-first UI alignment as complete
  for this stage and ready for owner-controlled merge to `main`. The accepted
  native App direction includes the cinematic bottom player, modal timeline
  scrubbing, feedback HUD/sidebar icons, and the right-aligned playback
  overlay panel with a transparent-track fixed-width scrollbar thumb. Remaining
  pixel-level visual details are deferred to later work and are not blockers
  for this phase.
- Fixed Player-UI and cursor idle handling so physical pointer movement while
  dragging with any mouse button keeps the playback chrome and cursor visible
  instead of letting the three-second idle timer fire mid-drag.
- Revised Phase 1.5.4 timeline dragging to defer thumbnail and full-size
  keyframe preview research. Timeline dragging now pauses playback, keeps the
  video surface on its pre-drag frame, skips keyframe preview, thumbnail
  generation, and realtime seek work during the drag, then commits the final
  seek while restoring the prior play/pause state.
- Implemented Phase 1.5.3 shared timeline scrub time display. The progress
  scrubber now publishes its active drag target through playback state, the
  bottom-player time label reads that shared scrub time while dragging, and the
  scrubber hides the white hover-ahead segment during modal scrubbing because
  the drag target is already the active progress position.
- Implemented Phase 1.5.2 timeline-scrubbing interaction gating. Dragging the
  progress scrubber now raises shared modal scrubbing state, suppresses
  non-Timeline playback keyboard shortcuts, closes and blocks the speed menu,
  and prevents bottom-player buttons, volume controls, speed controls, and time
  chrome from showing hover/pressed behavior or firing actions until scrubbing
  ends.
- Accepted the Phase 1.5 timeline scrubbing contract for the cinematic player:
  pressing the Timeline Zone now defines a modal scrubbing interaction where
  playback is paused, non-Timeline shortcuts/buttons/menus are suppressed,
  progress and time labels follow the drag target immediately, the video
  surface remains unchanged during the drag, ordinary read-ahead is not
  advanced by scrub-preview work, and mouse release commits the final precise
  seek while restoring the prior playback state when appropriate. Thumbnail and
  full-size keyframe preview remain future research rather than current Phase
  1.5 scope.
- Completed the cinematic player bottom controls bar refinement (Phase 1 of the `ui/restructure`
  branch). Resolved the critical color visibility and contrast issues on transparent bottom bar
  layouts by transitioning base capsule backings and scrubber timelines from translucent white
  to translucent black (`capsuleFill` at `0.30` opacity and `scrubberTrackBackground` at `0.60`
  opacity), which adaptive-mixes as sleek, highly visible grey on white video frames while
  blending cleanly and framelessly on black video stages. Refined concentric inner hover
  highlights using `Color.white.opacity(0.16)` (`capsuleHoverFill`), and aligned the speed
  popover settings menu items' hover, pressed, and selected backgrounds to a unified
  `menuItemHighlight` (`0.12` opacity white) for absolute visual identity. Implemented vertical
  coordinate Y-clamping for the settings popover within `speedMenuOverlay` to lock the bottom of
  the card tightly next to the progress bar (2.0px safety gap when hovered), completely
  eliminating visual overlap or scrubber hover gesture interference. Verified by `swift build`
  and all 95 native unit tests passing with zero regressions under bypassed compiler sandboxing.
- Updated the UI collaboration workflow to Swift-first during the active native
  UI restructure. Native SwiftUI/AppKit implementation is now authoritative;
  HTML prototypes are reference artifacts and no longer block approved App UI
  implementation, while stable component and UX mapping documents are
  synchronized when accepted Swift behavior becomes stable direction.
- Added the four general AI assistant execution principles to the Git workflow
  rules: think before coding, simplicity first, surgical changes, and
  goal-driven execution.
- Completed the UI view-file split (Phase 2 of the `ui/restructure`
  branch). The three remaining large SwiftUI view files were broken up:
  `PlaybackPageView.swift` (1699 lines) became a 113-line `PlaybackPage.swift`
  shell plus 13 focused files under `Playback/{Chrome,TopBar,Sidebar,Feedback}/`;
  `SearchView.swift` (1214 lines) became a 662-line top-level mode dispatch
  plus 7 files under `Search/{Library,Results,Shiori}/`; `SettingsView.swift`
  (850 lines) became a 126-line shell + category switcher plus 6
  `SettingsXxxCategory` files. 2.a and 2.b were pure file-level moves with
  `private` widened to `internal` only where a moved type now lives in a
  different file from its callers. 2.c required actual restructuring
  because the categories were inline `xxxSettingsContent` computed
  properties on `SettingsView`, not standalone structs; each category
  became its own struct that declares its own `@EnvironmentObject`s,
  owns its own `@State` (folder-removal + folder-picker state moved to
  Library; compact-confirmation state moved to Maintenance), hosts its own
  `.alert`, and carries its private helpers. The shell file
  `SettingsView.swift` lost the now-unused `appState` / `indexing` /
  `search` / `library` env objects and the `AppKit` / `CueSeekerCore` /
  `CueSeekerPlayback` imports. 29 atomic commits across 2.a + 2.b + 2.c,
  each with `swift build` + `swift test` 95/95 + `git diff --check` clean
  + owner E2E regression + Codex per-block code review. The branch
  `ui/restructure` stays open for follow-up UI alignment work; no merge
  back to `main` at this time per owner decision.
- Completed the UI invalidation-domain restructure (Phase 1 of the
  `ui/restructure` branch). The 3.7k-line `AppState` god object was split
  into a thin `AppCoordinator` plus seven per-domain stores —
  `SettingsStore`, `IndexingStore`, `WorkbenchLayoutState`, `ShioriStore`,
  `LibraryStore`, `SearchStore`, `PlaybackStore` — each owning the
  `@Published` state for one domain. `AppCoordinator` retains only
  cross-domain orchestration methods and a single app-level
  `startupError`; per-domain mutation now scopes SwiftUI invalidation to
  the relevant store's subscribers instead of fanning out across the
  workbench. Views that read AppCoordinator computed properties which
  compose multiple store states must observe each underlying store
  explicitly, since AppCoordinator does not republish child changes.
  `docs/engineering/04_architecture_rules.md` §7 was updated to record
  the new shape and the observation requirement. Phase 1 file
  reorganization (`Sources/CueSeekerApp/{App,Workbench,Library,Search,
  Playback,Shiori,Settings,Media,Shared,Diagnostics}/`) was completed in
  the same branch. Build clean, `swift test` 95/95.
- Completed the info-page / video-page refactor (video-page Phase 1
  structural stage, steps S1–S7). The app is now an info page (Library /
  Search / Shiori) plus a dedicated full-window video page layered above the
  still-alive info page; closing returns to the originating info-page mode
  with state intact. A custom video-page top bar provides app-semantic
  traffic-light controls (close = return to info page, minimize to Dock,
  green = fullscreen) with the native traffic lights suppressed; in
  fullscreen the native titlebar takes over and its close runs the app-close
  semantic without quitting.
- Replaced the squeeze sidebar with a centered overlay panel that never
  resizes the video stage, hosting Search Results and Subtitles with
  click-to-seek; its show/hide is driven only by the bottom-bar toggle, never
  auto-hides, animates ~180 ms, and is outside the serialized resize gate. The
  feedback HUD renders above the panel; dark-mode panel and segmented styling
  were corrected.
- Structurally resolved the playback fullscreen jank and converged ADR-0011:
  the dedicated video page removes the relayout that fought the fullscreen
  Space animation, so the `69861f2` render-sync band-aid was removed in full
  across all four layers (S5). ADR-0011 is marked Superseded by ADR-0013.
- Verified by `swift test` (94/94) and a full end-to-end functional
  regression on the project owner's real machine (navigation/return, top bar,
  fullscreen, v4 Player-UI/cursor, overlay panel, seek and shortcut
  invariants, preserved non-UI behavior). Memory/CPU diagnosis was
  deliberately deferred to after the full UI rebuild by project-owner
  decision and is not part of this milestone. The only remaining net-new UI
  stage is the Phase 5 info-page card-visual rebuild, planned as its own new
  independent proposal.
- Phase 5 info-page card-visual rebuild — completed and accepted
  (2026-05-20). Search, Library, and Shiori main cards, group headers,
  the results header, the topbar, and the info-page background were rebuilt
  onto the shared v6 Liquid Glass token skin and the single
  `LiquidGlassSelectableCard`; all retained playback-selection visuals were
  removed from main cards (finding F). The Library episode grid became a
  content-driven `EPnn` wrapping flow whose only retained state is the doc 12
  §7.2 Library-launched playing indicator (a mandated playing state, not a
  selection visual). The dead Shiori legacy row cluster and the orphaned
  `SearchLayout` were retired (~196 dead lines removed from `SearchView`).
  Done doc-first throughout: v6 prototype → doc 11/12 mapping → confirmed
  pixel spec → owner-confirmed P5.3/P5.4 decisions (Search/Library content
  padding unified, episode width content-driven, no Library group hairline,
  `EP01` label). Verified by `swift test` (94/94) and `swift build` green at
  every sub-step plus a code-level cross-surface audit (no retained selection
  visuals, empty/loading/failed/no-results routing intact, colorScheme-driven
  dark mode with no hardcoded light values, architecture §7 invalidation and
  lazy-group boundaries preserved, seek / native-render path untouched), and
  the project-owner real-machine end-to-end regression plus the prototype
  visual acceptance for P5.3 / P5.4 passed (2026-05-20). Phase 5 is closed;
  this completes the info-page card-visual rebuild proposal.
- Implemented the v4 Player-UI / cursor visibility model in the macOS playback
  page so fullscreen entry forces hidden states, fullscreen exit does not
  reveal chrome by itself, and non-player focus such as Settings no longer
  counts as player focus.
- Formalized the v4 Player-UI / cursor visibility rules: Player focus is now
  separate from App focus, Player UI state and cursor state are documented
  independently, and cursor visibility is decided by the current player only
  while the cursor is governed by that player.
- Corrected the v4 Player-UI hidden-state rule so governed mouse movement
  reveals Player UI, while cursor visibility remains governed by the separate
  cursor-state rules.
- Documented the next playback fullscreen repair plan: make fullscreen an
  explicit player state machine, bind video-only presentation to AppKit
  lifecycle callbacks, add native render-view transition hooks, and treat
  Metal/`CAMetalLayer` as future display-layer research only if the current
  `AVSampleBufferDisplayLayer` path still freezes after those fixes.
- Removed the obsolete dedicated playback fullscreen window code path now that
  playback fullscreen is routed through the main workbench window.
- Hid the custom topbar during playback fullscreen and let the playback page
  occupy the fullscreen window from the top edge.
- Routed playback fullscreen through the existing workbench window so the
  playback render surface remains in the main window hierarchy during the
  fullscreen minimum loop.
- Defined the second playback fullscreen repair step: route playback fullscreen
  through the existing workbench window, keep the render container in that
  window hierarchy, and accept Cmd-Tab return to the fullscreen video surface as
  the minimum-loop validation.
- Resumed implementation of the main-window playback fullscreen ADR: fullscreen
  repair now targets one AppKit fullscreen workbench window, no dedicated
  playback fullscreen window, and no cross-window playback render-view movement
  before detailed player-chrome visibility work continues.
- Required App interface implementation to follow a fixed synchronization
  order: update the HTML prototype first, then the Liquid Glass component and
  UX mapping documents, and only then modify native App code after explicit
  App implementation approval.
- Updated the `cueseeker-liquid-glass-v5` expanded playback prototype so the
  bottom player behaves like playback chrome: entering the black video base
  reveals it, leaving hides it, and three seconds of inactivity inside the
  black base hides it again without animating horizontal geometry.
- Added the `cueseeker-liquid-glass-v5` HTML review fork for expanded playback
  video geometry, including a visible aspect-ratio video frame and dynamic
  aspect-fit positioning inside the black video base.
- Added the accepted App-side Appearance settings category and updated expanded
  playback layout rules so the right playback side panel owns a full-height
  column while the video and bottom player occupy the left column.
- Required each HTML prototype edit to refresh a same-directory
  `standalone.html` bundled export so the current prototype can be handed to
  other AI tools without extra packaging.
- Added the split-source `ui/prototypes/cueseeker-liquid-glass-v4/` prototype
  directory, preserving the v3 visual result while moving editable HTML, CSS,
  and JavaScript into separate source files.
- Updated the UI collaboration workflow so editable prototypes use normal
  `index.html`, `styles.css`, and `script.js` source directories, with
  standalone bundled HTML generated only as a share artifact for other AI tools.
- Added the `cueseeker-liquid-glass-v3.html` review fork for prototype-only
  theme and disabled-state controls, restored distinct capsule/transport
  control classes, and documented that those test controls are not App UI.
- Standardized HTML prototype naming so broad review forks use a stable name
  plus version number instead of semantic change names.
- Updated toggle icon button rules so selected state uses the matching filled
  glyph in addition to selected material and foreground contrast.
- Required large-scale HTML prototype changes to fork a new versioned prototype
  source directory so before and after designs remain directly comparable
  during UI review.
- Added UI collaboration rules for concept-first component vocabulary, required
  element classification, and explicit scope clarification for element-specific
  versus class-wide UI changes.
- Clarified the Liquid Glass control taxonomy: circular icon buttons, capsule
  buttons, selected toggle states, pressed scaling, and rounded-rectangle
  pop-up menu containers are now documented as the current UI baseline.
- Documented the current Liquid Glass HTML prototype as the visual baseline for
  the main workbench, grouped Search results, Search-launched playback overlay,
  playback side panel, bottom player, and related native App differences.
- Accepted the UI collaboration workflow: local HTML prototypes now live under
  the repository-level `ui/` directory and must be visually aligned before App
  interface implementation begins.
- Clarified Search result-cache invalidation rationale: indexed ASS files are
  mutable, not append-only, so subtitle edits can change matches, ordering,
  counts, summaries, and cursor pages; successful index mutations therefore
  clear cached Search pages instead of patching them incrementally.
- Recorded the future Search result-rendering optimization plan. The suspended
  Step 16 scope now explicitly targets the results content area below the
  `Found` label, with candidate work for precomputed highlights, reduced
  result-group invalidation, UI lifecycle instrumentation, and viewport
  windowing validation.
- Implemented Search Step 17 query/result caching. Bounded Search pages are
  cached in memory by query, scope, cursor, limit, and mode; indexed-content
  mutations clear the cache, and `SearchBench` now reports cache hit/miss stats
  before clearing its in-process cache.
- Suspended Search Step 16 UI virtualization/windowing validation. The idea is
  retained for dedicated front-end instrumentation and E2E scrolling evidence,
  but it no longer blocks the final Search cache step.
- Decoupled Search's UI page limit from exact-count candidate scanning. Search
  still returns first-page and lazy-load pages of `100` results, while exact
  completion scans candidates in larger internal batches to reduce broad-query
  completion latency.
- Suspended Search Steps 10, 11, and 12. The Step 11 Latin prefix-index code was
  reverted after benchmark review because its benefit was limited to narrow
  English visible-window cases and did not address the main exact-count cost.
- Implemented Search Step 9 index-sorted early termination. Schema version 13
  rebuilds FTS rowids in display-title product Search order, Search reads
  candidates with `ORDER BY f.rowid`, and exact Search no longer performs an
  extra Swift-side sort after scanning candidates.
- Implemented Search Step 8 exact progress count streaming. Background exact
  completion now publishes exact completed-work count updates to the Search
  summary and lightweight JSONL `search_count_progress` records without
  creating empty visible file groups.
- Isolated the topbar Search input draft from Search result state. Searches can
  continue updating results and exact counts without overwriting the user's
  active Search-field editing or IME marked text.
- Removed Search's hidden runtime fallback for missing materialized order rows.
  Search now requires `subtitle_search_order_rows` in the hot path and fails
  when rebuildable ordering data is missing instead of recomputing display
  titles as an old-data compatibility branch.
- Added a database engineering rule that old-data handling must be explicit and
  documented; rebuildable derived data should not keep hidden runtime
  compatibility fallbacks in hot paths.
- Added Search Step 6 materialized ordering. Schema version 12 now maintains
  `subtitle_search_order_rows` so Search can reuse precomputed subtitle display
  order, and Search E2E JSONL schema version 6 reports whether sorting used
  materialized order diagnostics.
- Revised Search follow-up Step 8 from delayed counts to exact progress counts:
  visible `Found` updates may advance during Search, but must always represent
  exact completed-work counts and final exact full-corpus totals.
- Added Step 5 Search `fts5vocab` diagnostics. `SubtitleDatabase` now exposes
  explicit FTS vocabulary metrics, `SearchBench` prints them only when
  `CUESEEKER_BENCH_FTS_VOCAB=1` is set, Settings > Developer shows a default-on
  `FTS Vocabulary Diagnostics` switch plus inline vocabulary data, and the
  follow-up plan records the exact-count benchmark plus query-term vocabulary
  data.
- Reverted Search visible counts to exact-only semantics. Core Search pages,
  AppState, SearchBench, tests, and E2E docs no longer use provisional Search
  metadata or background exact-count completion; `Found <count> results in
  <count> files` now represents complete exact counts.
- Added Search-layer pagination cursor acceptance rules and implemented an
  explicit Search continuation cursor in Core, AppState, benchmark output, and
  Search E2E JSONL logs.
- Implemented the Search result presentation state model: Searching and
  Initial states now show only loaded non-empty file groups, `Collapse All` is
  disabled while Search is loading, and Collapsed state uses an all-file alias
  view with per-file lazy loading.
- Documented the Search result presentation state model: Searching and Initial
  states may show only file aliases backed by loaded rows, while Collapsed
  state is the explicit all-file collapsed view used by `Collapse All`.
- Fixed Search file-group toggling so a summary-only group with no loaded rows
  loads its subtitle rows on the first click instead of collapsing first.
- Added Search Step 1 benchmark-gap observability. Search E2E JSONL now records
  file-group preview milestones, exact-count completion, and per-file load-more
  timings; `SearchBench --step1-gaps` prints matching machine-readable metrics.
- Reworked Search E2E logging into a single JSONL benchmark stream. Completed
  Search records now expose `query`, `warmupMilliseconds`, `returned`,
  `totalCount`, `fileSummaries`, `hotAvgMilliseconds`, and `hotRawMilliseconds`
  at the top level, with the separate readable summary log removed.
- Kept Search E2E JSONL lightweight by default: records now keep benchmark
  fields, `hasMore`, timings, and small result/file-summary samples instead of
  storing complete Search result pages.
- Added default-on Developer settings control for local Search E2E JSONL logs.
  Each Search run can now write machine-readable Search evidence plus
  first-visible result evidence for manual E2E testing.
- Recorded the current post-rollback Search Gate A baseline benchmark at
  commit `fe8d09a`, using `SearchBench` against the local schema 11 database
  for `大丈夫`, `今日`, and `の`.
- Reordered the Search optimization backlog so backend, diagnostics, state
  model, index, and maintenance work happen before front-end combined display
  work, while keeping query/result cache as the final implementation step.
- Clarified the Search optimization end-to-end gate: manual app verification
  must search `大丈夫`, `今日`, and `の` in order, follow documented wait and
  scroll counts, and record per-query acceptance evidence before a step is
  accepted.
- Revised the Search optimization workflow: the active plan now starts with
  three-query baseline data, keeps unstable diagnostics in logs or benchmark
  output instead of front-end UI, and requires automated plus end-to-end
  evidence before each implementation step can be accepted.
- Documented the corrected stepwise Search optimization backlog with per-step
  acceptance data and explicit exclusions for line-level/hybrid FTS,
  `ORDER BY` / `LIMIT` index support, and playback overlay lazy loading.
- Rolled back the Search optimization sequence implementation to the
  pre-optimization baseline after the visible "first page" metric proved
  misaligned with the desired user experience. The Developer Settings category
  remains as a reserved diagnostics surface while Search diagnostics are
  realigned around ASS-file-first rendering.
- Opened a new Socratic Search alignment round. The new evaluation target is
  time until the first matching ASS file's results render, plus time until all
  results are complete; the previous hybrid cue-line FTS path remains excluded
  because benchmark data already showed it was a negative optimization.
- Added a Developer Settings category for local diagnostics. The concrete FTS
  vocabulary and first/full summary diagnostics were removed with the Search
  rollback and will be rebuilt against the new measurement model.
- Added the eighth accepted Search optimization-sequence step as diagnostics:
  Core and `SearchBench` can now inspect SQLite `fts5vocab` data for cue-group
  FTS, making high-frequency query terms and possible index pollution visible
  before later FTS maintenance or tokenizer changes.
- Implemented the seventh accepted Search optimization step: schema version 19
  stores unindexed filterable, sortable, and presentation attributes directly
  in cue-group FTS rows, letting Search build candidates from FTS without
  joining subtitle, video, and search-order tables on the hot path. The measured
  complete metadata benchmark improved for `今日` and `の`, while first-page
  timings stayed roughly flat.
- Implemented the sixth accepted Search optimization step: schema version 18
  rebuilds cue-group FTS rows so FTS `rowid` follows materialized product
  order, and Search now uses `ORDER BY f.rowid` for index-sorted early
  termination. The measured `の` first-page benchmark improved from `43.10 ms`
  to `8.93 ms`, and complete metadata improved from `830.48 ms` to `572.56 ms`.
- Investigated and rejected the `ORDER BY` / `LIMIT` index-support optimization
  for the current SQLite FTS path. A database-copy experiment removed the
  temporary sort from the query plan but turned the measured `の LIMIT 1001`
  case into a severe regression, so no product code change was made for that
  step.
- Implemented the next accepted Search optimization pass: visible Search pages
  can now return an ordered first page with deferred exact metadata, so large
  result sets no longer block first results on full total-count and file-summary
  computation. The macOS app refreshes exact metadata in the background, and
  `SearchBench` can benchmark deferred metadata mode.
- Rolled back the cue-line/hybrid FTS search path after benchmark data showed
  it was a negative optimization. Schema version 17 now returns Search to
  cue-group FTS recall while preserving materialized subtitle result ordering
  and line-level validation for multi-line cue groups.
- Tightened AI interaction rules: benchmark regressions must be reported and
  paused instead of silently reinterpreted, mitigated, or carried forward
  without explicit user approval.
- Implemented the second accepted Search optimization step: schema version 16
  materializes subtitle search order rows during index snapshot rebuilds so
  search can use precomputed folder/file/time order and skip the expensive
  Swift display-title sort when the snapshot is complete.
- Recorded the failed first Search optimization step: schema versions 12
  through 15 attempted cue-line and hybrid FTS recall, but benchmark data did
  not support keeping that path for the speed goal.
- Recorded the Socratic Search performance strategy direction: the likely
  optimization path is line-level FTS recall mapped to display time windows,
  materialized Library/file/time ordering, and ordered block/file-level early
  result emission, with lower-level FTS tuning treated as supporting work.
- Accepted the Search optimization execution workflow: benchmark `大丈夫`,
  `今日`, and `の` five times each before code changes and after each
  optimization step, implement accepted optimizations in order, keep
  query/result cache last, and preserve raw benchmark timings for comparison.
- Exposed `SearchBench` as a Swift package executable so search optimization
  passes can run the same local benchmark harness after each step.
- Implemented the first database storage maintenance pass in the native macOS
  app: Settings now exposes local database storage stats, highlights
  reclaimable SQLite freelist space, and offers a manual `Compact Database`
  action that checkpoints WAL, runs `VACUUM`, and refreshes the visible stats
  after completion.
- Added a chronicle documentation track for explicitly started Socratic
  architecture alignment sessions, so implementation ideas discovered through
  iterative questioning can preserve their reasoning provenance separately from
  Git history, proposals, ADRs, and milestone changelog outcomes.
- Accepted an AI Socratic architecture alignment workflow: when the user starts
  an iterative architecture questioning session, the assistant should answer
  narrowly, emphasize key conclusions, surface evidence and uncertainty, keep
  continuity across narrowing questions, and avoid file modifications unless the
  user explicitly changes the session into a modification request.
- Recorded the product philosophy behind CueSeeker as a local subtitle corpus
  workbench rooted in loved source material, fansub and fan-creation community
  respect, raw learning material, local-first boundaries, and non-AI
  search-to-context workflows.
- Implemented the second UI layout pass in the native macOS app: Search results
  now render as grouped cards in the main content area, Shiori uses the same
  grouped-card surface, Library and Shiori move to icon buttons beside the
  topbar Search field, and the previous Mode Rail / resizable content-panel
  sidebar path has been removed from the visible workbench. Card subtitles now
  show complete cue text, cards in the same row align to one row height, and
  unreliable inferred episode labels are omitted from card metadata.
- Implemented the first bottom-player playback pass in the native macOS app:
  the current shell now reserves a persistent light bottom player with real
  play/pause, progress seek, volume, subtitle, Shiori, speed, fullscreen,
  Search-result navigation, Library episode navigation, and secondary playback
  actions, and the main video surface now delegates playback controls to the
  bottom player instead of showing the previous inline control bar. Search
  results now open playback in a bottom-launched overlay window, collapsed video
  pauses playback, and the bottom player uses the resolved playback display
  title with middle truncation. The overlay now sizes to the source video
  aspect ratio without app-added black margins, and bottom-player popover menus
  open directly above their buttons without shifting controls, close on outside
  clicks, keep video expand/collapse commands serialized during the active
  layout animation, and keep the video expand control available after collapse.
- Refined the card Search and bottom-player HTML prototype direction: topbar
  Library and Shiori now use icon-only navigation without selected emphasis,
  the bottom player uses a light gray rounded surface, drops cover art for a
  video-window expand control, aligns right-side controls with current playback
  functions, uses a gray rounded speed menu, includes a Library view demo,
  documents Shiori as using the same basic grouped-card layout as Search, and
  moves secondary playback actions behind a three-dot menu after the
  next-episode control.
- Clarified the AI frontend UI workflow rule: HTML prototypes and references
  are alignment aids, so when an HTML reference conflicts with the current
  implemented UI or documented product direction, the assistant must confirm
  the conflict with the user before implementation.
- Accepted an AI frontend UI workflow rule: before major visually or
  structurally ambiguous frontend UI modifications, the assistant must consult
  the relevant HTML prototype or reference when one exists, and must explicitly
  remind the user before implementation when no relevant HTML reference exists.
- Added an Experimental Features settings direction: Search result thumbnails
  are now documented as an opt-in experimental feature that is disabled by
  default and must not request or generate images while disabled.
- Accepted and implemented the first Search result thumbnail test direction:
  loaded Search result pages use 100 cue-group rows, rows may show fixed-size
  left preview thumbnails generated as persistent-cache `160x90` AVIF images
  from cue midpoint timestamps via `ffmpeg`, and unloaded rows use a
  skeleton-style picture placeholder instead of black or gray blocks.
- Accepted a concise AI response rule: unless the user explicitly asks for a
  detailed explanation, assistant answers should stay brief, clear, and
  highlight the key conclusions in bold.
- Accepted the strict local-file boundary for CueSeeker indexing and playback:
  the app may process supported video files and `.srt`/`.ass` subtitle files,
  but must ignore fonts, images, loose text sidecars, archives, sidecar asset
  folders, and non-playback media attachments unless a future documented
  product feature explicitly expands the file surface. ASS playback now relies
  on source `.ass` content and system-installed fonts rather than app-owned
  external font caches.
- Fixed paused-seek playback toggling so Space or surface click can pause after
  a seek auto-resumes playback, and centered the topbar Search field without a
  visible `CueSeeker` title.
- Updated Search-launched playback so context drawers appear as video overlays,
  pause playback when opened, scroll to the selected context, and Search submit
  pauses playback before leaving the playback page.
- Expanded playback context overlays to fill the video area and made the
  `Results` overlay use the same grouped result content as the Search results
  page.
- Added `A` and `D` playback shortcuts for Previous Result and Next Result.
- Accepted the topbar Search single-page workflow direction: the first Search
  UI pass will add a fixed-width topbar Search field that submits only on
  Return, show submitted results in the main content area without a duplicate
  Search field, open Search-launched playback from result selection, preserve
  source video aspect ratio with command space below, and navigate
  Previous/Next through the complete active Search result order. Library,
  Shiori, and Settings remain in their current surfaces until later migration
  work.
- Accepted ADR-0011 for playback fullscreen: CueSeeker will replace the
  dedicated playback fullscreen window with main-window video-only presentation
  using AppKit native fullscreen behavior. The new direction keeps the playback
  render container out of cross-window movement, preserves workbench state while
  hidden, and treats ordinary app fullscreen and playback fullscreen as distinct
  states. Implementation is deferred until explicitly restarted; ADR-0011 now
  records the custom titlebar, traffic-light, side-panel animation, SwiftUI
  state-retention, overlay duplication, cursor, and remaining video-stutter risks
  that must be accepted before code changes resume.
- Accepted a Layout settings category with a `Sidebar Position` preference.
  The default `Left` layout keeps `Mode Rail - Shared Content Panel - Playback
  Area`; choosing `Right` moves the side controls to `Playback Area - Shared
  Content Panel - Mode Rail` without resetting current workbench state.
- Accepted a bottom Settings action in the fixed Mode Rail. The button mirrors
  the app-menu Settings command, opens or focuses the independent Settings
  window, and is not a workbench panel mode.
- Accepted the fixed Mode Rail and shared content panel workbench layout:
  Library, Search, and Shiori now belong behind a non-resizable left Mode Rail,
  render inside one resizable Shared Content Panel, preserve panel width across
  mode switches, use the previous Search minimum width (`420pt`) as the shared
  default/minimum, and remove the current right-side panel plus titlebar
  side-panel controls from the accepted layout direction.
- Added persistent Search timing diagnostics for development builds: every
  Search request records query, database, state assignment, grouping, status,
  first visible result-row timing, and internal `searchPage` database phases
  into project-local, one-line logs under `logs/search-timing/`, with explicit
  diagnostic flag enablement for non-development diagnostic runs.
- Recorded the current Search performance follow-up as deferred work: a
  high-result CJK Search case spends most of its measured app time inside
  `SubtitleDatabase.searchPage`, especially result sorting, and should be
  optimized later without blocking unrelated feature development.
- Accepted the shared-core architecture direction: CueSeeker will keep native
  macOS and Windows UI shells, keep playback rendering platform-native, prefer
  Rust for shared product-domain behavior, and limit the first shared-core
  migration phase to database, indexing, Search, Library, Shiori, and playback
  intent. The migration is macOS-first, so Windows architecture-level shared
  core integration resumes only after the migrated behavior passes macOS
  production acceptance.
- Rejected the right-sidebar Show / Episode / Hit three-level grouping that
  shipped in commit `9a49d8e` after a same-cycle review. Two structural
  reasons drove the revert: the parent-folder Show layer is redundant header
  chrome in a search context (the matched cue text is what users scan, the
  subtitle file alias plus content is enough, and not every subtitle file has
  matches so the Show layer is partially populated and unstable), and
  aggregating a season's worth of matches under one heading creates render
  and attention problems that the existing flat layout already handles via
  the global `Collapse All` control. The proposal at
  `docs/proposals/2026-05-right-sidebar-show-episode-grouping.md` is
  preserved as Rejected with a revision note for context.
- Retained the row visual updates introduced alongside the rejected
  proposal: Search and Shiori result rows drop the cue start timestamp;
  selected rows use the macOS system accent color (`Color.accentColor`)
  with white text; keyword highlights use a three-state token set
  (`#FFE066` default, `#FFCB1F` hover, `30%` white on selected) that
  follows the parent row state. Disclosure chevrons in the right-sidebar
  group rail and the Library folder header are unified to a single-icon
  rotation animation (`0°↔90°` over `160ms`).
- Moved the Library folder disclosure chevron to the left of the folder
  row to match the right-sidebar group disclosure rail. The shared
  left-side chevron position expresses a unified disclosure language
  across both sidebars even though Library drives top-down navigation
  and the search panel drives bottom-up keyword discovery.
- Redesigned the Search field to match the design spec: a `6pt` rounded
  pill with a `1pt` separator border by default; on focus a `1.5pt`
  accent inner stroke plus a `3pt` accent outer ring at `18%` opacity. A
  constant `3pt` outer padding prevents layout jitter when focus toggles.
  Internal padding is `8pt` horizontal and `6pt` vertical, with `6pt`
  gap between the leading magnifying glass, input, and trailing clear
  glyph (both `13pt`).
- Reserved scrollbar position uniformly across both sidebars. The
  Library list and the right-sidebar Search/Shiori lists each apply a
  `16pt` trailing inset to their scrollable container, and each pane
  header uses a matching `28pt` total trailing padding (`12pt` content
  margin plus the `16pt` reserve) so list rows align with their
  surrounding header chrome and visual left/right margins remain equal
  when the scrollbar appears.
- Accepted the revised Library row direction: Library folder rows drop the
  leading first-letter avatar, use a two-line layout with an
  `N episodes`/`N episodes · Playing M` subtitle, and toggle expand or collapse
  on full-row click. Expanded folders display a numbered episode-button grid
  whose column count adapts to the Library panel width and uses three states
  only (default, hover, playing). The `Playing M` indicator and the playing
  episode highlight are scoped strictly to playback launched through Library;
  Search-result and other playback surfaces do not toggle them. Expanding a
  folder containing the Library-launched playing video auto-scrolls that
  episode button into view.
- Implemented the first native Shiori workflow: schema version 10 persists
  saved subtitle cues, playback can save or remove Shiori with UI feedback, the
  `S` key triggers the same action, and the right-side Shiori panel lists saved
  rows grouped by subtitle file.
- Accepted the initial Shiori feature direction: Shiori replaces the previous
  saved-content naming, saves the current subtitle cue from playback with `S` or the
  playback Shiori control, persists a real-world save timestamp, confirms removal
  for already saved cues, and presents grouped Shiori rows in the right-side
  learning panel with a fixed `Collapse All` control.
- Fixed top bar UI toggle button "instant snap" bugs during side-panel animations
  by explicitly driving layout geometry with a global `withAnimation` transaction
  instead of relying on local implicit modifiers that drop frames inside `GeometryReader`.
- Symmetrized the left side-panel toggle button in macOS fullscreen mode to dynamically
  match the right side's edge padding when traffic light controls are hidden.
- Adjusted side-panel toggle buttons to snap perfectly flush (0px inner padding)
  against the vertical divider lines when panels are expanded.
- Unified and increased top bar `modeButtonSpacing` to 18px for better visual proportion
  across both the left Library and right Search/Shiori tab groups.
- Accepted the stricter Library snapshot and workbench invalidation rule:
  Library rows are persisted indexed-resource presentation loaded at startup as
  a ready snapshot, while Library disclosure state, Search Panel visibility, and
  Search focus are presentation changes that must not regenerate Library rows.
- Accepted and implemented the ADR-0010 playback fullscreen path: playback now
  moves the singleton native render container into a dedicated playback window
  that enters AppKit native Full Screen Space, superseding the borderless
  Theater Mode mechanism that came from the removed `libmpv` playback era.
  Fullscreen transitions hide the playback window's traffic light buttons and
  no longer leave a fake black placeholder in the embedded Playback Area.
- Fixed native playback layout synchronization during workbench side-panel
  animations: the embedded playback card no longer relies on a separate SwiftUI
  black background, and the native render host/container/display layer now
  synchronously applies layout without implicit CALayer frame animations.
- Implemented the second workbench UI invalidation cleanup: playback controls
  now read a rate-limited displayed playback time while the view model keeps a
  more precise internal playback time for resume history, relative seeking, and
  subtitle text selection. Native video playback and source-faithful ASS timing
  remain on their existing timing paths.
- Reworked the native workbench side panels to use a drawer-style animation:
  Library and Search keep fixed-width content while only their layout slot
  opens or closes, preventing side-panel text from being squeezed and
  remeasured during collapse or expand animations.
- Implemented the first workbench UI invalidation cleanup: Library and Search
  presentation groups are now cached and rebuilt only through their relevant
  data/collapse mutation paths, and hiding either side panel keeps the panel
  subtree alive instead of removing and recreating the large list view.
- Implemented the revised Library view-state behavior in the native app:
  Library folder groups no longer load from or write to persisted collapse
  state, startup and Library data refresh collapse all groups by default, and
  reindex clears affected Library/Search/playback state before rebuilding.
  Library/Search result row buttons also opt out of macOS focus rings intended
  for keyboard-focused controls.
- Accepted the derived index decoupling principle: rebuildable local index rows
  may become stale or be recreated, but durable user state such as Library
  playback history and future Shiori records should remain intact and show
  unavailable or unbound resource states when their current index binding is
  missing.
- Accepted the revised Library view-state rule: Library group collapse state is
  current-session presentation state only, app startup and Library refresh or
  reindex should present all groups collapsed, and reindex should refresh
  Library plus rerun the active Search query while clearing playback that uses
  media under the folder being rebuilt.
- Implemented SQLite locking reliability in the native app: SQLite connections
  now use a busy timeout plus WAL journal mode, and indexing cancels app-owned
  Library/Search read tasks before starting write-heavy work to reduce
  self-inflicted lock contention.
- Accepted the SQLite locking reliability direction: app-owned database
  connections should use a non-zero busy timeout, the production database should
  use WAL journal mode, indexing should avoid self-inflicted read/write
  contention where practical, and valid large ASS render-segment cache rows
  should not be treated as the root cause of `database is locked` failures.
- Accepted the CueSeeker workbench responsiveness boundary direction: Library,
  Playback, and Search should have separate invalidation domains; side-panel
  collapse should preserve large list state; Library and Search presentation
  rows should be cached derived state; playback-control time updates may be
  rate-limited without affecting native video playback; and ASS timing-source
  refactoring is deferred from the first UI invalidation cleanup.
- Implemented instant Library startup hydration in the native app: startup now
  loads persisted indexed Library videos synchronously from SQLite during
  `AppState` initialization, before the first main-window state is presented,
  using an indexed path-prefix range query while later refreshes continue to
  reconcile the same state path.
- Accepted the instant Library startup hydration rule: when indexed Library rows
  already exist locally, app restart must hydrate the Library list before the
  first visible main-window render instead of showing a transient empty or
  loading Library panel.
- Implemented the CueSeeker workbench Library persistence changes in the native
  app: the old visible `Search` navigation label is gone, the main title reads
  `CueSeeker`, the left titlebar control toggles Library, Library defaults to a
  resizable `310pt` panel, folder collapse state persists, and schema version 8
  stores resume history only for Library-opened playback.
- Accepted the CueSeeker workbench and Library persistence direction: remove
  the standalone `Search` navigation label, title the main workbench
  `CueSeeker`, let the left titlebar control collapse or expand Library, make
  Library resizable with a `310pt` default/minimum width, persist Library
  folder state, and persist resume history only for Library-opened playback.
- Implemented the first native left-side Library panel for the Search
  workspace: indexed videos now appear in flat collapsible folder groups with
  Finder-like natural sorting, extension-aware friendly titles, duration
  metadata populated during reindexing, and click-to-playback from `0`.
- Accepted the first left-side Library panel direction: Library should use a
  fixed gray left content panel, flat collapsible folder groups, Finder-like
  natural sorting, friendly video rows with extension and duration, and
  click-to-playback from `0`.
- Implemented the standalone Settings window in the native app: the App menu
  now exposes `Settings...`, the main sidebar no longer includes Settings, and
  the Settings window provides `Library` and `Decode` categories for subtitle
  folder management and playback decode mode.
- Accepted the standalone Settings window direction: Settings should open from
  `CueSeeker > Settings...`, use an independent two-column window with
  `Library` and `Decode` categories, and no longer be owned by the main-window
  AppShell sidebar.
- Implemented the player-first Search workspace layout in the native app:
  playback now occupies the left side of Search, Search controls and grouped
  results live in a collapsible right-side Search Panel, hiding that panel no
  longer pauses playback, and the titlebar's right toggle now controls Search
  Panel visibility.
- Accepted the content-navigation and learning-panel model: the leftmost
  AppShell sidebar remains main-window navigation, future left content panels
  should handle Library and Timeline-style precise location, and the right
  learning panel should handle Search, Shiori, Queue, and configurable
  learning-session workflows without changing the accepted player-first Search
  workspace swap.
- Accepted the player-first Search workspace layout: the leftmost app sidebar
  remains outside the Search workspace, while Search itself moves playback to
  the left and Search controls/results to a collapsible right-side Search Panel
  that does not pause playback when hidden.
- Implemented Playback Inspector file-location buttons: the video panel now
  shows `Video Folder` and `Subtitle Folder` buttons with folder icons that ask
  Finder to reveal and select the matched files.
- Accepted the Playback Inspector file-location action update: read-only Start
  Time, Video Path, and Subtitle Path metadata should be replaced by `Video
  Folder` and `Subtitle Folder` buttons that reveal the selected files in
  Finder.
- Implemented friendly Search result group titles by deriving display titles
  from the immediate parent folder name and the subtitle file's non-recursive
  Finder-like rank among same-extension regular sibling subtitle files, while
  falling back to raw filenames when derivation is unavailable.
- Accepted friendly Search result group titles: result headers should display
  the immediate parent folder name plus the subtitle file's Finder-like
  natural-sort rank among same-extension sibling subtitle files, such as
  `葬送的芙莉莲 - 05`, while preserving full subtitle paths for identity,
  playback, and diagnostics.
- Implemented index-stage ASS font-resource manifests for the libass-only
  playback path: schema version 7 records prepared font cache status, Index Now
  materializes conventional adjacent font folders and supported container font
  attachments into a cache directory, and playback only passes the prepared
  directory to `libass` without scanning or extracting fonts on the subtitle
  load path.
- Accepted the ASS font-resource plumbing rule for the libass-only playback
  path: ASS playback must carry matched-video font context into `libass`, cover
  adjacent font folders and video container font attachments, preserve that
  context for indexed render segments, and document release handling for
  extracted font caches.
- Clarified the next grouped Search header count presentation: per-file totals
  should be appended as plain text after the subtitle filename, using
  `1 result` or `N results`, without reintroducing a badge or separate count UI.
- Refined accepted Search result text contrast: subtitle rows and right-side
  timestamps now share the same color within each selection state, selected rows
  use primary text on the macOS unemphasized selection background, and
  unselected rows use a softer primary text opacity while preserving the
  existing yellow query highlight strengths.
- Accepted the grouped Search result row visual refresh: selected rows now use
  the macOS unemphasized gray selection background, row divider lines are
  removed, query highlights use separate selected and unselected yellow
  strengths, and wrapped subtitle lines use additional spacing for bilingual
  readability.
- Removed the native ASS renderer route from active playback: ASS playback now
  uses the `libass` source-faithful overlay only, Settings no longer exposes an
  ASS renderer selector, PlaybackSyncProbe reports the libass path, and ADR-0009
  now records libass-only ASS rendering as the accepted direction. The unused
  ASS Lite playback renderer code was removed from the production target as
  part of the same single-renderer cleanup.
- Refined grouped Search visual presentation: subtitle-file headers now show a
  disclosure triangle and full wrapping filename without a per-file count badge,
  result rows show the start timestamp on the right, selected rows use a gray
  background with primary text, and row/header alignment now follows separate
  disclosure, filename, and selected-background edges.
- Standardized grouped Search controls in English and aligned Search focus
  styling with the selected-row gray treatment, including a thicker gray focus
  outline on the Search field.
- Added temporary Search diagnostics beside the result count to show the current
  rendered result-row count while grouped lazy loading is being validated.
- Clarified grouped Search lazy-loading rules: per-file totals remain true in
  search state, initial and incremental global rendering use 100-result
  batches, expanding all reveals one global batch, and expanding a subtitle-file
  header reveals at most that file's first 100 rows.
- Updated grouped Search result implementation to use 100-result lazy-loading
  batches, added the collapse or expand-all control beside the result count, and
  kept collapse actions disconnected from search loading.
- Updated the grouped Search result requirements to use 100-result lazy-loading
  batches and to add a native collapse or expand-all control beside the result
  count.
- Implemented grouped Search result presentation by subtitle file, including
  total result counts, per-file match totals in search state,
  default-expanded collapsible groups, and timestamp-ordered rows within each
  file group.
- Documented the next Search result presentation direction: group matches by
  subtitle file, maintain total match counts, support default-expanded
  collapsible groups, and keep lazy loading based on cue-group result count.
- Replaced the hidden 50-result Search cap with lazy 50-result page loading so
  broad searches can continue revealing older matches as the result list
  scrolls.
- Added a copy-current-subtitle playback command, available from a pencil-tip
  control beside the subtitle visibility button and from the `Q` playback
  shortcut, using the indexed cue-group timing and Search result line order for
  clipboard text.
- Fixed Japanese kana subtitle search by segmenting hiragana, katakana, and
  halfwidth katakana for SQLite FTS phrase matching, and added a schema
  migration that rebuilds derived FTS rows from stored cue-group search content.
- Made search result selection update before playback session preparation starts,
  so result highlighting and inspector context respond immediately even when
  video open or seek work takes noticeable time.
- Reduced legacy `libass` CPU work for static ASS subtitles by reusing the
  previous cropped subtitle frame when libass reports no visual change, avoiding
  repeated RGBA compositing, `CGImage` creation, and layer replacement on every
  playback tick.
- Added an indexed render-segment cache for large ASS subtitles: indexing now
  stores source-faithful ASS fragments in SQLite for `legacy libass`, using a
  256 KB threshold and complexity-aware 5-60 second windows so playback can load
  the current fragment without rereading and splitting the full source file on
  result selection. Dense effect sections are split into shorter windows while
  simple regions remain wider, keeping complex ASS playback memory steadier
  without applying the overhead to small ordinary ASS files.
- Added a native playback rebuffer gate that pauses audio output when video
  frame delivery stalls, so NAS or network read jitter produces a unified
  playback pause instead of allowing audio to run ahead of video and subtitles.
- Added bounded native playback packet read-ahead for path-based media, using a
  0 second startup waterline, 10 second steady read-ahead target, and 64 MB
  compressed-packet cap to absorb local, NAS, and future WebDAV-style read
  jitter without staging whole files.
- Renamed the active project from `SubFinderX` to `CueSeeker`, recorded the
  Chinese product name `字幕求索`, and kept the archived Flutter implementation
  under its historical name for comparison.
- Established project documentation governance.
- Clarified when `docs/changelog.md` must be updated across documentation, Git workflow, and release rules.
- Archived the legacy Flutter implementation under `archive/flutter/`.
- Began formal engineering documentation for the native macOS rewrite.
- Recorded the native macOS rewrite decision in ADR-0001.
- Recorded native app stack, playback engine, and sandbox/file-access decisions in ADR-0002 through ADR-0004.
- Recorded the Playback Fullscreen Lifecycle and Singleton RenderView architecture in ADR-0005.
- Started the native macOS app shell under `apps/macos-native/`.
- Added core SRT parsing, subtitle file scanning, and same-directory video matching.
- Added the initial SQLite + FTS5 database layer for subtitle entries and search paths.
- Added the core indexing pipeline from selected folders into the SQLite search database.
- Connected the native UI to subtitle indexing and FTS5 search.
- Added incremental reindexing behavior that skips unchanged subtitle files.
- Added embedded `libmpv` playback integration for local video files.
- Replaced external-window playback behavior with `libmpv` render API playback embedded in the app window.
- Connected search results to playback, including timestamp start behavior and same-video seek handling.
- Reworked the Search flow from split result/detail presentation to a search-results page and a dedicated playback page.
- Added basic playback-page interactions: auto-play on result selection, return-to-search stop behavior, and click-to-toggle play/pause on the video surface.
- Accepted the Playback Inspector workflow to replace default playback-page navigation for search result preview.
- Implemented the Playback Inspector workflow with a resizable right-side panel, fixed titlebar toggle, and pause-on-hide behavior.
- Refined the Playback Inspector resize divider with a wider hit area, hover feedback, and a horizontal resize cursor.
- Added a custom native app shell with Search and Settings navigation.
- Moved titlebar controls to AppKit so the sidebar toggle and centered section title align with the native macOS titlebar.
- Updated Search result presentation with a larger custom search field, subtitle-file-name context, and highlighted query matches.
- Refined custom titlebar layout by securely offsetting native traffic light controls, eliminating resize jitter while preserving native hover and click behaviors.
- Refined Search UI typography to match native macOS standards, added search field focus state, and added a clear-text button.
- Overhauled Sidebar and Search Results layout to adopt a clean, Ulysses-style design with progressive padding, solid accent selection, and native titlebar hover states.
- Fixed a UI regression where the Search Field decoupled from the FTS engine, restoring real-time subtitle queries.
- Removed duplicate subtitle text display from the Playback Inspector to streamline the UI.
- Unified global content layout by standardizing top padding across all application panes (Sidebar, Search, Inspector, Settings) to a strict 16pt baseline.
- Fixed Search UI layout regressions including horizontal width bounding, AttributedString line-height inflation, and text reflow jitter during selection state changes.
- Eliminated Search input text baseline jitter by replacing the standard SwiftUI `TextField` with a custom `NSTextView` wrapper (`SearchTextView`), bypassing AppKit Field Editor swapping while preserving the custom 36pt focus ring via explicit state bridging.
- Implemented global AppShell layout persistence using `UserDefaults` within `AppState` to automatically save and restore Sidebar visibility, Playback Inspector visibility, and Inspector width across application launches.
- Configured the main window to automatically maximize to the screen's visible frame upon startup, preserving native window behavior without forcing Full Screen mode.
- Adopted "Main Workspace" as the standard nomenclature for the center content region to support future scalability (e.g., Shiori).
- Kept Search mounted while switching to Settings so embedded playback preserves its render view and returns without a black frame.
- Accepted the M1 native macOS minimal local loop on 2026-04-28 after manual UI interaction review and passing the Swift test suite.
- Deferred search-quality optimization, keyboard shortcuts, playback interaction refinement, and broader native macOS polish to post-M1 work.
- Researched and documented the root causes of `libmpv` OpenGL context crashes and `toggleFullScreen` IMK crashes during playback fullscreen transitions.
- Designed the "Singleton RenderView" and "Theater Mode" architecture to permanently resolve fullscreen pointer dereference crashes (recorded in ADR-0005).
- Started M2 planning on 2026-04-28 and clarified that playback interaction is a separate M2 work area from keyboard shortcuts, while M1 window sizing and restoration work should be treated as M2 regression verification.
- Clarified the M2 playback fullscreen behavior as video-level Theater Mode rather than app-window Full Screen.
- Clarified playback control terminology and interaction rules for the Timeline Zone, Transport Controls Zone, and Playback Operation Zone.
- Added M2 playback shortcut and feedback overlay requirements for subtitles, fullscreen, play/pause, relative seek, volume, and speed.
- Implemented video-level Theater Mode fullscreen using a singleton `MPVRenderView`, avoiding app-window Full Screen transitions.
- Refined playback operation controls with an app-drawn upward speed menu, subtitle visibility toggle, and video-surface-only play/pause tapping.
- Added playback keyboard shortcuts and feedback overlays for subtitle visibility, fullscreen, play/pause, relative seek, volume, and speed.
- Refined playback speed and volume controls by aligning keyboard speed limits with the control menu, adding the `1.75x` speed preset, reducing keyboard volume steps to `5%`, and stabilizing the volume hover layout.
- Refined playback fullscreen chrome behavior, speed-menu hover behavior, timeline hover stability, and playback shortcut focus handling around read-only selectable metadata text.
- Fixed fullscreen entry behavior so the initial hover event from the newly opened fullscreen window does not immediately reveal playback controls or the mouse cursor.
- Suspended Theater Mode while the app is inactive so app switching no longer leaves the fullscreen playback window visually covering other applications.
- Lowered the Theater Mode window level so the Cmd-Tab app switcher remains visible while playback fullscreen is active.
- Clarified and implemented Search field focus behavior for app-owned commands, sidebar navigation, search result selection, Playback Inspector clicks, and system-level app switching.
- Refined playback fullscreen and speed menu interaction so keyboard shortcuts no longer reveal fullscreen controls, the speed menu has no separate animation, and speed button hover/click geometry matches the menu.
- Verified the M2 playback interaction refinements after user testing and passing the Swift test suite with 23 tests on 2026-04-28.
- Consolidated documentation for the accepted M2 interaction refinements covering Theater Mode app switching, Cmd-Tab visibility, Search focus preservation rules, fullscreen chrome triggers, and speed menu hover geometry.
- Proposed a native playback backend direction that uses FFmpeg demuxing, VideoToolbox hardware decoding, native display, native audio output, and mpv fallback for unsupported cases.
- Added an isolated `NativePlaybackProbe` target to validate the native playback direction without changing the production `libmpv` playback path.
- Verified the probe can demux the representative H.264 1080p60 Matroska sample, decode 300/300 video frames through VideoToolbox hardware decode, display decoded frames through `AVSampleBufferDisplayLayer`, decode Opus audio through FFmpeg, schedule PCM audio through `AVAudioEngine`, and pace video frames by timestamp.
- Advanced the native playback probe with timestamp seek, seek-preroll handling, audio-clock video pacing, repeated seek simulation, and pause/resume simulation against the representative H.264/Opus Matroska sample while keeping the production `libmpv` playback path unchanged.
- Added duration-limited native playback probe runs with process RSS and physical-footprint sampling to support long-running stability and memory comparisons before any production playback backend change.
- Added quiet and interrupt-safe native playback probe output so repeated 5-minute stability runs remain readable and still produce final summaries when stopped early.
- Added seek-list native playback probe runs to simulate repeated search result selection and stress decoder, audio, display, and clock reset behavior before app integration.
- Added an inspect-only native playback probe mode to classify candidate files before spending time on multi-format playback stability runs.
- Recorded user-verified native playback probe results for 10-minute single-seek playback, interrupted 5-minute iteration, and 60-operation repeated seek-list stress testing on the representative H.264/Opus Matroska sample.
- Extended the isolated native playback probe with audio stream enumeration, explicit audio stream selection, and stereo downmix for multi-channel audio, keeping the production `libmpv` playback path unchanged.
- Added batch inspect-list screening to the isolated native playback probe so multiple media files can be classified before longer native-backend stability runs.
- Accepted native-first playback in ADR-0006, superseding the previous `libmpv`-primary decision while retaining `libmpv` as fallback.
- Integrated the native playback backend into the production macOS app behind a playback facade that tries FFmpeg + VideoToolbox + native audio first and falls back to `libmpv` when needed.
- Aligned playback product, engineering, proposal, and ADR documentation with the native-first production playback path and generalized fullscreen render-container ownership.
- Fixed a playback crash when a search result falls back from native playback to `libmpv` by removing recursive render-container initialization.
- Refined native-first playback so `libmpv` is initialized only on fallback demand, native success releases fallback state, 1.0x playback can retry native after fallback, and native timestamp seek has a global seek fallback.
- Added native AV1 hardware decode routing by selecting a VideoToolbox-capable FFmpeg decoder instead of accepting the default `libdav1d` software decoder for AV1 files.
- Verified native AV1 VideoToolbox playback on the representative GTA V WebM sample with all decoded video frames reported as hardware frames and user-observed app memory staying below 50 MB.
- Recorded the next native playback direction: move hard-decoded and future software-decoded frames through a shared Metal YUV renderer while retaining `libmpv` fallback.
- Fixed native playback seek flicker by preserving the current displayed frame during same-file seek rebuilds until the first target frame is ready.
- Fixed native playback result-switch flicker by preserving the previous frame until the next video's first frame is ready, and suppressed non-error FFmpeg warning logs from production native playback.
- Clarified future packaging direction: if `libmpv` fallback is removed, the distributable app should bundle FFmpeg libraries and their required non-system transitive dependencies, while relying on macOS system frameworks for VideoToolbox, Metal, AVFoundation, and audio output.
- Fixed native timeline seek state so selecting a timeline timestamp no longer publishes a transient `0` playback time before the target time is ready.
- Documented the video-first backend preselection direction: folder scanning should cache fast media-file backend preference using stream presence, codec names, and current-device VideoToolbox hardware support, while real playback remains responsible for fallback and correction.
- Added app-owned subtitle overlay rendering for native-first playback using the indexed SRT file associated with the selected search result.
- Accepted native-only playback in ADR-0007, superseding native-first `libmpv`
  fallback so production playback failures surface directly through the native
  backend.
- Restored native subtitle search semantics from the archived Flutter
  implementation, including Latin prefix matching, ordered multi-token
  filtering, CJK FTS segmentation, invalid-query handling, and migration of
  existing FTS rows to the updated indexed representation.
- Refined Settings folder management with a global all-folder indexing action
  and confirmed folder removal that does not delete local files.
- Fixed folder removal so removing a configured folder also clears its indexed
  subtitle rows, FTS data, and stored search path from the local database.
- Added startup index reconciliation and scoped search so stale subtitle rows
  outside the currently configured folders cannot appear in Search.
- Documented the accepted Settings folder-management, scoped-search, and index
  reconciliation behavior across product and engineering docs.
- Added a persisted Decode Settings picker for `hardware`, `software`, and
  `auto` playback decode modes.
- Connected Decode Settings to native playback, adding FFmpeg software video
  decode with `libswscale` BGRA conversion while keeping VideoToolbox hardware
  decode available.
- Clarified that future Metal YUV playback work should first target
  software-decoded frame compatibility and leave the VideoToolbox hardware
  display path unchanged.
- Reduced debug-run AppKit helper service pressure by mounting Settings only
  when selected, replacing the Decode Settings menu picker with an app-drawn
  segmented control, and presenting folder selection as a single window sheet.
- Documented that native folder selection and future Finder interactions may
  temporarily create AppKit, QuickLook, or Finder helper services, and that
  optimization should avoid unnecessary helper creation without replacing
  native macOS file-access behavior or force-terminating system services.
- Added a one-shot initial software playback session recycle to reduce
  first-session physical memory pressure on high-resolution software AV1
  playback while preserving decoder parallelism and first-frame responsiveness.
- Documented the accepted software playback memory-mitigation constraints and
  unsandboxed verification requirements after user confirmation that the recycle
  behavior is not perceptible in normal playback.
- Accepted M2 ASS subtitle support planning for `.ass` indexing, grouped cue
  search results, grouped result display, and click-to-playback behavior while
  deferring source ASS subtitle rendering.
- Documented the ASS cue-model migration direction: preserve durable user
  configuration, rebuild derived subtitle index data, and enforce line-level
  search matching so query terms split only across different cue lines do not
  produce a grouped result.
- Implemented the first M2 ASS subtitle support step: `.ass` scanning, ASS
  dialogue parsing, cue group and cue line indexing, grouped search result
  display, and click-to-playback behavior.
- Migrated the native database to schema version 3 for the ASS cue model,
  preserving selected-folder configuration while rebuilding derived subtitle
  index data from source files.
- Verified the ASS implementation with the Swift test suite passing 43 tests.
- Accepted the ASS Lite source subtitle rendering direction for the first
  playback rendering step, keeping rendering source-file-owned while avoiding an
  external ASS rendering dependency.
- Implemented the first ASS Lite source subtitle rendering path with playback
  source loading, basic ASS parsing, a native overlay in the playback render
  container, subtitle visibility integration, and 48 passing Swift tests.
- Refined first-pass ASS Lite visual scope so source ASS files provide timing,
  text, line breaks, and basic placement while CueSeeker owns the default
  readable subtitle display style.
- Restored the ASS Lite visual direction so `[V4+ Styles]` and `[V4 Styles]`
  source style fields drive first-pass subtitle rendering while CueSeeker avoids
  platform text-stroke rendering for outlines.
- Accepted the source-faithful ASS playback rendering pipeline direction:
  search remains a readable-text projection, playback preserves timed source ASS
  events, and ASS parsing or rendering must not block row selection or video
  playback.
- Clarified the planned ASS render-preparation optimization: database cue timing
  can identify the selected and nearby deterministic time windows, while the
  source `.ass` file remains required for exact formatting and visual-effect
  payloads.
- Implemented the first windowed ASS render-preparation path: ASS playback
  sources now carry an indexed cue timing window as a future renderer
  preparation hint, while the current ASS Lite fallback keeps full-source
  parsing and subtitle source loading runs asynchronously with stale-load
  cancellation.
- Accepted ADR-0009 and clarified the source-faithful ASS rendering plan:
  complex ASS playback should use a dedicated renderer path, preferably
  `libass`, with ASS Lite limited to simple fallback or diagnostics and
  renderer failures surfaced during development.
- Added an isolated `CASSRendering` libass bridge and `ASSRenderingProbe`
  executable to render source `.ass` files into diagnostic RGBA/PNG output
  before any playback UI integration.
- Routed ASS playback subtitles through the libass-backed source-faithful
  overlay path in the native playback render container, keeping ASS Lite out of
  the active ASS playback path so renderer failures surface during development.
- Updated ADR-0009 to make native `v0` the first ASS renderer phase and a fully
  project-owned native ASS rendering pipeline the final direction, with legacy
  renderer paths retained only as transitional selectable options.
- Implemented the native ASS `v0` manual-acceptance path: native parsing,
  active cue selection, tag stripping, text-bounded subtitle surfaces, playback
  overlay routing, and Settings renderer selection with native mode as the
  default and legacy libass retained as a transition option.
- Refined the native ASS rendering plan by making ordinary dialogue visual
  alignment part of Phase 1 and scoping Phase 2 as a separate expanded static
  ASS support discussion.
- Fixed native ASS ordinary dialogue sizing so small source font sizes and scale
  values are no longer enlarged by hard-coded renderer minimums.
- Calibrated native ASS `v0` CJK dialogue font sizing against the legacy ASS
  comparison path so ordinary bilingual subtitles no longer render oversized.
- Added Phase 1.1 font fallback parity planning for native ASS ordinary dialogue
  alignment before accepting further font-size calibration.
- Documented the validated legacy `libass` memory optimization directions:
  layer-contents presentation, cropped subtitle bitmap presentation, and
  lifecycle-safe clear or stop recovery work.
- Clarified that the `libass` ASS renderer is a long-term selectable reference
  and compatibility option rather than only a temporary transition path.
- Reframed later native ASS rendering phases as a flexible, user-led
  real-sample exploration process: Phase 2 analyzes and implements coverage
  from real subtitle samples, Phase 3 defines compromise or unsupported-behavior
  policy, and Phase 4 focuses on performance, memory, and long-run stability.
- Documented long-term danmaku playback as a possible separate overlay track
  and renderer from subtitles, with ASS syntax and timeline heuristics used for
  practical subtitle-versus-danmaku classification.
