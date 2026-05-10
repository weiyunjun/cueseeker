# CueSeeker Playback Native

This directory contains the Windows native playback backend source.

`CueSeekerPlaybackNative.dll` is the production-facing native boundary for the
Windows app. The command-line playback lab remains useful as a diagnostics
harness, but it should call this backend rather than owning the playback core.

Current exported API:

- `CueSeekerPlaybackInspectJson`
- `CueSeekerPlaybackPlay`
- `CueSeekerPlaybackRunRenderTest`
- `CueSeekerPlaybackFreeString`

The first DLL extraction still uses the existing lab window presenter for video
output. The next backend step is to add a WinUI `SwapChainPanel` presenter so
the Windows app can render video inside its own visual tree.
