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
5. Update the Filter Set UI for saved Filter Sets, no default presets, Reset
   semantics, join propagation, static joins after the second rule, and
   type-specific input handling.
6. Verify with focused tests and a Swift build/test pass.

Acceptance follow-up:

- Filter string and string-set conditions match case-insensitively, matching the
  search experience.
- Saving while an existing saved Filter Set is active updates that saved Filter
  Set instead of creating a duplicate.
- Saved Filter Set definitions persist across app restarts, while the active
  Filter Set selection and applied rules do not restart as active state.

## Verification

- `swift test` passed from `apps/macos-native`.
- `swift build` passed from `apps/macos-native`.
- Focused coverage added:
  - `SubtitleSearchFilterSetTests` for operator availability, empty value skip,
    case-insensitive string matching, case-insensitive string-set matching,
    case-normalized cache signatures, and set-level And/Or behavior.
  - `SubtitleDatabaseTests` for Display, Cues, Language, exact counts, indexed
    windows, and filter-specific cache key behavior.
  - `SchemaWorkbenchFilterRulesTests` for no preset Filter Sets and UI-to-core
    rule conversion.
  - `SchemaWorkbenchFilterRulesTests` for updating the active saved Filter Set
    and SettingsStore persistence without default active filter restoration.

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
- The Filter Set UI starts without presets, persists saved Filter Set
  definitions, updates the active saved Filter Set on Save, clears active/draft
  filters on Reset, hides the old `New Filter Set` title, propagates the second
  rule's join to later rules, renders later joins as static labels, excludes `#`
  from filtering, and scrolls the Test Search 2 table back to the top when the
  effective Filter Set changes.
- App restart restores saved Filter Set definitions only; it does not restore an
  active selection or auto-apply the previous active Filter Set. Rename behavior
  was intentionally not added.
