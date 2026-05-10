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
