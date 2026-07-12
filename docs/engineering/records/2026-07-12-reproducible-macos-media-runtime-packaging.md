# Reproducible macOS Media Runtime and App Packaging

Date: 2026-07-12

Human-owned document:

- `docs/human/requirements/20260712-Feature-Reproducible macOS Media Runtime And App Packaging.md`

## Scope

Establish the engineering baseline for an ARM64-only, reproducible FFmpeg and
libass runtime that can be embedded in a self-contained CueSeeker app bundle.

## Steps

1. Audited the current SwiftPM link roots and the built CueSeeker executable.
2. Confirmed that FFmpeg currently resolves from a temporary patched FFmpeg 8.1
   prefix while libass and its dependency closure resolve from Homebrew.
3. Audited the existing FFmpeg patch and all application call sites that enable
   the custom Matroska demuxer option.
4. Defined FFmpeg 8.1.2 plus the existing patch as the controlled baseline.
5. Defined an ARM64, macOS 13, shared-library, `@rpath` runtime shared by direct
   distribution and a future Mac App Store build.
6. Defined the initial controlled libass dependency direction and app-bundle
   layout.
7. Added a pinned source manifest for FFmpeg 8.1.2, libass 0.17.4, FreeType
   2.14.3, FriBidi 1.0.16, HarfBuzz 14.1.0, libunibreak 6.1, and the build-only
   pkgconf 2.5.1 tool.
8. Added a source build that bootstraps fixed Meson and Ninja versions, applies
   the CueSeeker FFmpeg patch, builds the full ARM64 shared-library runtime,
   rewrites install names to `@rpath`, and stages licenses and build metadata.
9. Added a fail-fast runtime verifier for required libraries, ARM64-only
   architecture, install IDs, dependency paths, and FFmpeg GPL/nonfree state.
10. Replaced the Swift package's independent FFmpeg header/library fallback and
    Homebrew libass paths with one complete controlled media runtime root.
11. Added development and app-bundle runtime search paths while keeping the
    linked library identities at `@rpath`.

## Verification

- `otool -L` confirmed that the current app is not self-contained and contains
  `/private/tmp` and `/opt/homebrew` runtime dependencies.
- The existing FFmpeg implementation record and patch were inspected to confirm
  why the custom demuxer option remains required.
- The official FFmpeg 8.1.2 source archive matched pinned SHA-256
  `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`.
- The existing CueSeeker patch applied cleanly to FFmpeg 8.1.2.
- `scripts/build_macos_media_runtime.sh` completed a clean source build of the
  controlled runtime.
- `scripts/verify_macos_media_runtime.sh` passed for the staged runtime and
  confirmed all shipped dylibs are ARM64 with only `@rpath`, system framework,
  and `/usr/lib` dependencies.
- FFmpeg reported `License: LGPL version 2.1 or later`; the staged configuration
  has GPL and nonfree disabled.
- libass was built through its distribution-recommended Autotools path with
  CoreText, ARM64 assembly, and the pinned FreeType, FriBidi, HarfBuzz, and
  libunibreak libraries.
- `swift build` passed against the controlled runtime.
- `swift test` passed all 7 XCTest tests and 548 Swift Testing tests against the
  controlled runtime.
- `otool -L` on the rebuilt CueSeeker executable reports the controlled FFmpeg
  8.1.2 and libass libraries through `@rpath`; it contains no Homebrew or
  `/private/tmp` media-library dependency.

## Outcome

The technical baseline is recorded in
`docs/engineering/09_macos_media_runtime_and_packaging.md`. The first
implementation stage now produces and verifies the controlled runtime.

## Follow-ups

- Implement and verify the pinned media runtime build.
- Move SwiftPM to the complete controlled runtime root.
- Package and verify the self-contained app bundle.
- Complete human end-to-end validation on a clean Apple Silicon Mac.
