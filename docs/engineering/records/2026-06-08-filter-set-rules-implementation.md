# Filter Set Rules Implementation

Date: 2026-06-08

Human requirement:

- `docs/human/requirements/20260608-Feature-Filter Set Rules.md`

## Scope

Implement database-level Filter Set rules for the Test Search 2 table flow.

Planned implementation steps:

1. Add a core Filter Set model and pure evaluator for Display, Cues, and
   Language rules.
2. Apply the Filter Set in `SubtitleDatabase` search result construction so
   result count, cursor windows, ID indexes, and file summaries all reflect the
   filtered result set.
3. Include the Filter Set signature in search page and result-ID index cache
   keys.
4. Thread the active Filter Set through App search, exact completion, table
   hydration, and search navigation.
5. Update the Filter Set UI for session-only saved sets, no default presets,
   Reset semantics, join propagation, static joins after the second rule, and
   type-specific input handling.
6. Verify with focused tests and a Swift build/test pass.

## Verification

Pending implementation.

## Outcome

Pending implementation.
