# Changelog

All notable milestone-level project changes are recorded in this file.

This changelog does not replace Git history. Git records concrete file changes. This file records meaningful project progress and milestone outcomes.

## Unreleased

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
