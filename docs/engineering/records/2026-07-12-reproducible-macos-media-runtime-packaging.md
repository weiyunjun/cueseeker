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

## Verification

- `otool -L` confirmed that the current app is not self-contained and contains
  `/private/tmp` and `/opt/homebrew` runtime dependencies.
- The existing FFmpeg implementation record and patch were inspected to confirm
  why the custom demuxer option remains required.
- No application source or build behavior changed in this documentation step.

## Outcome

The technical baseline is recorded in
`docs/engineering/09_macos_media_runtime_and_packaging.md`. Implementation will
proceed in independently verifiable build-runtime, SwiftPM-linking, and app
packaging stages.

## Follow-ups

- Implement and verify the pinned media runtime build.
- Move SwiftPM to the complete controlled runtime root.
- Package and verify the self-contained app bundle.
- Complete human end-to-end validation on a clean Apple Silicon Mac.
