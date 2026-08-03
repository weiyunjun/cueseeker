# Unified Subtitle Encoding Decoding

## Requirement

- `docs/human/requirements/20260803-Bug-Unified Subtitle Encoding Decoding.md`
- `docs/human/design/Cue Parsing.md`
- `docs/human/design/Data.md`

## Scope

Unify ASS and SRT text decoding for indexing, playback, and subtitle screenshot
rendering without changing source files, database storage, or user settings.

## Steps

1. Added one decoder in `CueSeekerCore` with BOM-first Unicode decoding, strict
   UTF-8 handling, lossless Foundation charset detection for legacy unmarked
   files, and format-specific ASS or SRT structure validation.
2. Routed indexing and SRT rendering parsing through the shared decoder.
3. Routed direct ASS playback and screenshot fallbacks through decoded in-memory
   scripts so libass always receives UTF-8 text. Existing indexed ASS render
   segments remain unchanged.
4. Added coverage for Unicode BOM variants, CP932, Shift-JIS, EUC-JP,
   GB18030, GBK, Big5, malformed input, indexing/playback text parity, and
   libass memory rendering.

## Verification

- The focused parser, indexer, playback, screenshot, and libass regression set
  passed: 114 tests with no failures.
- The full 947-case Swift Testing run reported 25 failures in unrelated
  concurrent media, Library removal, keyboard-focus, menu, and UI refresh-scope
  tests. Every reported failing group was rerun in isolation; all 70 isolated
  tests passed.
- The supplied UTF-16LE ASS and matching video passed the playback sync probe.
  libass loaded the normalized in-memory script with 2 styles and 339 events;
  the probe reported no playback failures.
- The supplied file was read only. No source subtitle, database copy, cache, or
  manual encoding setting was created.

## Outcome

The same decoding policy now supplies subtitle text to indexing, playback, and
screenshot paths. Unsupported or structurally invalid data fails explicitly
instead of being passed to libass as an unknown byte encoding.

## Follow-ups

None.
