# Restore AV1 Automatic Cover Decoding

Date: 2026-07-27

## Requirement

- `docs/human/requirements/20260727-Bug-Restore AV1 Automatic Cover Decoding.md`
- `docs/human/design/Data.md`

## Scope

This record tracks the accepted two-stage AV1 recovery and the subsequent
automatic-cover indexing correction. Phase 1 provides the platform UI/UX
fallback for unavailable automatic covers. Phase 2 restores software AV1 cover
decoding in the controlled macOS media runtime. The indexing correction applies
the stabilized fallback, automatic, and user-cover replacement rules.

## Steps

1. Confirmed that failed generated covers are excluded from presentation cover
   paths, so the shared Library cover view receives no usable image key.
2. Replaced the shared flat placeholder with the existing Library Cover
   Placeholder background and a centered muted `film` symbol.
3. Preserved the existing Cue-count badge, playback progress, duration, and
   manual cover replacement behavior by changing only the cover image layer.
4. Synchronized the stable fallback behavior in the product UI document.
5. Recorded dav1d 1.5.4, its official source URL, SHA-256, source directory,
   and BSD-2-Clause license in the pinned media-runtime inputs.
6. Built dav1d as a shared decoder library without its tools, examples, tests,
   documentation, or optional muxer, then enabled FFmpeg's `libdav1d` decoder.
   No AV1 encoder was added.
7. Added runtime completeness, FFmpeg configuration, decoder registration,
   `@rpath` linkage, app-bundle presence, and packaged-decoder checks.
8. Added `libdav1d` to the Swift package media-runtime completeness gate and
   staged its license notice with the packaged application.
9. Made every explicit Library Index inspect its complete eligible video scope,
   so a prior fallback state retries automatic generation even when subtitle and
   video indexing data is unchanged.
10. Added the existing user-cover row to automatic-cover eligibility data and
    excluded those videos from both automatic generation and automatic display
    rendition backfill.
11. Kept fresh unchanged automatic covers, regenerated affected or stale
    automatic covers, and preserved the prior automatic master, display
    rendition, database row, and folder reference when regeneration failed.
12. Staged a newly generated master JPEG and its display rendition before
    publishing either database path, so a decode or rendition-generation
    failure cannot replace a prior automatic cover with fallback.

## Verification

- The full media-runtime build completed with dav1d 1.5.4, and
  `verify_macos_media_runtime.sh` passed the ARM64, dependency, FFmpeg
  configuration, registered-decoder, and direct `libavcodec` linkage gates.
- An AV1 Matroska sample decoded as `av1 (libdav1d)`. The automatic-cover
  scoring command produced the exact expected 320 x 180 RGB24 payload of
  172,800 bytes, and the full cover command produced a valid 320 x 180 JPEG.
- `swift test --package-path apps/macos-native --filter LibraryCover` rebuilt
  against the updated runtime and passed all 25 selected cover tests.
- `package_macos_app.sh` produced, signed, and verified a self-contained ARM64
  application. Its packaged FFmpeg exposed `libdav1d`, linked only to the
  bundled dylib through `@rpath`, and produced the same 172,800-byte AV1 cover
  scoring frame.
- The complete `swift test --package-path apps/macos-native` run executed 873
  tests but reported 11 issues across seven existing playback timing, Shiori
  timing, folder-removal, menu timing, and refresh-scope tests under broad
  concurrent load. This run is not recorded as passing.
- The seven failed tests were selected together and rerun with `--skip-build`
  and `--no-parallel`; all seven passed without code or test changes. The
  isolated rerun found no failure coupled to the media-runtime dependency.
- `swift test --package-path apps/macos-native --filter LibraryCover` passed all
  29 selected tests after the indexing correction. The added regressions cover
  unchanged fallback retry, user-cover preservation, failed automatic refresh
  rollback, folder-reference preservation, and unchanged automatic-cover
  freshness.
- `swift test --package-path apps/macos-native --filter LibraryDatabase` passed
  all 18 selected persistence and presentation tests.
- `swift test --package-path apps/macos-native --filter LibraryFolderRemoval`
  passed all eight selected App indexing and folder-lifecycle tests, including
  the unchanged-folder Index flow.

## Outcome

Both accepted AV1 phases and the cover-state indexing correction are
implemented. Unavailable covers retain the accepted fallback presentation and
retry on later Index operations, user covers remain untouched, and a failed
refresh cannot erase an existing automatic cover. The reproducible and packaged
macOS runtime uses its bundled `libdav1d` decoder for AV1 automatic-cover
extraction when software decoding is required.

## Follow-ups

- Perform the final human application test with the generated package before a
  formal release or installation replaces an existing application.
