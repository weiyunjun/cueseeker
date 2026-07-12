# Subtitle Video Basename Matching Priority

Date: 2026-07-12

## Requirement

- `docs/human/requirements/20260712-Bug-Subtitle Video Basename Matching Priority.md`

## Scope

Replace the previous language-suffix heuristic with the accepted deterministic
basename rule: prefer the complete subtitle basename, fall back once by
removing its final dot-separated suffix, and persist at most one matched video
per subtitle.

## Steps

1. Aligned product, playback, testing, shared-core planning, and changelog
   documentation with the accepted rule.
2. Replaced the language-suffix regular expression in `VideoMatcher` with a
   deterministic final-dot split that yields the complete basename first and
   at most one fallback.
3. Added unit coverage for generic suffix fallback, complete-basename priority
   across video extensions, unsuffixed subtitle isolation, and one-level-only
   fallback generation.
4. Added indexing integration coverage proving a generic non-language suffix
   selects the complete-basename video when both candidates exist, persists one
   active association, and rematches an unchanged subtitle when a new
   higher-priority video appears.
5. Ran the complete native package test suite and debug build without touching
   the user's production database or media files.

## Verification

- Confirmed the human-owned requirement is committed.
- Searched AI-maintained documentation for the superseded language-suffix rule
  and replaced the active matching and testing expectations.
- `swift test --package-path apps/macos-native --filter VideoMatcher` passed all
  six selected Swift Testing tests.
- The first `swift test --package-path apps/macos-native --filter BasenameMatch`
  run selected the correct videos but exposed `/var` versus `/private/var`
  aliases in the temporary-fixture assertions. The assertions were corrected
  to compare symlink-resolved file URLs.
- The repeated basename-matching integration filter passed both tests, covering
  complete-basename priority, one persisted active association, fallback, and
  deterministic rematching of an otherwise unchanged subtitle.
- `swift test --package-path apps/macos-native` passed all 7 XCTest tests and
  566 Swift Testing tests.
- `swift build --package-path apps/macos-native` completed successfully.

## Outcome

The implementation matches the accepted rule without a database schema change:
each subtitle produces the complete basename candidate first, optionally one
generic fallback candidate, and persists only the first existing video. Focused
and full automated verification passed. Real-library end-to-end acceptance is
left to the human owner as requested.

## Follow-ups

- Reindex the selected real media folders and verify the expected Library video
  set during human end-to-end acceptance.
