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
2. Implementation and automated regression coverage are pending the next
   staged commits.

## Verification

- Confirmed the human-owned requirement is committed.
- Searched AI-maintained documentation for the superseded language-suffix rule
  and replaced the active matching and testing expectations.

## Outcome

Documentation alignment is complete. Production implementation and automated
verification remain in progress.

## Follow-ups

- Update `VideoMatcher` and its unit tests.
- Add indexing/database integration coverage for deterministic rematching.
