# Search and Shiori Result UI and Table Refinement

## Requirement

- `docs/human/requirements/20260727-Feature-Search Shiori Result UI And Table Refinement.md`
- `docs/human/design/UI.md`

## Scope

- Classify the change as macOS platform UI and UX work.
- Implement Steps 1 through 7 of the requirement: increase the horizontal
  breathing room, remove the Search and Shiori table outer frame, and replace
  persisted reusable Filter Sets with session-only filters and a count badge,
  then refine the result-table column order, text hierarchy, and normal-mode
  Hover treatment before adding the core Select-mode interaction.
- Preserve filtering execution, column width formulas, scrolling, and table
  interaction outside the requested Select-mode changes.

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
17. Kept the accepted `16px` / `10px` badge geometry and applied a tokenized
    `1px` downward optical offset to the whole badge without changing its
    internal number layout.
18. Removed the remaining legacy rule initializer from the Filter trigger so
    opening an empty Filter editor keeps zero rules; the first rule is created
    only through `New Filter`.
19. Swapped the Search and Shiori `Cues` and `Display Title` schema positions
    while retaining each column's existing weight and minimum-width formula.
20. Kept Primary Cue on `--color-text-secondary` and moved Display Title, Time
    Range, Date Added, Extra Cues, and table Tag text to
    `--color-text-muted`.
21. Changed enabled table-header text to `--color-text-secondary` in both the
    rendered SwiftUI headers and their attributed text-selection representation.
22. Preserved the shared table's legacy fallback column order because Search
    and Shiori already pass their explicit schema order; this avoids changing
    unrelated callers.
23. Moved redesign Hover background rendering from the Cues content region to
    the complete row, using the existing `--color-row-hover` token.
24. Preserved the Cues Hover text emphasis and underline while leaving Cue,
    Tag, text-selection, and context-menu hit regions unchanged.
25. Added a shared Select trigger using the existing Edit icon mapping and
    toolbar-control styling; it changes to `Exit Select` while active.
26. Gated Select entry on a complete result identity set: Search
    reuses its existing exact text-copy boundary, while Shiori verifies its
    complete result-ID snapshot.
27. Reused the existing row-selection state and fixed selection-column width,
    hiding Header and Row Checkboxes in normal mode without changing table
    geometry.
28. Made every loaded row area toggle selection in Select mode and disabled
    Search editing, Filter, View, Header actions, Cue playback, Tag actions,
    context menus, and internal or external text selection until exit.
29. Applied the existing `--color-row-selected` token to selected rows, kept
    unselected Row Hover on `--color-row-hover`, and gave Selected priority so
    Hover does not stack another background.
30. Cleared transient selection when exiting Select mode, when its exact-result
    boundary becomes unavailable, or when the owning table leaves its active
    presentation.
31. Corrected the Search Select-entry boundary to require the existing search
    lifecycle to be completed as well as exact, preventing the reset-time empty
    exact metadata from briefly enabling Select while a new search is running.

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
- `swift build` and the focused Filter Rule and Filter Count Badge tests passed
  after the whole-badge alignment and empty-trigger correction.
- The complete parallel `swift test` run executed 882 tests and reported 10
  timing or database-I/O failures unrelated to the spacing constant.
- The 10 failed tests all passed when rerun together with `--no-parallel`,
  confirming that the parallel-run failures were resource-contention flakes.
- `swift build` passed after the Step 5 column and text hierarchy changes.
- Twenty-one focused schema, column-layout, typography, header, and Tag tests
  passed with `--no-parallel`.
- The initial broader SubtitleTable run exposed an out-of-scope fallback-order
  change; after preserving that fallback, the final rerun passed all 167
  SubtitleTable tests with `--no-parallel`.
- `swift build` passed after the Step 6 Hover change.
- The focused full-row Hover test passed, and the complete SubtitleTable test
  group passed all 168 tests with `--no-parallel` after the Step 6 change.
- `swift build` passed after the Step 7 Select-mode change.
- The complete SubtitleTable-focused group passed all 170 tests with
  `--no-parallel`, including exact-entry gating, reserved selection-column
  geometry, full-row selection, disabled text selection, and Selected/Hover
  priority coverage.
- The first complete `--no-parallel` run executed 884 tests and exposed five
  legacy Cue Group integration cases that invoked Checkbox selection without
  entering Select mode, plus the previously documented shared-preferences
  retained-state failure.
- The Cue Group integration tests were aligned with the new Select-mode
  boundary and all 14 passed on rerun; the shared-preferences test also passed
  alone.
- The final complete `--no-parallel` rerun executed 884 tests with only that
  same retained shared-preferences-state failure; all Step 7 and Cue Group
  integration coverage passed.
- The focused Search text-copy boundary regression test passed, including the
  new searching-with-empty-exact-metadata case.
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
- Step 4 received human visual acceptance when the human owner advanced to the
  next step.
- Step 5 received human visual acceptance when the human owner started Step 6.
- Step 6 received human visual acceptance when the human owner advanced to
  Step 7.
- Step 7 automated verification passed; human visual acceptance remains
  pending.
- The Search Select-button transient-enable regression was fixed within Step 7;
  human verification remains pending.

## Follow-ups

- Continue to Step 8 only after Step 7 is explicitly accepted.
- Update the human-owned requirement and UI design only through the human-owner workflow after the iterative UI work is complete.
