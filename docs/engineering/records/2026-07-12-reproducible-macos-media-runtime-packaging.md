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
12. Added LAME 3.100 as a pinned LGPL shared dependency and enabled FFmpeg's
    `libmp3lame` encoder so packaged Anki audio export remains self-contained.
13. Included the FFmpeg 8.1.2 CLI from the same controlled build for existing
    thumbnail, screenshot, Library cover, and Anki subprocess workflows.
14. Changed generated thumbnail cache files from AVIF through external
    `libsvtav1` to built-in FFmpeg MJPEG output so thumbnail generation does not
    require an unbundled encoder.
15. Updated all FFmpeg subprocess resolution paths to prefer the app's embedded
    `Contents/Helpers/ffmpeg` executable while preserving development fallbacks.
16. Added the standard app `Info.plist`, self-contained bundle assembly,
    ordered local signing, and recursive app verification scripts.
17. Assigned Debug and packaged launches the same explicit
    `com.cueseeker.macos-native` UserDefaults suite while preserving injectable
    isolated defaults for tests. This makes Library folders, Recent visibility,
    settings, and interface state share the same persistence identity as the
    already-shared application database.
18. Added a one-time, non-overwriting migration from the legacy `CueSeeker`
    Debug preferences domain so existing Library folders and application state
    appear immediately in both launch forms.

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
- The final runtime build includes FFmpeg 8.1.2, libavfilter, the FFmpeg helper,
  LAME 3.100, libass 0.17.4, and the complete pinned text-rendering dependency
  closure. Runtime verification passed.
- The embedded FFmpeg helper reports FFmpeg 8.1.2 and exposes both `mjpeg` and
  `libmp3lame` encoders.
- `scripts/package_macos_app.sh` produced an ad-hoc-signed
  `.build/distribution/CueSeeker.app`.
- `scripts/verify_macos_app_bundle.sh` confirmed the main executable, FFmpeg
  helper, and every dylib are ARM64-only; all non-system dependencies resolve
  within `Contents/Frameworks`; development runtime rpaths are absent; and the
  complete app signature is valid.
- The final `swift test` run passed all 7 XCTest tests and 548 Swift Testing
  tests after the embedded-helper and JPEG thumbnail changes.
- Launch Services successfully opened the packaged app, and `pgrep` confirmed
  the running process came from
  `CueSeeker.app/Contents/MacOS/CueSeeker`.
- Application metadata tests verify the stable shared persistence identifier;
  migration tests verify legacy values are copied once without replacing values
  already written by the packaged app.
- The complete `swift test` run passed all 7 XCTest tests and 550 Swift Testing
  tests after the final shared-persistence migration change.
- The final packaging run rebuilt and verified the self-contained, ad-hoc-signed
  ARM64 `CueSeeker.app` after the persistence changes.

## Outcome

The technical baseline is recorded in
`docs/engineering/09_macos_media_runtime_and_packaging.md`. The first
implementation now produces the controlled runtime and a locally signed,
self-contained ARM64 app for human end-to-end acceptance.

## Follow-ups

- Complete human end-to-end validation on a clean Apple Silicon Mac.
- Add Developer ID signing and notarization only when friend distribution is
  requested; the media runtime does not need to be rebuilt for that step.
