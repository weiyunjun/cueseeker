# Restore AV1 Automatic Cover Decoding

Date: 2026-07-27

## Requirement

- `docs/human/requirements/20260727-Bug-Restore AV1 Automatic Cover Decoding.md`

## Scope

This record tracks the accepted two-stage recovery. Phase 1 is limited to the
platform UI/UX fallback for unavailable automatic covers. It does not change
FFmpeg, media-runtime dependencies, indexing, cover persistence, or AV1 decode
behavior.

## Steps

1. Confirmed that failed generated covers are excluded from presentation cover
   paths, so the shared Library cover view receives no usable image key.
2. Replaced the shared flat placeholder with the existing Library Cover
   Placeholder background and a centered muted `film` symbol.
3. Preserved the existing Cue-count badge, playback progress, duration, and
   manual cover replacement behavior by changing only the cover image layer.
4. Synchronized the stable fallback behavior in the product UI document.

## Verification

- `swift test --package-path apps/macos-native --filter LibraryCover` rebuilt
  the changed application target and passed all 25 selected cover tests.
- The complete `swift test --package-path apps/macos-native` run executed 873
  tests but reported 14 issues across nine playback timing, Shiori timing,
  folder-removal, menu timing, and refresh-scope tests while the suite was
  under broad concurrent load. This run is not recorded as passing.
- Each of the nine failed tests was rerun individually with both `--skip-build`
  and `--no-parallel`; all nine passed without code or test changes. The
  isolated reruns found no failure coupled to the shared fallback cover view.
- Human visual acceptance of the fallback remains outstanding and is the gate
  before Phase 2 begins.

## Outcome

Phase 1 is compiled, targeted-cover verified, and ready for human visual
acceptance. AV1 software decoding remains unchanged and is deferred until the
human owner accepts the fallback behavior.

## Follow-ups

- Stop after the Phase 1 commit for human visual acceptance.
- After acceptance, add the controlled AV1 software decoder and verify automatic
  cover extraction in a separate implementation step and commit.
