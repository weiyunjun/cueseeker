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

## Verification

- Confirmed the human-owned requirement is committed.
- Searched AI-maintained documentation for the superseded language-suffix rule
  and replaced the active matching and testing expectations.
- `swift test --package-path apps/macos-native --filter VideoMatcher` passed all
  six selected Swift Testing tests.

## Outcome

Documentation alignment, the production matcher change, and focused unit
verification are complete. Indexing integration verification remains in
progress.

## Follow-ups

- Add indexing/database integration coverage for deterministic rematching.
