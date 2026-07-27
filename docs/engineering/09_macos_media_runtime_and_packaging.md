# macOS Media Runtime and App Packaging

Status: Active

## 1. Purpose

This document defines the reproducible Apple Silicon media runtime and local
application packaging rules for CueSeeker.

Human-owned direction:

- `docs/human/requirements/20260712-Feature-Reproducible macOS Media Runtime And App Packaging.md`

## 2. Supported Platform

- Architecture: `arm64` only.
- Minimum deployment target: macOS 13.0.
- The directly distributed app and a future Mac App Store app must consume the
  same media runtime binaries.
- Distribution-specific signing, provisioning, sandboxing, and submission are
  outside the media runtime binary definition.

## 3. FFmpeg Baseline

- Source baseline: the official FFmpeg 8.1.2 release archive.
- CueSeeker must apply
  `third_party/ffmpeg/patches/ffmpeg-8.1-cueseeker-skip-internal-subtitles.patch`,
  rebased only as needed for FFmpeg 8.1.2.
- FFmpeg must be built as shared libraries with GPL and nonfree components
  disabled.
- The initial build keeps FFmpeg's built-in demuxers and decoders rather than
  using a narrow `--disable-everything` allowlist. Codec reduction requires a
  separate compatibility review.
- External GPL codec libraries such as x264 and x265 must not be linked.
- LAME 3.100 is included as an LGPL shared library because the existing Anki
  workflow exports MP3 audio through FFmpeg's `libmp3lame` encoder.
- dav1d 1.5.4 is included as a BSD-2-Clause shared library, and FFmpeg must be
  built with `--enable-libdav1d`. It provides the controlled software AV1
  decoder used when automatic cover extraction cannot use VideoToolbox. This
  dependency does not add an AV1 encoder.
- The `ffmpeg` command-line program is part of the app runtime because existing
  thumbnail, screenshot, and Anki export workflows invoke it. `ffplay`,
  `ffprobe`, documentation, static libraries, and debug symbols are excluded.
- The source URL, archive SHA-256, patch SHA-256, configure arguments, and build
  tool versions must be recorded with the staged runtime.

The required FFmpeg app libraries are:

- `libavformat`
- `libavcodec`
- `libavutil`
- `libswresample`
- `libswscale`

The required external codec libraries include `libdav1d` and `libmp3lame`.

## 4. libass Runtime

- libass and its non-system dependencies must be built from pinned source
  versions for `arm64` and macOS 13.0 or later.
- The runtime must use the CoreText font provider and must not depend on a
  Homebrew installation at runtime.
- The first controlled baseline is libass 0.17.4 with pinned FreeType, FriBidi,
  HarfBuzz, and libunibreak dependencies.
- Optional HarfBuzz integrations that pull in GLib, Cairo, ICU, or Graphite2
  should be disabled unless subtitle rendering verification proves they are
  required.
- Removal of FreeType image or compression support must be justified by font
  and subtitle regression coverage. The first packaging implementation may
  retain a small additional dependency rather than silently reduce rendering
  compatibility.

## 5. Reproducible Build Inputs

- Third-party source trees and compiled products are build artifacts and must
  not be committed to Git.
- Repository-owned manifests and scripts must pin source URLs and SHA-256
  values, download into a disposable build directory, and stage into one
  explicit media runtime prefix.
- `Package.swift` must consume one complete media runtime root. It must not mix
  headers and libraries from different roots and must not silently fall back to
  `/opt/homebrew` or `/private/tmp`.
- An explicit environment override may be retained for CI or diagnostics, but
  it must pass completeness checks before use.

## 6. Dynamic Library Layout

All shipped non-system dynamic libraries belong in:

```text
CueSeeker.app/Contents/Frameworks/
```

Rules:

- Each library install ID must be `@rpath/<versioned-library-name>`.
- Dependencies between bundled libraries must use `@rpath`.
- The main executable must search
  `@executable_path/../Frameworks`.
- Runtime artifacts must not contain references to Homebrew, `/private/tmp`,
  the repository, or a build workspace.
- macOS system frameworks and libraries under `/System/Library` and `/usr/lib`
  remain system dependencies and must not be copied into the app.

## 7. App Bundle

The local package layout is:

```text
CueSeeker.app/
  Contents/
    Info.plist
    MacOS/CueSeeker
    Frameworks/<media runtime dylibs>
    Helpers/ffmpeg
    Resources/ThirdPartyLicenses/<license notices>
```

The final bundle identifier is `com.cueseeker.app`. Application data remains
independent of this identifier: preferences use `com.cueseeker.shared`, and the
database remains under `Application Support/CueSeeker`. A future bundle
identifier change requires the release-rule review described in
`docs/engineering/07_release_rules.md`.

The packaging workflow must support ad-hoc signing for local validation. A
future distribution identity may be supplied without rebuilding the media
runtime. Nested dylibs are signed individually before the executable and the
outer app; `codesign --deep` must not be used as a substitute for ordered
signing.

## 8. Verification Gates

Before accepting a packaged runtime:

- Verify every Mach-O artifact is `arm64` only.
- Verify the minimum OS is macOS 13.0.
- Recursively inspect install IDs and dependencies.
- Reject forbidden absolute paths and unresolved non-system dependencies.
- Verify the app code signature after packaging.
- Verify that FFmpeg records `CONFIG_LIBDAV1D_DECODER=yes`, exposes the
  `libdav1d` decoder, and links `libavcodec` to the bundled `libdav1d` through
  `@rpath`.
- Build and test CueSeeker against the controlled runtime.
- Decode an AV1 sample through the same scaled RGB-frame and JPEG extraction
  commands used by automatic cover generation.
- Re-run the patched Matroska attachment/subtitle open-stall samples.
- Exercise representative H.264, HEVC, VP9, AV1, AAC, Opus, seek, and ASS
  subtitle rendering workflows when samples are available.
- Perform final acceptance on an Apple Silicon Mac without Homebrew, FFmpeg, or
  libass installed.

## 9. Licensing Artifacts

- The FFmpeg configuration must remain LGPL-compatible and must not enable GPL
  or nonfree components.
- The app must ship applicable third-party license notices.
- The exact FFmpeg source archive, CueSeeker patch, and build instructions used
  for a distributed binary must be retained so corresponding source can be
  provided.
- License compliance verification is required before a friend-distribution or
  formal-release artifact is published.
