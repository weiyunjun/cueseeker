# Playback Overlay Unicode Path Identity

## Requirement

- `docs/human/requirements/20260804-Bug-Playback Overlay Unicode Path Identity.md`
- `docs/human/design/Data.md`
- `docs/human/design/Cue Parsing.md`

## Classification

- Product semantics: Playback Overlay resolves indexed subtitle cues by the
  permanent `SubtitleID` defined by the data model.
- Platform UI/UX and playback execution: unchanged.

## Scope

- Added `SubtitleID` to the existing Library, Search, Shiori, and Playback
  Overlay source projections.
- Changed the Overlay initial-window and complete-batch database reads to bind
  `subtitle_files.id` instead of comparing the subtitle path.
- Kept paths as filesystem locations for video and subtitle playback; no path
  normalization policy, matching rule, cue parsing rule, schema, or stored ID
  changed.
- Added regression coverage for canonically equivalent Japanese dakuten,
  Latin accent, and Hangul NFC/NFD paths, plus projection and Overlay loader
  coverage.

## Verification

- `swift test --filter SubtitleFocusTests`: 10 tests passed, including all
  three Unicode normalization fixtures.
- Focused Library, Search, Shiori, Overlay entry, and Subtitle Focus–Shiori
  rerun: 10 tests passed.
- `swift test`: ran 953 tests and reported 25 issues in unrelated concurrent
  native media timing, Library removal, UI refresh-probe, row-menu, and
  Subtitle Focus–Shiori tests during disk I/O contention. All three affected
  Subtitle Focus–Shiori tests passed in the focused rerun.
- `git diff --check`: passed.

## Outcome

Playback Overlay cue loading no longer depends on byte-for-byte equality
between filesystem paths and SQLite text. Canonically equivalent Unicode path
forms therefore resolve the same indexed subtitle through its permanent ID,
without language-specific handling or data migration.
