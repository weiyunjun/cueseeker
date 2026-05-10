# CueSeeker Windows Native App

This directory is the starting point for the production Windows client.

The Windows app is a C# + WinUI 3 shell. It is not a playback lab and should
not launch `CueSeekerWindowsPlaybackLab.exe` as its production playback route.
Playback should flow through `CueSeekerPlaybackNative.dll`.

## Current Bootstrap

Implemented in the current bootstrap:

- WinUI 3 application project structure.
- A three-region shell matching the planned Windows app shape: left Library,
  center playback surface, and right Search/Shiori panel.
- A fixed Settings footer row at the bottom of the left sidebar.
- A Settings surface with `Library` and `Decode` categories.
- `Library` Settings folder management and `Index Now`.
- A Windows SQLite database with macOS-aligned table names and core semantics
  for search paths, subtitle files, video files, subtitle-video matches, cue
  groups, cue lines, Library rows, and Shiori records.
- Subtitle scanning for `.srt` and `.ass`.
- Same-directory basename video matching with simple language-suffix removal.
- Derived display aliases based on parent folder plus natural-sort sibling
  rank.
- Library hydration from persisted playable-video rows.
- Search over indexed cue groups with line-level match validation.
- Search result selection that resolves video path, subtitle path, and
  `start_ms`, then calls `CueSeekerPlaybackNative.dll`.
- A central `SwapChainPanel` reserved for native Direct3D presentation.
- A C# native playback host that can locate `CueSeekerPlaybackNative.dll`,
  capture the `SwapChainPanel` native WinRT pointer, call the native inspect
  API, and start native playback requests.

Not implemented yet:

- Binding the C++ backend swap chain to the `SwapChainPanel`.
- In-app swapchain presentation; the current native playback API still presents
  through the backend's existing Win32 playback window.
- Playback controls, shortcuts, Shiori save/remove actions, or subtitle text
  copy actions.
- Full macOS parity for advanced indexing/search edge cases.

## Local Tooling

The project targets Windows App SDK `1.8.260317003`, .NET 8, and Windows SDK
`10.0.26100.0` for compilation. The app keeps
`TargetPlatformMinVersion=10.0.19041.0`, but local WinUI/CsWinRT builds require
the compile-time Windows SDK to be installed.

The WinUI project pins x64 through `PlatformTarget=x64` and
`RuntimeIdentifier=win-x64`. For command-line validation, run the `.csproj`
directly and do not pass `Platform=x64` to `dotnet run`; `dotnet run` looks for
the non-solution output path when launching the app.

## Manual Validation

After installing a .NET 8 SDK and Windows SDK `10.0.26100.0`, build the native
backend, then build and run the Windows app:

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/build.ps1 -Configuration Debug
dotnet build apps/windows-native/CueSeeker.Windows/CueSeeker.Windows.csproj -c Debug
dotnet run --project apps/windows-native/CueSeeker.Windows/CueSeeker.Windows.csproj -c Debug
```

Then validate:

1. Open `Settings` from the left sidebar footer.
2. In `Library`, add a media folder such as `D:\影视`.
3. Run `Index Now`.
4. Confirm the left Library shows folder rows and numbered episode buttons.
5. Search for subtitle text in the right Search panel.
6. Click a Search result and confirm native playback starts at that cue
   timestamp with the selected external subtitle file.
7. Check `%LOCALAPPDATA%\CueSeeker\Windows\last-playback.json` for the selected
   decode path and playback report.
