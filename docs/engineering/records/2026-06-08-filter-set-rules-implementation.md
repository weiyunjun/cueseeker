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

- `swift test` passed from `apps/macos-native`.
- `swift build` passed from `apps/macos-native`.
- Focused coverage added:
  - `SubtitleSearchFilterSetTests` for operator availability, empty value skip,
    string matching, string-set matching, and set-level And/Or behavior.
  - `SubtitleDatabaseTests` for Display, Cues, Language, exact counts, indexed
    windows, and filter-specific cache key behavior.
  - `SchemaWorkbenchFilterRulesTests` for no preset Filter Sets and UI-to-core
    rule conversion.

## Outcome

Implemented the requested Filter Set behavior for the Test Search 2 flow:

- Filter Set rules are modeled in `CueSeekerCore`.
- Database search applies Filter Sets before producing result counts, cursors,
  file summaries, and result-ID index windows.
- Search page and result-ID index cache keys include the active Filter Set
  signature.
- App search, exact completion, table hydration, grouped load-more, and search
  navigation use the active Filter Set and reject stale async results when the
  Filter Set changes.
- The Filter Set UI starts without presets, saves sets only for the current
  page session, clears active/draft filters on Reset, hides the old `New Filter
  Set` title, propagates the second rule's join to later rules, renders later
  joins as static labels, excludes `#` from filtering, and scrolls the Test
  Search 2 table back to the top when the effective Filter Set changes.
- App restart persistence and rename behavior were intentionally not added.
