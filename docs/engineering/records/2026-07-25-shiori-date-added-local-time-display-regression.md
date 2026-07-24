# Shiori Date Added Local Time Display Regression

## Requirement

- `docs/human/requirements/20260725-Bug-Shiori Date Added Local Time Display Regression.md`

## Scope

Restore local-time presentation for Shiori Date Added values without changing
the stored UTC timestamp or Move/Duplicate behavior.

## Classification

- Platform UI/UX: convert the stored timestamp only when producing Date Added
  display text.
- Product semantics: unchanged.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Steps

1. Replaced direct UTC string slicing with ISO 8601 parsing followed by
   `yy-MM-dd HH:mm` formatting in the system's current time zone.
2. Preserved the existing behavior of returning an unparseable stored value
   unchanged.
3. Added a deterministic regression test using the Asia/Shanghai time zone to
   cover the UTC-to-local conversion and date rollover.
4. Updated the changelog for the user-visible correction.

## Verification

- `swift test --filter tableSandboxShioriDateAddedDisplayConvertsUTCToLocalTime`
  passed with 1 test.
- `swift test --filter tableSandboxRowModelStore` passed with 31 tests.
- `swift build` passed.
- Static scope inspection confirmed that no database persistence or
  Move/Duplicate path was modified.

## Outcome

The targeted regression now passes: `2026-07-23T18:20:49Z` displays as
`26-07-24 02:20` in Asia/Shanghai while persistence semantics remain unchanged.
