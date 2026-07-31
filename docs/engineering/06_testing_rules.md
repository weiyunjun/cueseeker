# Testing Rules

Status: Draft

## 1. Purpose

This document defines testing expectations for the native macOS rewrite of CueSeeker.

It describes what must be verified before a milestone is considered complete. It does not define implementation code.

## 2. Testing Principles

Testing should focus on the local subtitle search and playback workflow.

Principles:

- Test pure logic directly where possible.
- Test database behavior with real SQLite and FTS5.
- Test macOS integration points with focused integration or manual checks.
- Keep fixture data small, explicit, and version controlled when practical.
- Do not depend on the user's personal subtitle library for automated tests.
- Each milestone must have acceptance checks tied to product requirements.

## 3. Required M1 Test Coverage

M1 is not complete until the minimal local loop is verified.

Required coverage areas:

- Local folder selection and stored folder configuration.
- Recursive `.srt` scanning.
- SRT parsing.
- Same-directory video matching.
- SQLite schema creation.
- FTS5 indexing and search.
- Incremental reindexing behavior.
- Stale entry removal.
- Search result selection.
- Local playback open and timestamp seek behavior.
- User-visible error handling for missing files and unreadable inputs.

Not every area must be automated in M1, but manual checks must be documented when automation is impractical.

## 4. Unit Tests

Unit tests should cover deterministic logic without relying on macOS UI.

Required unit test areas:

- SRT block parsing.
- Multi-line subtitle text parsing.
- Timestamp parsing and millisecond conversion.
- Malformed subtitle block handling.
- Subtitle file extension filtering.
- Video basename matching.
- Complete-basename video priority, one-level suffix fallback, and at most one
  matched video per subtitle.
- Friendly Search result group title derivation from parent folder name and
  same-extension sibling subtitle rank.
- Finder-like natural filename ordering for friendly Search result group titles,
  including numeric cases such as `aa2.ass` before `aa11.ass`.
- Search query normalization or validation, if implemented outside the database layer.

Rules:

- Unit tests must not require access to the user's real subtitle folders.
- Unit tests should use small inline or fixture-based examples.
- Parser tests must include both valid and malformed input.
- Timestamp tests must include boundary-like cases such as zero time and hour-level timestamps.

## 5. Database Tests

Database behavior must be tested with SQLite, not mocked as plain in-memory collections.

Required database test areas:

- Fresh schema creation.
- Schema version value.
- Migration from each supported previous schema version.
- Insert and replace subtitle entries for a source file.
- Delete stale subtitle entries.
- FTS5 insert, update, delete, and search consistency.
- Empty query behavior.
- Invalid query behavior.
- Result limits and predictable ordering.
- CJK search behavior at least matching the archived Flutter implementation's practical behavior.
- Pure Japanese kana search behavior, including hiragana, katakana, and
  halfwidth katakana queries.
- Search scoped to the currently selected folders.
- Startup reconciliation that removes or excludes index rows outside the
  currently selected folders.
- Clearing derived index data when no folders are selected.

Rules:

- Tests must use isolated test databases.
- Tests must not mutate a production user database.
- Tests should verify durable user state separately from rebuildable index state.
- Migration tests must fail if a fresh schema and migrated schema diverge unexpectedly.

## 6. Integration Tests

Integration tests should verify the main local data flow across modules.

Required M1 integration scenarios:

- Index a fixture folder containing valid `.srt` files and matching videos.
- Index a fixture folder with unreadable or malformed subtitle content and continue processing valid files.
- Reindex after a subtitle file changes.
- Reindex after a subtitle file is removed.
- Search indexed content and resolve a result to video path plus `start_ms`.
- Handle a search result whose matched video no longer exists.
- Remove a configured folder and verify its indexed subtitle rows no longer
  appear in search results.
- Start with stale indexed rows from a previously removed folder and verify they
  are reconciled or excluded from search.

Rules:

- Integration tests should use fixture directories, not personal media libraries.
- Fixture video files may be tiny placeholder media files if playback tests do not inspect actual decoding.
- Tests that require real media decoding may be separated from fast default tests.

## 7. UI Smoke Tests

The native UI must have smoke coverage before milestone completion.

Required M1 smoke checks:

- App launches.
- First-launch or no-folder state is visible.
- A folder can be added through the intended UI path.
- Indexing status is visible during or after indexing.
- Search input accepts text.
- Search results render without layout breakage.
- Selecting a result updates selection state.
- Playback area opens or reports a clear error.

Rules:

- UI smoke tests may be automated or manually documented during early development.
- Text input shortcuts must continue to behave like native macOS text fields.
- Keyboard shortcuts must be checked for conflicts before being considered complete.

## 8. End-to-End Test Documentation

End-to-end tests are required for changes whose main risk is runtime behavior,
macOS integration, playback behavior, UI responsiveness, or user-visible
workflow friction.

Detailed procedures live in `docs/engineering/08_end_to_end_testing.md`.

Rules:

- Before asking for an end-to-end test, create or update a test document under
  `docs/engineering/` that describes the exact test method, the expected log
  flow, and the acceptance criteria.
- The test document must include the feature or regression under test,
  preconditions, build or launch commands, diagnostic environment variables,
  log-stream commands, user action steps, expected observations, failure
  examples, cleanup steps, and what evidence the user should paste back.
- The AI/log handoff must be explicit. The document should state which terminal
  should be running, how to delimit a test run, what log predicate or file path
  matters, and how the assistant should interpret the pasted output.
- If a test depends on temporary probes, the document must identify whether
  those probes are default-off, how to enable them, and what later change should
  remove or keep them gated.
- Acceptance criteria must avoid vague instructions such as "try it for a
  while." Each test should define concrete pass/fail conditions such as no
  `com.cueseeker.perf` output, no `MainThread.stall`, no unrelated row rebuild
  counter increase, preserved scroll position, or immediate playback seek.
- End-to-end test docs are allowed to evolve during debugging, but every
  meaningful change to the expected procedure or acceptance criteria must be
  committed with the code or documentation change that relies on it.

## 9. Search Optimization Gates

Search optimization work must be benchmark-led and test-gated.

Rules:

- Before changing Search optimization code, run the agreed benchmark queries
  `大丈夫`, `今日`, and `の` on the current commit and record raw timings,
  averages, result counts, and file counts.
- Search diagnostics should be exposed through benchmark output, log files, or
  default-off probes while the optimization path is unstable. Do not add
  front-end Search-performance display as an early workflow shortcut.
- Automated tests must cover the behavior changed by the optimization step
  before the step is accepted. Relevant areas include query semantics, result
  identity, grouping, ordering, folder scope, total counts, pagination, collapse
  and expansion behavior, and lazy-loading boundaries.
- End-to-end evidence is required before accepting a Search optimization step
  that affects visible Search workflow, scrolling, collapse or expansion,
  lazy-loading triggers, or Search-result playback selection.
- Search optimization end-to-end evidence must run the fixed query sequence
  `大丈夫`, `今日`, and `の` in order and follow the documented per-query wait,
  scroll, and acceptance rules.
- A benchmark regression on the metric targeted by the step must stop the
  sequence. The default follow-up is to revert or disable the change unless the
  user explicitly accepts keeping it with a documented reason.

## 10. Playback Verification

Playback requires both automated-adjacent verification and manual acceptance.

Required M1 playback checks:

- A matched local video can be opened.
- Playback can seek to `start_ms`.
- Play and pause controls work.
- Manual seek controls work.
- Missing video files produce a clear error.
- Selecting another result for the same open video seeks instead of unnecessarily reopening when practical.

Required M2 playback interaction checks:

- Playback fullscreen affects only the video experience even though the main
  workbench window may enter AppKit native fullscreen.
- Playback fullscreen uses main-window video-only presentation and does not
  create a dedicated playback fullscreen window for the standard path.
- Playback fullscreen does not move the native playback render container across
  windows during fullscreen entry or exit.
- Dock, menu bar, desktop, wallpaper, Spaces, Mission Control, app switching,
  and system overlays follow standard macOS fullscreen behavior.
- The custom app top bar, traffic-light buttons, Mode Rail, Shared Content Panel,
  and Playback Area remain visually correct in ordinary window mode after
  entering and exiting playback fullscreen.
- The green traffic-light button and system View fullscreen command enter
  ordinary app fullscreen, not video-only playback fullscreen.
- Playback fullscreen does not trigger ordinary side-panel open, close, or resize
  animations.
- Playback fullscreen hides the normal workbench shell without destroying panel
  widths, active panel mode, selected rows, scroll positions, or focus state.
- Embedded controls, fullscreen controls, subtitles, and feedback overlays do not
  render in duplicate during entry, active fullscreen, or exit.
- Fullscreen keyboard shortcuts execute playback commands without revealing the playback operation controls.
- The `Q` shortcut toggles subtitle visibility without interfering with editable
  text input.
- The normal bottom player has no Shiori or copy-current-subtitle button, and
  normal-playback `S` and `C` do not execute those removed commands.
- Enter during active playback opens the Playback Multi-Module Overlay, pauses
  playback, hides Playback Chrome, starts on Current, and shows Playlist only
  when the current playback-origin list exists.
- Unmodified Tab cycles the available canonical module order even while the
  Playback Search field is focused. It does not perform native focus traversal;
  no other key switches modules.
- Current, Playlist, and Shiori use exact settled Primary Cue `S`, `C`, and
  Enter actions. `S` saves idempotently and `C` preserves complete source line
  breaks without closing the paused Overlay. Enter destroys the Session before
  continuous playback starts at the exact Primary Cue start. Space is consumed
  without a playback action.
- Current, Playlist, and Shiori `X` tests must verify the exact plain Markdown
  payload, CueID target, settled-action semantics, and success feedback. The
  payload coverage must include LF, CRLF, CR, Unicode line breaks, trimmed and
  empty source lines, the required Markdown backslash escapes, and the visible
  `Cue #{CueID}` fallback for an empty normalized label.
  Playback Search must keep `X` as query input and must not publish adaptive
  HTML or RTF clipboard representations.
- Playlist setting tests must cover the three valid Auto Pause and Auto Switch
  combinations: on/on, on/off, and off/off. They must verify that turning Only
  Pause off forces Auto Switch off, persists the normalized state, and disables
  only the Auto Switch toggle while Gap editing remains available. Cue-boundary
  tests must verify that the current subtitle remains visible both when stopped
  indefinitely and while waiting in the automatic-switch Gap.
- URL Scheme tests must cover Workbench Search versus Overlay Search routing,
  direct-play first-result routing, empty-result routing with and without active
  Playback, preservation of the persisted Workbench facet Filter, direct play
  from the first filtered result, filtered-empty fallback, CueID parsing and
  lookup, one-item Playlist presentation, command supersession, and Cue
  playback Return Context.
- Playback Search keeps native text input priority, starts work 100 milliseconds
  after the latest edit through the shared Workbench Search pipeline, keeps
  editor focus while Up and Down navigate Results, and exposes only
  settled-result Enter as its module action. Recent and both Library levels use
  four-direction media selection and nonrepeating Enter.
- Overlay action feedback renders above the Overlay. Cue Result hover and click
  do nothing; Up, Down, wheel, trackpad, and scrollbar navigation still work.
  Recent and Library reuse their existing pointer, hover, and context-menu
  regions; Playback omits only the Workbench `Context` menu item. Selected
  reuses Hover visuals and adds no Focus Ring.
- A Cue action accepted during reel motion executes once against the final
  settled target. Module switching preserves each module's Session state;
  Escape, playback actions, Playback Page close, source replacement, and stop
  synchronously destroy the Session, cancel its workers, and reject stale work.
- Playback Return Context persists across Overlay Sessions, changes only after
  successful Search, Shiori, Recent, or Library Detail playback, and is
  destroyed after close restores the corresponding current Workbench Feature.
- Playback Page initialization hides Pointer. Mouse movement inside the player
  area reveals player UI and Pointer and restarts the idle timer; clicks and
  Wheel do not. Every key-down hides Pointer without revealing player UI.
  Hidden-Pointer Hover cannot change Playback Media Selection.
- Selecting a search result, clicking app-owned feature buttons, selecting
  another main-window sidebar section when such sections exist, or clicking the
  Playback Area clears Search field focus.
- Cmd-Tab away and back, titlebar double-click resize, native traffic-light clicks, and foreground/background transitions do not intentionally clear Search field focus.
- The speed menu has no separate show or hide animation.
- The speed button hover area, speed button click area, and speed menu width are aligned.
- The speed menu remains visible only while the pointer is inside the documented rectangular hover region spanning the menu and speed button.
- The main window title identifies the workbench as `CueSeeker`; the old
  standalone `Search` navigation label is not shown.
- The fixed left titlebar control collapses or expands Library. The fixed right
  titlebar control collapses or expands the Right Learning Panel.
- `CueSeeker > Settings...` opens or focuses an independent Settings window.
- Opening, focusing, switching categories within, or closing Settings does not
  pause playback, switch away from the CueSeeker workbench, collapse either
  side panel, or clear the selected Search result.
- The Settings window exposes `Library` and `Decode` categories.
- `Library` supports current Subtitle Folders operations: add folder, index,
  remove with confirmation, and indexing status.
- `Decode` supports choosing persisted `hardware`, `software`, and `auto`
  decode modes.
- The CueSeeker workbench places Library on the left when expanded, playback in
  the center, and Search controls/results on the right.
- Collapsing the Right Learning Panel expands playback width, preserves the
  selected result, and does not pause playback.
- Reopening the Right Learning Panel restores the current Search/Shiori
  context when practical.
- Future Left Content Panel modes should preserve the left-side precise
  resource-positioning responsibility for Library and Timeline.
- Future Right Learning Panel modes should preserve the right-side active
  workflow responsibility for Search, Shiori, Queue, and Learning Session.
- Titlebar mode-container checks should verify that side-panel mode buttons are
  rendered in the global titlebar, use the documented folder/search/Shiori icons,
  and visually track the corresponding side-panel width during manual divider
  resize and collapse or expand animation.
- Titlebar side-panel animation checks should verify that mode buttons do not
  fade in or out. They should be revealed or hidden only by the clipped
  drawer-style strip, and the titlebar controls should finish their animation
  at the same time as the side-panel body.
- Titlebar mode-button checks should verify that mode buttons have hover and
  selected states only: hover matches collapse-toggle hover, selected matches
  collapse-toggle pressed, and clicking a mode button does not add a separate
  pressed state.
- Library panel checks should cover the accepted Library behavior:
  left titlebar collapse or expand, default width equal to the `310pt` minimum
  width, width resizing and persistence, gray background, flat one-level folder
  grouping, Finder-like natural folder and video ordering, startup with all
  folder groups collapsed, session-only individual group collapse or expand,
  no panel-wide `Collapse All` / `Expand All`, two-line folder rows with no
  leading first-letter avatar, full-row click toggling expand or collapse,
  numbered episode-button grid in expanded folders using one-based sibling
  rank, episode grid using minimum-width auto-flow columns that adapt to the
  Library panel width, episode grid indented slightly to the right of the
  folder row's left edge, three episode-button states only (default, hover,
  playing), and click-to-playback from Library resume history with `0`
  fallback.
- Library subtitle text checks should verify that the folder row subtitle
  reads `N episodes` when no Library-launched playback is active for any video
  in this folder, and reads `N episodes · Playing M` while a Library-launched
  playback session is active for a video in this folder, where `M` is that
  video's one-based sibling rank.
- Library "Playing" indicator checks should verify that the folder subtitle
  `Playing M` indicator and the episode-button playing-state highlight light
  up only for playback launched through Library, and never for playback
  launched through Search results, Shiori, or any other surface. Search-result
  playback whose video happens to belong to a Library folder must not change
  the folder's subtitle text or any episode-button state.
- Library auto-scroll checks should verify that expanding a folder containing
  the currently Library-launched playing video scrolls that video's episode
  button into view as part of the expand transition. Auto-scroll must not fire
  for already-expanded folders or for data refresh.
- Library visual checks should verify that no blue macOS focus ring appears on
  the first Library folder row at startup. Keyboard focus should remain
  available for real text controls such as Search input.
- Library startup checks should verify that a database with existing indexed
  Library rows hydrates the Library list before the first visible main-window
  render, without showing an empty or loading Library state solely because the
  app restarted.
- Library metadata checks should include reindexing a fixture folder so episode
  buttons and indexed duration metadata are populated. Even though duration is
  not drawn in folder rows or episode buttons, indexed duration metadata must
  remain available for tooltips, accessibility, and future features.
  Reindexing or a Library data refresh should reset all Library folder groups
  to collapsed.
- Library playback history checks should verify that Library-opened videos read
  and write persisted resume position, while Search-result playback does not
  read, write, or overwrite that history. Removing a folder and later adding or
  reindexing the same path should not delete matching Library playback history.
  A successfully started Library or Recent video must immediately refresh every
  currently loaded Recent Videos projection through the shared `LibraryStore`
  refresh path.
- Reindex workflow checks should verify that playback using media under the
  reindexed folder is stopped or cleared before the rebuild starts, and that an
  active Search query is rerun after the rebuild completes.
- Database locking regression checks should verify that `Index Now` does not
  fail with `database is locked` when triggered shortly after app startup, after
  Library startup hydration, after Search results are loaded, while playback
  history may be written, or while ASS render-segment reads are possible.
- SQLite connection checks should verify that app-owned connections configure a
  non-zero busy timeout and use the documented production journal mode.
- Indexing workflow checks should verify that app-owned Library and Search read
  tasks are cancelled or isolated before indexing begins, so CueSeeker does not
  create avoidable lock contention with itself.
- Workbench responsiveness checks should verify the UI invalidation boundaries
  between Library, Playback, and Search:
  - Repeatedly toggling the left titlebar Library control should not rebuild
    Library presentation rows and must not destroy the playback render
    container.
  - Exiting playback fullscreen should not rebuild Library presentation rows or
    Search presentation rows.
  - Clicking or focusing the Search field during playback should not rebuild
    Library presentation rows or reset playback state.
  - Search query updates should rebuild Search presentation rows only for the
    active query state and should not rebuild Library presentation rows.
  - Library add-folder, remove-folder, reindex, and explicit Library data
    refresh are the accepted reasons to rebuild the persisted Library
    presentation snapshot. Width resize and manual Library group collapse or
    expand may update presentation state, but must not rebuild rows.
- Workbench side-panel animation checks should verify that collapse and expand
  keep Library and Search panel contents at their expanded widths while sliding
  the panels in or out. The panels must not be compressed to zero-width content
  during animation, and the central Playback Area should resize independently.
- Embedded Playback Area checks should verify that normal workbench playback is
  not wrapped in a SwiftUI ScrollView layout path. Side-panel toggles should not
  drive repeated ScrollView size measurement for the native playback surface or
  its command buttons.
- Performance diagnostics for this work should include counters or signposts
  for Library row rebuilds, Search row rebuilds, workbench container body
  refreshes, playback time publications, and ASS renderer reloads. These
  diagnostics may be temporary, but they must be sufficient to prove that
  unrelated panel interactions are not driving expensive recomputation.
- Heavy performance diagnostics, including automatic `sample` capture, run-loop
  observers, and broad SwiftUI body/layout probes, should have a verification
  step to remove them or gate them behind DEBUG or an explicit diagnostic flag
  after the target regression has been fixed.
- Normal smoke runs should produce no `com.cueseeker.perf` output unless an
  explicit diagnostic environment flag is set. When deeper investigation is
  needed, enable only the narrow flag for the probe under test, such as
  `CUESEEKER_PERF_WATCHDOG=1`, `CUESEEKER_PERF_RUNLOOP=1`,
  `CUESEEKER_PERF_AUTOSAMPLE=1`, `CUESEEKER_PERF_LAYOUT=1`, or
  `CUESEEKER_PERF_UI=1`, or `CUESEEKER_PERF_PLAYBACK=1`.
- End-to-end tests that depend on diagnostic logs must have a startup marker
  and action markers. If the expected startup marker does not appear within
  three seconds, the run is invalid and must be relaunched with the documented
  diagnostic flag instead of continuing as a manual visual check.
- UI invalidation-domain checks should confirm that Library, Playback, Search,
  and future panel modes do not subscribe to unrelated high-frequency state.
  Playback time publications, Search input changes, Library disclosure changes,
  and side-panel visibility changes should each refresh only the smallest
  practical view subtree.
- Dense row interaction checks should cover large Library/Search result sets
  with repeated row clicks, hover affordances, and context menus. If SwiftUI
  Button layout appears in performance traces for ordinary row rendering,
  use lighter row hit handling before adding more row-level buttons. Top-level
  command buttons may remain SwiftUI buttons when they are not repeated per row.
- Playback clock throttling checks should confirm that native video playback
  remains smooth, manual seek feedback updates immediately, and visible
  progress controls remain accurate enough for subtitle-context review.
- Left and Right panel mode-container checks should verify that switching future
  modes such as Library, Timeline, Search, Shiori, Queue, and Learning
  Session preserves each mode's relevant presentation state and does not reset
  playback or rebuild unrelated lists.
- Playback render layout checks should verify that repeatedly collapsing and
  expanding both workbench side panels during playback keeps the black video
  background, native video frame, and ASS overlay synchronized. The video frame
  must not visibly lag behind or detach from the black playback container.
- Playback-size transition checks should verify that side-panel toggle commands,
  bottom-player video overlay expand/collapse, titlebar double-click zoom,
  playback fullscreen `F`, fullscreen button enter/exit, and Escape fullscreen
  exit are serialized while an animation is active, without adding a
  post-animation cooldown.
- Playback fullscreen animation checks should verify that main-window
  video-only presentation enters and exits AppKit native fullscreen through
  AppKit lifecycle callbacks, keeps using the singleton render container without
  moving it across windows, and does not rely on a guessed fixed fullscreen
  delay.
- Playback fullscreen animation checks should also verify top-bar restoration,
  traffic-light restoration, non-duplication of playback overlays, and no
  side-panel animation side effects.
- Playback fullscreen state-machine checks should verify that repeated `F`,
  fullscreen button clicks, and Escape during entering or exiting fullscreen are
  serialized by explicit state rather than by a fixed cooldown. A failed enter
  or failed exit callback must return the manager to a known non-transitioning
  state.
- Playback fullscreen lifecycle checks should verify that AppKit will-enter,
  did-enter, will-exit, did-exit, and fail callbacks are the source of
  fullscreen transition completion. Tests and manual verification should reject
  guessed fixed delays as the mechanism for declaring fullscreen complete.
- Playback native render-view transition checks should verify that the same
  native playback render view and display layer remain in the main window
  hierarchy through fullscreen entry, active fullscreen, and exit. The display
  layer frame should be synchronized through native layout hooks; fullscreen
  transition handling should not use `flushAndRemoveImage` as a workaround.
- If video still freezes during fullscreen transition after the state-machine
  and render-view checks pass while audio continues, the result should be
  recorded as display-layer research input. A Metal/`CAMetalLayer` investigation
  must be documented separately before replacing the current
  `AVSampleBufferDisplayLayer` presentation path.
- Playback chrome checks should verify that time labels fit `10:00:00` without
  wrapping while keeping the scrubber gap compact, speed menus close on outside
  clicks, player UI means bottom player plus `Close`, player UI has only
  visible and not-visible states, mouse movement is the only reveal input,
  idle hiding uses the frozen display-check area, fullscreen entry force-hides
  player UI and cursor, and repeated command feedback updates in place without
  a flashing full-entry animation.
- Playback side-panel checks should verify that opening playback and navigating
  previous or next Search results preserve the current side-panel visibility.
- ASS timing-source changes are out of scope for the first workbench
  invalidation cleanup. If they are attempted later, manual checks must verify
  that selecting a Search result still updates selection, opens or seeks video,
  and loads the intended subtitle source promptly.

Rules:

- Frame-perfect seek accuracy is not required for M1.
- Seek must be close enough for subtitle context review.
- Playback memory and performance measurements must run outside the execution
  sandbox because sandboxed runs can distort process memory observations.
  Sandboxed memory samples must not be used as authoritative playback evidence.
- Software playback memory mitigation must be verified with unsandboxed
  physical-footprint and RSS samples at roughly 50 ms resolution, click-to-first
  target-frame timing, click-to-stable-playback timing, seek preroll behavior,
  and a manual check for visible frame jumps or audible restarts.
- A software playback memory fix is not acceptable if it materially increases
  click-to-first-frame latency, reduces decoder parallelism as its primary
  strategy, or masks the issue only by changing the measurement method.
- Playback read-ahead changes must be checked against local files, mounted NAS
  paths, and representative network-jitter conditions using the same playback
  policy. Verification should confirm that audio, video, and subtitles pause as
  a unit when reads stall, rather than allowing audio to run ahead.
- Playback read-ahead verification should record startup latency, queued packet
  cap behavior, seek/session replacement cleanup, and whether rebuffer events
  become fewer or shorter under network read pressure.
- Timeline scrubbing verification should confirm that pressing the progress
  scrubber enters a modal scrubbing state immediately, pauses playback and
  audio, disables all non-Timeline playback shortcuts, and suppresses
  non-Timeline playback button hover, pressed, click, and menu interactions.
- Timeline scrubbing verification should confirm that the red progress track,
  thumb, tooltip, and visible playback time follow drag updates immediately,
  that the white hover-ahead track segment is hidden while dragging, and that
  mouse release seeks to the final requested timestamp rather than to the
  displayed keyframe timestamp.
- Timeline scrubbing video-surface verification should confirm that dragging
  updates the video surface only when the target maps to a different previous
  keyframe, that repeated drag updates within the same keyframe interval do not
  redraw the video surface, and that stale keyframe requests are cancelled or
  ignored in favor of the newest target.
- Timeline scrubbing read-ahead verification should confirm that active
  scrubbing does not advance or repopulate the normal 10-second / 64 MB
  playback read-ahead queue from the old playback position, and that normal
  read-ahead is retained or rebuilt only after the final release seek.
- ASS subtitle rendering memory work must be judged primarily through
  end-to-end playback acceptance, not isolated renderer probes alone. The core
  acceptance question is whether the user-visible memory drop is meaningful
  while playback, seeking, subtitle visibility toggling, and playback
  fullscreen remain stable.
- ASS renderer measurements should compare the same video across no subtitles,
  SRT subtitles, simple ASS subtitles, and complex ASS subtitles. Useful
  observation points include process memory after open, after steady playback,
  after repeated seeks, after subtitle hide/show toggles, after fullscreen
  transitions, and after closing playback.
- Complex ASS segmentation acceptance should record private resident memory
  before the dense effect section, at peak playback, and after leaving the dense
  section for at least two minutes. Private resident memory is the primary
  process-owned metric; real resident memory is useful context but includes
  shared framework, font, video, and graphics pages.
- Numeric memory samples are supporting evidence for ASS renderer changes, but
  they do not replace perceptual acceptance. A change should not be accepted if
  memory appears lower only in a narrow sample while visible playback behavior,
  subtitle fidelity, responsiveness, or lifecycle stability regresses.
- Playback engine-specific behavior must be documented after the engine is selected.
- Final playback engine verification criteria must be updated after the playback ADR is accepted.

## 11. File Access and Sandboxing Tests

Local folder access must be verified explicitly.

Required checks:

- Selected folders can be scanned.
- Removed folders are no longer indexed on refresh.
- Removed folders no longer contribute search results.
- Permission loss or unreadable folders are reported clearly.
- If sandboxing is enabled, folder access persists across app restart through the documented mechanism.
- If sandboxing is disabled for early personal use, that assumption is documented before packaging.

## 12. Test Fixtures

Fixture data should be small and intentional.

Required fixture categories:

- Valid English `.srt`.
- Valid CJK `.srt`.
- Valid `.ass`.
- ASS file with multiple `Dialogue` events sharing exact timing.
- ASS file with near-equal `Dialogue` timings that must not be grouped.
- ASS file with `Comment` events that must not be indexed.
- Multi-line subtitle entries.
- Missing sequence numbers if supported by parser behavior.
- Malformed blocks.
- Same-basename video match.
- Language-suffix subtitle match, such as `Movie.en.srt` to `Movie.mp4`.
- Subtitle file with no matching video.

Rules:

- Fixture files should avoid copyrighted media or large binary assets.
- Placeholder or generated media should be used when possible.
- Fixture names should make the tested condition obvious.

## 13. Manual Acceptance Checks

Each milestone must have a short manual acceptance checklist.

M1 manual checklist:

```text
Launch native macOS app
Add a local subtitle folder
Run indexing
Search for known subtitle text
Confirm result text, video name, and timestamp are shown
Click a result
Confirm local video opens
Confirm playback starts near the subtitle start time
Remove the configured folder
Confirm the same subtitle text no longer appears in Search
Confirm missing or unreadable files show clear errors
Restart app and confirm configured folder state is preserved if persistence is implemented
```

Rules:

- Manual checks must be updated when the product workflow changes.
- Manual checks should not replace deterministic automated tests for parser, database, and search behavior.

## 14. Regression Policy

Bug fixes should add tests when the bug is deterministic and testable.

Rules:

- Parser bugs should add parser tests.
- Database bugs should add migration or query tests.
- Search ranking or query bugs should add search fixtures.
- Playback bugs should add the closest practical automated check plus a manual verification note if needed.
- UI regressions should add smoke coverage where the native test setup allows it.

## 15. Milestone Completion Rule

A milestone is not complete until:

- Required product acceptance criteria are checked.
- Relevant automated tests pass.
- Known manual-only checks are documented.
- Test gaps are listed explicitly.
- Database migrations, if any, have fresh-create and migrate-path verification.
- Playback behavior, if included in the milestone, has been verified against the selected playback strategy.

## 16. M2 ASS Subtitle Test Coverage

The ASS implementation is complete only after ASS indexing, individual-Cue
Search results with optional derived Cue Group context, and exact-Cue
click-to-playback behavior are verified.

Current verification:

- The Swift test suite passed with 43 tests using
  `swift test --package-path apps/macos-native` after the first ASS
  implementation.

Required parser coverage:

- ASS `[Events]` `Format:` field mapping.
- `Dialogue` event parsing with non-default field order.
- `Comment` events excluded from searchable subtitles.
- Override-tag removal for documented `{...}` cases.
- ASS line-break normalization for documented `\N` cases.
- Exact-time cue grouping by subtitle file, `start_ms`, and `end_ms`.
- Near-equal ASS timestamps not grouped by tolerance.
- Cue lines preserved without deduplication.
- Stable display-order fallback to source event order when layout projection is
  unavailable.

Required database and search coverage:

- Fresh schema creation for cue groups and cue lines.
- Migration from the previous supported schema version.
- Migration preserves durable configuration and rebuilds derived subtitle index
  data.
- FTS rows link to cue groups.
- Search returns individual Cue lines.
- A query that matches one cue line returns that Cue as the primary result; Cue
  Group context is a separate optional presentation projection.
- Query terms split only across different cue lines do not produce a result.
- Multiple matching Cues in one Cue Group remain distinct results and counts.
- Migrating a supported legacy Shiori schema preserves Shiori row IDs and Cue
  relations while schema version `41` removes the legacy Shiori Tag tables and
  assignments. Fresh schema coverage must verify that those tables and indexes
  are absent.
- Search results remain scoped to currently selected folders.

Required integration coverage:

- Index a fixture folder containing `.srt` and `.ass` files.
- Prefer `Movie.commentary.mp4` for `Movie.commentary.ass` when both it and
  `Movie.mp4` exist, and fall back to `Movie.mp4` when the complete-basename
  video is absent.
- Reindex after an ASS file changes and rebuild its cue groups and cue lines.
- Remove a configured folder and verify ASS-derived rows no longer appear in
  search results.
- Select an ASS search result and resolve it to matched video path plus
  `start_ms`.

Playback verification for the first ASS step:

- Clicking an ASS search result opens or updates the Playback Area.
- Playback opens the matched video and seeks to the selected Cue's `start_ms`.
- Source ASS subtitle rendering is not required for this first ASS step.

## 17. ASS Renderer Routing Coverage

CueSeeker currently supports a single active ASS playback renderer: the
`libass`-backed source-faithful overlay.

Required routing coverage:

- ASS search results load the source `.ass` file, or the matching
  source-derived render segment, for playback rendering.
- Playback attaches `SourceFaithfulASSSubtitleOverlayView` for ASS subtitle
  sources.
- Playback does not attach native ASS or ASS Lite fallback overlays.
- Settings does not expose an ASS renderer selector.
- The existing subtitle visibility control shows and hides the `libass` overlay.
- The overlay follows both the Playback Area and playback fullscreen.
- Missing or unreadable subtitle files do not prevent video playback.
- SRT playback subtitle behavior does not regress.

Known deferred behavior should remain documented when tests cover graceful
degradation cases.

## 18. Source-faithful ASS Rendering Pipeline Coverage

The source-faithful ASS rendering pipeline is complete only after search,
playback startup, render preparation, and complex ASS rendering behavior are
verified separately.

CueSeeker currently has one active ASS playback renderer: the `libass`-backed
source-faithful overlay. Tests should verify that ASS playback routes to this
overlay only, Settings does not expose an ASS renderer picker, and native ASS or
ASS Lite fallback renderers are not reachable from the active playback path.

Required `libass` manual checks:

- Common ASS dialogue appears correctly enough for subtitle-context review.
- Complex ASS samples with vector drawing, clipping, karaoke, transforms, and
  short-duration events render through the source `.ass` file or a
  source-derived render segment.
- Font behavior must be checked against real samples using only
  system-installed fonts and platform fallback. Reference comparisons must not
  depend on adjacent font folders, extracted video-container font attachments,
  or app-owned external font caches.
- File-boundary checks must verify that indexing and playback ignore unsupported
  sibling files and sidecar asset folders, including fonts, images, loose text
  files, archives, and other non-video/non-subtitle resources.
- Video-container attachment checks must verify that font, image, or document
  attachments are not extracted or materialized for ASS playback.
- macOS system-font aliasing must be checked with a real installed font whose
  ASS name differs from its CoreText family or PostScript name, such as
  `方正准圆_GBK` resolving to `FZZhunYuan-M02`. The check must verify that
  playback does not fall back to `Helvetica` or another unrelated face, and it
  must cover both full-source ASS loading and indexed render-segment loading
  when render segments are available.
- Subtitle output maps to the displayed video rectangle.
- Playback, seek, subtitle visibility toggling, Playback Area, and Theater
  Mode remain stable.
- Search result selection and video open or seek do not wait for ASS renderer
  loading or rendering.

Required search projection coverage:

- Real dialogue and lyric text remains searchable.
- Vector drawing path commands such as `m ... b ...` are not returned as search
  result text.
- Repeated visual-effect fragments do not create duplicate user-facing search
  results unless they contain distinct readable subtitle text.
- Each Cue's own timing remains stable and is the Search/playback action target.
  Cue Group timing remains available for derived recall and optional context
  but must not replace the selected Cue's start time.

Required render timeline coverage:

- Timed `Dialogue` events are preserved for playback rendering even when they
  use `Effect=fx`.
- `\p` vector drawing events remain in the render timeline.
- `\clip`, `\iclip`, `\pos`, `\move`, blur, alpha, border, scale, and karaoke
  metadata remain available to the renderer.
- Short-duration and zero-duration events do not corrupt timeline indexing or
  cancellation behavior.
- Cache invalidation uses source subtitle path, file size, modified time, and
  renderer version.
- Time-windowed preparation uses indexed cue-group timing to choose the selected
  cue window and nearby deterministic windows while still retrieving exact
  render payload from the source `.ass` file.
- Partial timeline caches are keyed by both source file identity and prepared
  time window, and they invalidate when the source subtitle file changes.
- Large ASS render-segment caches must be verified at the indexing and playback
  boundary: indexing stores segment scripts, unchanged reindex skips only when
  those segments exist, and legacy `libass` can load the segment from memory for
  the current timestamp.
- Full-source ASS loading and indexed render-segment loading must both preserve
  the system-font-only boundary. Render segments must not receive a renderer
  font directory or extracted attachment cache.
- Font-alias unit coverage should verify that ASS style `Fontname` fields and
  inline `\fn...` override tags can be rewritten in a render-only script while
  preserving the original subtitle source and search projection.
- Playback subtitle source tests must verify that ASS playback can carry source
  subtitle identity without reintroducing external font-resource context, an ASS
  renderer picker, or a native ASS fallback route.
- Legacy `libass` unchanged-frame reuse must be tested with a static ASS sample:
  the first cropped render should produce a visible payload, and a subsequent
  unchanged timestamp in the same static interval should return no cropped
  payload so the playback overlay can reuse the existing layer contents.
- Complexity-aware ASS segmentation tests must cover the 256 KB activation
  threshold, low-complexity widening, and dense effect regions shrinking to
  shorter windows without dropping overlapping source events.
- Regression checks for the segmenter should include a real complex ASS sample
  with a dense effect section followed by ordinary dialogue, verifying that the
  indexed windows shrink only around the dense section and widen again after it.
- ASS render-segment cache migration tests must verify that older segmentation
  algorithm versions are ignored for unchanged source files and rebuilt on the
  next indexing pass.

Required non-blocking playback checks:

- Selecting a large ASS search result updates the selected row before ASS source
  parsing finishes.
- Opening or seeking video does not wait for ASS parsing or renderer
  initialization.
- Stale ASS preparation tasks are cancelled when another result is selected.
- Subtitle rendering can attach later and catch up to the current playback time.
- ASS rendering failure does not stop video playback or playback controls.

Required renderer checks:

- Leading `\fs`, `\fscx`, and `\fscy` size overrides affect ordinary dialogue
  sizing in native `v0`.
- Complex ASS fixtures with vector drawing, clipping, and karaoke-like repeated
  effect events render without treating drawing commands as text.
- Playback Area and playback fullscreen use the same renderer output
  lifecycle.
- Subtitle visibility toggles renderer output without stopping the video.
- SRT playback subtitle behavior does not regress.

## 19. Cue-Centric Table And Playback Multi-Module Overlay Coverage

Search, Shiori, Context, and the Playback Multi-Module Overlay are complete only
when their individual-Cue identity, dynamic geometry, module state, and
invalidation boundaries are verified together.

Required Cue-table coverage:

- Search pagination and exact result counts use individual Cues. Multiple
  matching Cues from one Cue Group remain separate rows with separate stable
  identities and action targets.
- Search and Search-hosted Context use the Search table columns; Shiori uses its
  declared Cue, time, and date columns. All three surfaces use the same
  native virtual Cue-table geometry and interaction contract.
- Shiori search updates from each input change, reuses Search's Primary Cue
  matcher without matching Display Title, and exposes its exact result count
  only after the current resident projection is complete.
- A one-line primary Cue with no additional context resolves to 40 points; each
  additional primary visual line adds 24 points and each additional Cue Group
  visual line adds 20 points. Tests must count source line breaks and automatic
  wrapping and verify the general `16 + 24P + 20S` formula.
- Complete primary and optional additional Cue text is rendered without
  clipping, truncation, ellipsis, a maximum line count, or a character limit.
- `Show Cue Group` defaults to Off, persists across launches, and uses a native
  macOS switch below Search Scope. Off renders only the primary Cue; On renders
  every additional Cue below it while all selection and actions continue to use
  the primary Cue.
- Toggling `Show Cue Group` or changing the Cues-column width remeasures only
  visible rows plus overscan. It must not rerun Search, rebuild the row identity
  snapshot, change Context scope, reload Shiori data, change counts, reorder
  rows, retarget actions, or recreate the playback render host.
- Dynamic reflow preserves a stable scroll anchor consisting of the primary Cue
  identity and its first visual line's screen-space position. Probe tests must
  distinguish Search, Context, and Shiori measurement, draw, owner-update, and
  anchor-correction counters.

Required Playback Multi-Module Overlay coverage:

- Opening Current at a timestamp inside a Cue Group selects that group's
  physically bottommost Cue in stable source display order. With no active Cue,
  selection falls back to the nearest preceding Cue, then the first Cue.
- The initial snapshot contains 10 Cues when available, preferring six before
  and three after the selected Cue, with stable Cue identity independent of the
  transient window index.
- Current natural Cue height is `max(52L, typographic stack height) + 24`;
  one-, two-, and three-line Cues therefore measure 76, 128, and 180 points for
  the current fonts. Every adjacent typographic Visual Line inside one Cue is
  separated by exactly five points. Resolved height is clamped to the reel
  viewport while the complete Cue value remains available to actions.
- A fitting Cue displays every visual line and centers its complete bounds on
  the fixed Focus Anchor. An oversized Cue uses accepted head-first placement:
  its resolved top aligns to the reel viewport top, its first visual line stays
  the visible origin whenever it settles, and only trailing display content may
  be clipped.
- Resizing or width-dependent wrapping preserves stable selected Cue identity,
  recomputes natural and resolved height, and restores the selected Cue to its
  accepted placement.
- Playlist, Search, and Shiori use one shared bounded virtual Reel, Result
  renderer, dynamic extent path, Focus Anchor, scrollbar, motion, and recycling
  contract. Primary and optional Cue Group lines retain the same strict
  five-point internal typographic gap; Playlist alone shows the one-based
  playback-origin sequence number.
- Playlist preserves the established Search or Shiori source count, identity,
  order, Exact progress, and navigation scope. Playback Search shares the
  Workbench Search query, current persisted facet Filter, filtered resident
  result projection, and pipeline; standalone Shiori reads the shared
  persisted Shiori order. Virtualization is render-only.
- Recent and Library reuse their existing card layouts. Directional selection
  follows visible geometry, defaults to the first available item, and preserves
  exact native scroll offsets. Visible-Pointer Hover selects available items;
  selection uses the existing Hover visual without a Focus Ring. Library
  independently preserves Folder and Episode state; Back clears only Detail
  and restores Folder selection and offset.
- Module switching preserves Current, each Result Reel, Playback Search,
  Recent, and both Library levels inside one Session. A newly saved Shiori that
  prepends the database order must preserve an already selected Shiori by
  Result identity, not by its previous ordinal.
- `S`, `C`, and Enter target the exact settled Primary Cue in Current, Playlist,
  and Shiori. Tests verify idempotent save, complete-text copy with source line
  breaks, exact start-time continuous play, and once-only deferred execution.
  Search responds only to settled Enter; Recent and Library Enter reuse their
  existing primary playback actions.
- Normal playback before Enter creates no Overlay Session or module data.
  Closing or replacing the playback source releases Current batches, virtual
  windows, Search runs, Recent and Library snapshots, selections, scroll state,
  observers, and measurement caches. Database readers must cooperatively stop
  long row iteration after cancellation, and late work cannot publish into a
  closed or newer Session.
