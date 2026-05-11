# CueSeeker Playback Native

This directory contains the Windows native playback backend source.

`CueSeekerPlaybackNative.dll` is the production-facing native boundary for the
Windows app. The command-line playback lab remains useful as a diagnostics
harness, but it should call this backend rather than owning the playback core.

Current exported API:

- `CueSeekerPlaybackInspectJson`
- `CueSeekerPlaybackPlay`
- `CueSeekerPlaybackCreateSwapChainPanelPresenter`
- `CueSeekerPlaybackDestroyPresenter`
- `CueSeekerPlaybackStopPresenter`
- `CueSeekerPlaybackRunRenderTest`
- `CueSeekerPlaybackFreeString`

`CueSeekerPlaybackPlay` accepts an optional WinUI `SwapChainPanel` native
pointer, physical render size, and XAML rasterization scale. The Windows app
first creates a native presenter on the UI thread with
`CueSeekerPlaybackCreateSwapChainPanelPresenter`, then passes that presenter to
`CueSeekerPlaybackPlay` for background playback. The presenter owns a DXGI
composition swap chain attached to the app visual tree and applies the inverse
scale transform required for high-DPI `SwapChainPanel` rendering. The lab CLI
still omits those fields and uses the standalone diagnostics window.
The app calls `CueSeekerPlaybackStopPresenter` before replacing an active
session so the previous playback loop can exit and release resources.
