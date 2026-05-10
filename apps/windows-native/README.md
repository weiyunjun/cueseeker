# CueSeeker Windows Native App

This directory is the starting point for the production Windows client.

The Windows app is a C# + WinUI 3 shell. It is not a playback lab and should
not launch `CueSeekerWindowsPlaybackLab.exe` as its production playback route.
Playback should flow through `CueSeekerPlaybackNative.dll`.

## Current Bootstrap

Implemented in this first scaffold:

- WinUI 3 application project structure.
- A three-region placeholder layout matching the planned Windows shell shape:
  directory list, video surface, and search area.
- A central `SwapChainPanel` reserved for native Direct3D presentation.
- A C# native playback host that can locate `CueSeekerPlaybackNative.dll`,
  capture the `SwapChainPanel` native WinRT pointer, and call the native inspect
  API.

Not implemented yet:

- Binding the C++ backend swap chain to the `SwapChainPanel`.
- Database, folder settings, indexing, and search services.
- Playback controls, shortcuts, bookmarks, or subtitle text actions.

## Local Tooling

The project targets Windows App SDK `1.8.260317003`, the latest stable release
listed by Microsoft Learn at the time this scaffold was created. Building this
project requires a .NET SDK and Windows App SDK restore support. The current
local machine only has the .NET runtime installed, so the C++ backend can be
validated locally before this WinUI project is built.
