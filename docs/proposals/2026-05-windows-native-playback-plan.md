# Windows Native Playback Plan

Status: Draft

## Background

CueSeeker is currently implemented as a native macOS app. The accepted macOS
direction uses a project-owned playback backend built around FFmpeg demuxing,
VideoToolbox hardware decode, FFmpeg software decode fallback, native audio
output, and a `libass` source-faithful ASS overlay.

The project is now considering Windows as a first-class desktop platform.
Windows support should not be treated as a quick UI port. CueSeeker's core
workflow depends on local media playback, precise timestamp seek, ASS subtitle
rendering, mounted network storage behavior, and diagnostic control over
playback failures. These requirements make playback architecture a platform
foundation rather than a late integration detail.

Earlier discussions considered using `mpv`, `libVLC`, or GStreamer as a
Windows playback backend. Those projects remain useful references and
comparison tools, but the current proposed direction is to start Windows from a
project-owned native playback backend rather than shipping a third-party player
framework as the main production route.

The macOS playback direction is not changed by this proposal.

## Goals

- Treat Windows as a first-class desktop platform.
- Keep the current macOS native playback direction unchanged.
- Build the Windows playback foundation before migrating the full application
  shell and existing product architecture.
- Use mature media libraries for high-risk media parsing and rendering instead
  of writing custom codecs, demuxers, or ASS renderers.
- Own the Windows playback orchestration layer so CueSeeker can diagnose,
  optimize, and eventually harden playback behavior.
- Validate Windows playback against real local libraries before committing to a
  full Windows client.
- Preserve a future path toward shared product contracts, database semantics,
  fixtures, and compatibility reports across macOS and Windows.

## Non-goals

- Do not replace the current macOS playback backend as part of this proposal.
- Do not use `mpv`, `libVLC`, VLC, or GStreamer as the planned primary Windows
  production playback framework.
- Do not write custom video codecs, audio codecs, media container demuxers, or
  a custom full ASS renderer.
- Do not promise universal playback compatibility in the first Windows
  milestone.
- Do not make the first Windows milestone depend on a complete WinUI product
  shell.
- Do not introduce cross-device sync, cloud services, or account systems in the
  first Windows playback milestone.

## Proposed Direction

Windows development should start with a dedicated playback lab rather than a
full application shell.

The first Windows implementation target should be:

```text
Windows Playback Lab
Open local or mounted-network media
Inspect container, streams, codecs, pixel formats, and attachments
Decode video through D3D11VA/DXVA when available
Fallback to FFmpeg software decode when practical
Render video through Direct3D
Decode and output audio through a Windows-native audio path
Render ASS subtitles through libass
Seek accurately to subtitle timestamps
Emit structured compatibility and failure diagnostics
```

The playback lab should become the evidence base for deciding when the Windows
client is ready to integrate the existing CueSeeker search, Library, Shiori, and
settings workflows.

## Architecture

The intended long-term Windows shape is:

```text
Windows App
  C# + WinUI 3 application shell
  Search, Library, Shiori, Settings, and playback UI state

Windows Native Playback Backend
  C++ playback engine
  FFmpeg demuxing and software decode
  D3D11VA/DXVA hardware decode
  Direct3D video rendering
  Windows-native audio output
  libass ASS subtitle overlay
  Structured diagnostics and compatibility reports

Shared Project Assets
  Product behavior contracts
  SQLite schema and migration rules
  Subtitle parsing/search semantics
  Cross-platform fixtures
  Playback compatibility samples and reports
```

The Windows playback backend should expose CueSeeker-owned concepts rather than
third-party-player concepts:

```text
PlaybackRequest
PlaybackSession
PlaybackClock
PlaybackCommand
PlaybackError
PlaybackCapabilityReport
```

The app layer should not depend on FFmpeg, Direct3D, WASAPI, or `libass`
implementation details directly.

## Third-Party Player Role

Third-party players remain useful but should not define the Windows production
architecture.

Allowed roles:

- Reference playback behavior.
- Memory and CPU comparison.
- Codec/container compatibility comparison.
- Visual ASS rendering comparison.
- Temporary diagnostic baseline when investigating a sample.

Non-goals for the planned Windows production path:

- Embedding `mpv` as the primary shipped playback backend.
- Embedding VLC or `libVLC` as the primary shipped playback backend.
- Building the first Windows player around GStreamer pipelines.

This position may be revisited only if the native Windows playback lab shows
that the project-owned backend is not viable for the product's performance,
compatibility, or maintenance constraints.

## Compatibility Strategy

Windows compatibility must be treated as an explicit test matrix, not as an
assumption.

The playback lab should report:

- Windows version and build.
- CPU model.
- GPU vendor, device, and driver version.
- Direct3D feature level.
- Hardware decode capability by codec and profile where discoverable.
- Selected decode path for each sample.
- Container, video, audio, subtitle, font, and attachment facts.
- Local path, mapped network drive, or UNC path classification.
- Seek result and failure reason.
- Memory and CPU observations for representative playback windows.

Initial compatibility should be validated on the available Windows 11 Intel CPU
and Nvidia GPU machine. AMD CPU, AMD GPU, Intel GPU, and additional driver
coverage should be collected through later community compatibility reports or
additional test hardware.

The first Windows release should not claim compatibility with hardware profiles
that have not been tested.

## Near-Term Lab-to-App Plan

The current W0 lab has proven a basic software playback path: FFmpeg demuxing
and software video decode, D3D11 presentation, WASAPI shared-mode audio output,
external ASS parsing, and external ASS overlay through `libass`.

The next work should avoid trying to make the standalone lab perfect before the
Windows app can exercise it. Previous project experience suggests that many
important defects only appear once playback is driven by real app state,
navigation, file selection, subtitle selection, window lifetime, and user
commands. A standalone lab that appears perfect is not sufficient evidence for
product readiness.

Near-term work should therefore proceed in this order:

1. Add a structured playback report for `--play`.
   The report should identify the selected streams, requested decode path,
   actual decode path, audio endpoint, subtitle source, first-frame timing,
   decoded/rendered frame counts, and failure stage.
2. Add lightweight performance sampling.
   The lab should report process memory and coarse CPU observations for a short
   playback window. This is a baseline signal, not a benchmark suite.
3. Add D3D11VA/DXVA capability probing.
   The probe should identify available hardware decode support by adapter,
   codec, and profile where practical, without claiming compatibility beyond
   tested hardware.
4. Add an initial D3D11VA playback path with software fallback.
   The report must explicitly state whether playback used hardware decode or
   software decode.
5. Run a small real-media smoke set.
   Developer-local media roots, currently including `D:\影视`, may be used for
   manual validation. These files are local test inputs, not repository
   fixtures, not a compatibility guarantee, and not a reason to delay app
   integration for broad matrix work.
6. Define the first app integration boundary.
   Once basic hard decode, software fallback, audio output, and subtitle overlay
   work against a few representative files, the lab should be wrapped behind
   CueSeeker-owned playback request/report concepts so the Windows app can start
   driving real playback scenarios.

The first app integration boundary does not need every advanced player feature.
It should be enough to open a media file, select or pass an external ASS
subtitle, start playback, observe the selected decode path, and receive a
structured failure or summary report.

## Windows Client Bootstrap Decisions

The first Windows client should not invent temporary product semantics in order
to move faster. It should use the existing CueSeeker product contracts as the
source of truth and implement only the amount of UI needed to exercise them
inside the Windows app.

Initial Windows app integration should follow these decisions:

- The Windows client should reuse the macOS database architecture, indexing
  semantics, Library semantics, Search semantics, Shiori semantics, and
  Settings categories where practical. If a macOS behavior cannot yet be
  represented on Windows, the gap should be documented instead of hidden behind
  a Windows-only transitional rule.
- The initial main window should follow the accepted three-area workbench:
  Library on the left, playback in the center, and the right-side panel for
  Search and Shiori modes.
- The left Library should be driven by the indexed playable-video model
  described in the product documents. It should not introduce a separate
  temporary grouping model merely for the Windows bootstrap.
- Search result selection should immediately select the result, open or update
  the matching video, and seek to the selected cue group's `start_ms`. When the
  matching video is already open, the app should prefer seeking over reloading
  when practical.
- Shiori is the accepted product, UI, and code-domain name for saved subtitle
  cues. The Windows right-side mode button should remain present as `Shiori`
  during the bootstrap even if the first implementation shows an empty
  development state before durable Shiori integration is wired.
- The first Windows Settings entry should live as a fixed footer row at the
  bottom of the left Library/sidebar area. The placement should follow the
  reference sidebar pattern: a gear icon and `Settings` label anchored below the
  main Library content, not a control inside the playback surface. The button
  should open a Settings surface whose layout follows the accepted macOS
  standalone Settings model: a two-column window with `Library` and `Decode`
  categories.
- Windows `Library` Settings should provide folder management and the `Index
  Now` action using the same indexing behavior as macOS. Windows `Decode`
  Settings should manage the persisted decode preference used by the native
  playback backend.
- Opening or closing Settings must not pause playback, switch the right-side
  mode, clear the Search query, clear the selected Search result, or rebuild
  Library/Search/Shiori presentation state unnecessarily.
- Custom Windows titlebar work and Mica polish are deferred for the bootstrap.
  The early Windows app may use standard WinUI window behavior while playback,
  indexing, Library, Search, Settings, and Shiori integration are being wired.

These decisions define the first Windows app integration boundary. They do not
change the current macOS technical route or the accepted product semantics.

## Windows Client Bootstrap Implementation Sequence

The first usable Windows client should be built in small vertical slices so the
app can exercise real indexing, search, and playback behavior before advanced
polish.

Recommended sequence:

1. Translate the accepted Windows design into a WinUI layout skeleton using
   standard window behavior. Defer custom titlebar and Mica work.
2. Build the main three-area shell: left Library/sidebar, center playback
   surface, and right Search/Shiori panel.
3. Add the fixed left-sidebar Settings footer row with a gear icon and
   `Settings` label.
4. Add the Settings window shell with `Library` and `Decode` categories,
   following the macOS standalone Settings structure.
5. Establish the Windows app database location and SQLite access layer while
   preserving the macOS schema and migration semantics.
6. Wire `Library` Settings folder management: add folder, remove folder with
   confirmation, show configured folders, and run `Index Now`.
7. Port or mirror the macOS indexing behavior for subtitle files, playable
   videos, cue groups, search projection, and indexed Library rows.
8. Hydrate the left Library from the persisted indexed playable-video model.
   The Windows UI should not synthesize temporary grouping rules.
9. Implement the right Search panel against the indexed database, including
   grouped result presentation and selection state.
10. Connect Search result selection to playback intent resolution: identify the
    matching video, source subtitle file, and selected cue group's `start_ms`.
11. Bind the WinUI playback surface to the native Windows playback backend so
    playback happens inside the app instead of the standalone lab window.
12. Implement open-or-seek behavior: open the matching video when needed, or
    seek within the current video when practical, then start playback at the
    selected cue timestamp.
13. Pass the selected external subtitle file to the native backend and verify
    `libass` overlay inside the app surface.
14. Surface the selected decode path, hardware/software fallback, and playback
    failure report in developer-visible UI or logs.
15. Keep the Shiori right-side mode button present as `Shiori`; the initial
    panel may be empty until durable Shiori actions are wired.
16. Run a bounded end-to-end validation with local media: add a folder, index,
    populate Library, search subtitles, click a result, play in-app, seek to the
    cue timestamp, render subtitles, and confirm the playback report.

## W0 Testing Boundaries

W0 testing should be evidence-driven but intentionally bounded.

The lab should answer these questions before app integration begins:

- Can a representative H.264 or HEVC file open and display video?
- Does the playback path use D3D11VA/DXVA when requested or when auto-selected?
- Does software decode fallback work when hardware decode is unavailable or
  fails?
- Does WASAPI audio output start and continue during a short playback window?
- Does an external ASS subtitle file load and appear on video?
- Does the playback report capture decode path, basic timing, CPU/memory signal,
  and failure stage?

The lab should not spend W0 trying to exhaustively solve:

- Every codec, profile, container, subtitle style, and attachment case.
- Long-play stability across a large library.
- Perfect synchronization and frame pacing under every load.
- Full app-like lifecycle behavior outside the app.
- Final UI behavior, settings persistence, or production packaging.

Those issues should be revisited after the Windows app can drive the backend,
because the app integration will expose lifecycle, threading, windowing, and
state-management problems that the standalone lab cannot faithfully reproduce.

## Security Strategy

The Windows backend should assume that media and subtitle files may be
untrusted, including files from mounted NAS folders, mapped network drives, UNC
paths, downloads, and shared subtitle packages.

Security principles:

- Do not implement custom codecs or media container parsers.
- Do not implement a custom full ASS renderer.
- Keep FFmpeg and `libass` versions visible and updatable.
- Avoid loading user-global third-party player configuration, scripts, or
  plugins.
- Prefer structured error reporting over silent fallback.
- Treat crashes in media parsing, decoding, subtitle rendering, and native
  rendering as security-relevant until proven otherwise.
- Consider helper-process isolation before any broad public Windows release.

The project cannot guarantee the absence of media parsing vulnerabilities. The
goal is to reduce exposure, keep dependencies maintainable, and make failures
diagnosable.

## Data Model Impact

The Windows playback lab should not require a database schema change.

Future Windows client integration should preserve these cross-platform data
principles:

- Derived indexes are local and rebuildable.
- Durable user state must remain separate from platform-specific absolute paths.
- Library, Shiori, history, queue, and learning-session records should use
  stable logical identities where practical.
- Platform-local path bindings should be separate from logical media and cue
  identity.

Cross-device sync is out of scope for this proposal.

## Milestone Shape

### W0: Windows Playback Lab

Goal:

- Prove that a project-owned Windows playback backend can open, inspect, seek,
  and play representative local and mounted-network media with useful
  diagnostics.

Expected implementation scope:

- C++ command-line or minimal-window playback lab.
- FFmpeg media open and stream inspection.
- D3D11VA/DXVA capability probing.
- Direct3D video output.
- Windows-native audio output.
- `libass` overlay proof.
- Structured compatibility report output.

W0 should be considered sufficient for the first app integration attempt when a
small representative sample set can demonstrate:

- Basic playback success with video, audio, and external ASS overlay.
- A visible report of whether playback used hardware decode or software decode.
- A working software fallback path.
- Coarse CPU and memory observations for short playback windows.
- Structured failure stages for unsupported or failed samples.

### W1: Windows Playback Engine

Goal:

- Turn the playback lab into a reusable backend with CueSeeker-owned playback
  contracts.

Expected implementation scope:

- Stable playback request API.
- Open, seek, play, pause, close, rate, volume, and subtitle visibility
  commands.
- Structured playback event stream.
- Hardware/software decode selection.
- Failure reason taxonomy.
- Long-play memory and seek stability tests.

### W2: Windows Client Integration

Goal:

- Build the first Windows CueSeeker client around the validated playback engine.

Expected implementation scope:

- C# + WinUI 3 shell.
- Search, Library, Shiori, Settings, and playback UI integration.
- Shared database/search behavior where practical.
- Windows-specific file access and folder management.
- Windows packaging and release preparation.

## W0 Bootstrap Decisions

The initial Windows playback lab bootstrap uses the following decisions so
implementation can begin without waiting for the full Windows client design:

- Lab code lives under `apps/windows-playback-lab/`.
- The lab is a focused C++ playback and diagnostics workspace, not a WinUI
  product shell.
- The initial build entry point is CMake targeting MSVC and the Windows SDK.
- FFmpeg and `libass` must be supplied as development packages with headers and
  link libraries, discovered through `FFMPEG_ROOT` and `LIBASS_ROOT`.
- Windows system media and rendering APIs should come from the Windows SDK.
- The initial audio path is WASAPI shared mode because it is Windows-native,
  suitable for basic playback validation, and keeps latency or exclusive-mode
  tuning out of W0.
- The initial validation target is Windows 11 on the available Intel CPU and
  Nvidia GPU machine. Other Windows hardware profiles must be added through
  explicit compatibility reports before compatibility is claimed.
- `ffprobe`, `ffmpeg`, and `ffplay` may be used by scripts as environment
  diagnostics or comparison references. They must not become the planned
  production playback backend for the Windows app.

## Open Questions

- Should the Windows native playback backend live in the same repository as the
  macOS app from the first Windows commit, or should it start as a focused lab
  directory and be integrated later?
- Should the Windows playback lab initially use WASAPI directly, XAudio2, or a
  higher-level Windows audio wrapper?
- What sample set is sufficient to represent the user's real media library?
- What minimum Windows version should be documented before W1 begins?
- Which parts of the current Swift `CueSeekerCore` behavior should become
  shared specifications versus shared source code?
- What helper-process isolation boundary is required before a public Windows
  release?

## Acceptance Criteria

This proposal can be considered ready for ADR or stable engineering updates
when:

- The project owner accepts Windows as a first-class platform direction.
- The project owner accepts project-owned Windows native playback as the planned
  mainline direction.
- The project owner accepts that third-party players are comparison tools rather
  than the planned primary shipped backend.
- The first Windows playback lab scope is agreed.
- The repository structure for Windows lab code is decided.
- The minimum Windows version target is decided.
- Security and compatibility reporting expectations are documented well enough
  to guide implementation.

## Decision

Pending.
