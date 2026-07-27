# Search and Shiori Result UI and Table Refinement

## Requirement

- `docs/human/requirements/20260727-Feature-Search Shiori Result UI And Table Refinement.md`
- `docs/human/design/UI.md`

## Scope

- Classify the change as macOS platform UI and UX work.
- Implement Steps 1 and 2 of the requirement: increase the horizontal breathing
  room and remove the Search and Shiori table outer frame.
- Preserve toolbar composition, column layout, filtering behavior, selection
  behavior, and table interaction.

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
- Step 2 automated verification passed; human visual acceptance remains
  pending.

## Follow-ups

- Continue to Step 3 only after Step 2 is explicitly accepted.
- Update the human-owned requirement and UI design only through the human-owner workflow after the iterative UI work is complete.
