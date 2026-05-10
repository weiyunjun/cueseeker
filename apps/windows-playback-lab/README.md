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
- External ASS subtitle probing through `libass`.
- Embedded subtitle stream and attachment metadata reporting.
- Basic software video decode through FFmpeg with BGRA upload to a D3D11
  textured quad.
- Basic audio decode and resampling through FFmpeg with shared-mode WASAPI
  output to the default Windows render endpoint.
- External ASS subtitle overlay through `libass` on the software video path.
- Structured playback report output for `--play`, including selected streams,
  decode path, rendered frame counts, WASAPI output, ASS overlay status, and
  coarse process CPU/memory counters.
- D3D11VA hardware decode capability probing.
- First D3D11VA playback path with software fallback. Hardware decoded frames
  are transferred back to system memory before the existing BGRA/D3D11 render
  upload, so this validates hardware decode availability before the final
  zero-copy rendering path exists.

Not implemented yet:

- Structured playback event stream.
- Zero-copy D3D11 hardware-frame presentation.
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

The helper below can install Gyan's official release full shared FFmpeg package
under the ignored local `deps/` directory, verify its SHA-256 file, extract it,
and generate MSVC import libraries from the FFmpeg DLL exports:

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/install-ffmpeg-shared.ps1
. apps/windows-playback-lab/deps/ffmpeg-release-full-shared/cueseeker-ffmpeg-env.ps1
```

That package provides the FFmpeg headers and DLLs needed for `--inspect` and
`--play`.

The helper below installs the MSYS2 UCRT64 `libass` package and its runtime
dependencies under the ignored local `deps/` directory, extracts the public
headers and DLLs, and generates a MSVC import library from `libass-*.dll`:

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/install-libass-msys2.ps1
. apps/windows-playback-lab/deps/msys2-ucrt64-libass/cueseeker-libass-env.ps1
```

The build, environment check, and run helpers automatically load both local
environment helpers when they exist.

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

Generate a small legal fixture for local validation:

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/make-fixture.ps1
```

The fixture includes H.264 video, AAC audio, an embedded ASS subtitle stream,
an attachment, and a matching external `.ass` file for subtitle probe testing.

Then rebuild and run:

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/build.ps1
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/run-lab.ps1 apps/windows-playback-lab/out/fixtures/windows-lab-sample.mkv -SubtitlePath apps/windows-playback-lab/out/fixtures/windows-lab-sample.ass
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/run-lab.ps1 apps/windows-playback-lab/out/fixtures/windows-lab-sample.mkv -Play -SubtitlePath apps/windows-playback-lab/out/fixtures/windows-lab-sample.ass -Decode auto -SeekMs 1000 -DurationMs 2500 -ReportPath apps/windows-playback-lab/out/reports/windows-lab-sample-playback.json
```

Or run the full local smoke path:

```powershell
powershell -ExecutionPolicy Bypass -File apps/windows-playback-lab/tools/verify-smoke.ps1
```

## Run

Inspect a media file:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --inspect "D:\media\sample.mkv"
```

Inspect a media file with an external ASS subtitle probe:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --inspect "D:\media\sample.mkv" --subtitle "D:\media\sample.ass"
```

Run a D3D11 rendering smoke test:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --render-test
```

Play video, audio, and external ASS subtitles through the first software decode
path:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --play "D:\media\sample.mkv" --subtitle "D:\media\sample.ass" --decode software --seek-ms 30000 --duration-ms 15000
```

Use automatic decode selection. The lab tries D3D11VA first and falls back to
software decode when the device or decoder cannot be opened:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --play "D:\media\sample.mkv" --subtitle "D:\media\sample.ass" --decode auto --seek-ms 30000 --duration-ms 15000 --report-path "apps\windows-playback-lab\out\reports\sample-playback.json"
```

Force D3D11VA and write a playback report:

```powershell
apps/windows-playback-lab/build/Debug/CueSeekerWindowsPlaybackLab.exe --play "D:\media\sample.mkv" --subtitle "D:\media\sample.ass" --decode d3d11va --seek-ms 30000 --duration-ms 15000 --report-path "apps\windows-playback-lab\out\reports\sample-d3d11va-playback.json"
```

Without the FFmpeg development package, `--inspect` still reports system, D3D11,
WASAPI, and dependency status, but media stream inspection and `--play` are
disabled. The first D3D11VA path intentionally transfers decoded frames back to
system memory before rendering; it proves hardware decode can run and report
fallback behavior, but it is not the final Windows playback engine.
