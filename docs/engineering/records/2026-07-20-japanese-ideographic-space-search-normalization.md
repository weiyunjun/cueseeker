# Japanese Ideographic Space Search Normalization

## Human-Owned Requirement

- `docs/human/requirements/20260719-Bug-Japanese Ideographic Space Search Normalization.md`

## Classification

- Product semantics: default subtitle search treats ASCII space `U+0020` and
  ideographic space `U+3000` as equivalent.
- Platform UI/UX, platform integration, and playback execution are unchanged.

## Root Cause

SQLite FTS already treated both characters as token separators and returned the
same candidate cue groups. The subsequent CJK line-level validation used a raw
substring comparison, so a candidate was discarded when the query and subtitle
line used different space widths.

## Implementation

1. Normalize only `U+3000` to `U+0020` when building the search query plan.
2. Apply the same targeted normalization before line-level matching so every
   default search entry point shares the same behavior.
3. Preserve stored and displayed subtitle text without Unicode compatibility
   normalization, schema changes, or an FTS index rebuild.
4. Add a regression test covering both query directions while confirming that
   returned content retains its original space character.

## Verification

- The focused regression test failed in both directions before the core change.
- `swift test --filter searchTreatsASCIIAndIdeographicSpacesAsEquivalent`
  passed after the implementation.
- `swift test --filter CueSeekerCoreTests` passed all 207 core tests.
- No runtime UI verification was required because every search surface routes
  through the tested `CueSeekerCore` query path.

## Outcome

Default subtitle search now returns the same results whether the query or
subtitle content uses `U+0020` or `U+3000`. The change is limited to those two
space characters and does not broaden search normalization to other Unicode
compatibility characters.
