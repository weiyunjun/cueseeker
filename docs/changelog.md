# Changelog

All notable milestone-level project changes are recorded in this file.

This changelog does not replace Git history. Git records concrete file changes. This file records meaningful project progress and milestone outcomes.

## Unreleased

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
  playback history and future favorites should remain intact and show
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
  should handle Library, Timeline, and Favorites-style precise location, and
  the right learning panel should handle Search, Queue, and configurable
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
- Adopted "Main Workspace" as the standard nomenclature for the center content region to support future scalability (e.g., Favorites).
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
