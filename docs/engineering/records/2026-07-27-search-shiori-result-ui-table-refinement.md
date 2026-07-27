# Search and Shiori Result UI and Table Refinement

## Requirement

- `docs/human/requirements/20260727-Feature-Search Shiori Result UI And Table Refinement.md`
- `docs/human/design/UI.md`

## Scope

- Classify the change as macOS platform UI and UX work.
- Implement Steps 1 through 4 of the requirement: increase the horizontal
  breathing room, remove the Search and Shiori table outer frame, and replace
  persisted reusable Filter Sets with session-only filters and a count badge.
- Preserve column layout, filtering execution, selection behavior, and table
  interaction outside the requested filter-control changes.

## Steps

1. Reused the existing shared Search and Shiori shell spacing source.
2. Increased the shared page horizontal padding from `12pt` to the existing
   `--spacing-6` token (`24pt`).
3. Kept toolbar, table, and popover horizontal bounds aligned to the same inset.
4. Replaced the initial `24pt` literal with
   `WorkbenchControlMetrics.redesignSpacing6` so the implementation references
   the existing UI token directly.
5. Added the missing Swift mapping for the existing `--spacing-8` token and
   changed the Step 1 review candidate from `--spacing-6` (`24pt`) to
   `--spacing-8` (`32pt`) at the human owner's request.
6. Removed the redesign table container border and corner clipping while
   preserving its existing surface background token and the legacy table
   appearance.
7. Kept the Header and Row Divider paths at the full table width and changed
   their redesign color from the control-border token to the existing
   `--color-border-divider` token.
8. Replaced the Filter Sets and New Filter Set controls with one Filter trigger
   that reuses the existing toolbar control and opens the existing filter
   editor directly.
9. Removed the Filter Set model, picker, save action, Save Filter Set button,
   active Filter Set identifiers, and UserDefaults persistence.
10. Kept Search and Shiori filter rules in their existing separate in-memory
    stores so they survive view remounts within the current app session but are
    empty in new store instances.
11. Removed the two obsolete filter-status controls after their final call
    sites were removed.
12. Added Filter Count Badge geometry tokens and semantic color aliases.
13. Extended the shared toolbar button with an optional numeric badge and used
    it only for the Filter trigger.
14. Passed the current Filter Rule count into the trigger, hiding the badge at
    zero while allowing its tokenized minimum circle to expand for multi-digit
    counts.
15. Refined the Step 4 review candidate to a `16px` badge with a dedicated
    `10px` font-size token, `4px` horizontal padding, and the existing muted
    color palette in Light and Dark modes.
16. Corrected the Filter editor's final-rule deletion path: the previous code
    immediately inserted a replacement rule whenever deletion made the array
    empty; the editor now preserves the valid empty-filter state.

## Verification

- `swift build` passed.
- `swift build` passed again after replacing the literal with the existing
  `--spacing-6` token reference.
- `swift build` passed after changing the review candidate to the newly mapped
  existing `--spacing-8` token.
- `swift build` passed after removing the table frame and correcting the
  divider token.
- Focused subtitle-table tests passed with `--no-parallel` after the Step 2
  change.
- `swift build` passed after the Step 3 filter simplification.
- Focused filter and Shiori remount tests passed with `--no-parallel`, including
  the new Search/Shiori session-state isolation coverage.
- The complete `--no-parallel` suite ran 880 tests and reported one unrelated
  shared-preferences migration failure consistent with retained test state;
  that test passed immediately when rerun alone.
- `swift build` passed after the Step 4 badge change.
- Ten focused workbench and Filter Count Badge token tests passed with
  `--no-parallel`.
- `swift build` passed after the Step 4 review refinements and final-rule
  deletion correction.
- Seven focused Filter Rule and Filter Count Badge tests passed with
  `--no-parallel` after the refinements.
- The complete parallel `swift test` run executed 882 tests and reported 10
  timing or database-I/O failures unrelated to the spacing constant.
- The 10 failed tests all passed when rerun together with `--no-parallel`,
  confirming that the parallel-run failures were resource-contention flakes.
- No AI visual acceptance was performed; visual review is reserved for the
  human owner.

## Outcome

- Step 1 now uses a `32pt` horizontal inset for the shared Search and Shiori
  result shell through the existing `--spacing-8` token.
- Automated verification passed subject to the documented parallel-suite
  resource contention.
- Step 1 received human visual acceptance.
- Step 2 received human visual acceptance.
- Step 3 received human visual acceptance.
- Step 4 automated verification passed; human visual acceptance remains
  pending.

## Follow-ups

- Continue to Step 5 only after Step 4 is explicitly accepted.
- Update the human-owned requirement and UI design only through the human-owner workflow after the iterative UI work is complete.
