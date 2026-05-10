# CueSeeker Windows Playback Lab

This directory contains the first Windows-native playback lab for CueSeeker.

The lab is intentionally separate from the future Windows app shell. Its job is
to validate the playback foundation first: media inspection, Direct3D rendering,
Windows audio capability probing, FFmpeg decode behavior, `libass` availability,
and structured diagnostics.

## Current Scope

Implemented in this bootstrap:

- CMake/MSVC project skeleton.
- DXGI adapter and D3D11 device probing.
- WASAPI default render endpoint probing.
- D3D11 render smoke test.
- Structured JSON system report output.
- PowerShell environment check and build helpers.

Implemented when FFmpeg and `libass` development packages are available:

- FFmpeg media open and stream inspection.
- `libass` version probing.
- Basic software video decode through FFmpeg with BGRA upload to a D3D11
  textured quad.

Not implemented yet:

- D3D11VA/DXVA hardware decode.
- WASAPI audio output.
- `libass` subtitle overlay composition.
- Structured playback event stream.
- Long-play stability and seek stress tests.

## Required Local Tools

The current Windows machine already has FFmpeg command-line tools in `PATH`, but
the C++ lab needs development packages, not only `ffmpeg.exe`.

Required for the bootstrap executable:

- Visual Studio 2022 or newer Build Tools with C++ desktop tools.
- Windows SDK.
- CMake.

Required for FFmpeg-backed media inspection and `--play`:

- FFmpeg development package with `include/` and `lib/`.
- `libass` development package with `include/` and `lib/`.

Environment variables:

```powershell
$env:FFMPEG_ROOT = "D:\path\to\ffmpeg-dev"
$env:LIBASS_ROOT = "D:\path\to\libass-dev"
```

Expected layout examples:

```text
%FFMPEG_ROOT%\include\libavformat\avformat.h
%FFMPEG_ROOT%\lib\avformat.lib
%LIBASS_ROOT%\include\ass\ass.h
%LIBASS_ROOT%\lib\ass.lib
```

## Environment Check

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/check-env.ps1
```

The check reports installed tools, FFmpeg CLI capabilities, development package
paths, Windows version, CPU, GPU, and hardware acceleration methods visible to
the FFmpeg CLI.

## Build

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/build.ps1
```

Optional generator override:

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/build.ps1 -Generator "Visual Studio 17 2022"
```

The helper can also use Visual Studio's bundled CMake when `cmake.exe` is not
available in the shell `PATH`.

## Run

Inspect a media file:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --inspect "D:\media\sample.mkv"
```

Run a D3D11 rendering smoke test:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --render-test
```

Play video frames through the first software decode path:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --play "D:\media\sample.mkv" --seek-ms 30000 --duration-ms 15000
```

Without the FFmpeg development package, `--inspect` still reports system, D3D11,
WASAPI, and dependency status, but media stream inspection and `--play` are
disabled. The first playback path intentionally reports that audio output and
subtitle overlay are not implemented yet. It is a video/rendering foundation for
W0, not the final Windows playback engine.
