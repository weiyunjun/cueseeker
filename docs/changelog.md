# Changelog

All notable milestone-level project changes are recorded in this file.

This changelog does not replace Git history. Git records concrete file changes. This file records meaningful project progress and milestone outcomes.

## Unreleased

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
