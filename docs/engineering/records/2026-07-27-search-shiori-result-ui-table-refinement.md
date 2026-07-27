# Search and Shiori Result UI and Table Refinement

## Requirement

- `docs/human/requirements/20260727-Feature-Search Shiori Result UI And Table Refinement.md`
- `docs/human/design/UI.md`

## Scope

- Classify the change as macOS platform UI and UX work.
- Implement only Step 1 of the requirement: increase the horizontal breathing room around the Search and Shiori result surfaces.
- Preserve toolbar composition, table chrome, column layout, filtering behavior, selection behavior, and table interaction.

## Steps

1. Reused the existing shared Search and Shiori shell spacing source.
2. Increased the shared page horizontal padding from `12pt` to the existing
   `--spacing-6` token (`24pt`).
3. Kept toolbar, table, and popover horizontal bounds aligned to the same inset.
4. Replaced the initial `24pt` literal with
   `WorkbenchControlMetrics.redesignSpacing6` so the implementation references
   the existing UI token directly.

## Verification

- `swift build` passed.
- `swift build` passed again after replacing the literal with the existing
  `--spacing-6` token reference.
- The complete parallel `swift test` run executed 882 tests and reported 10
  timing or database-I/O failures unrelated to the spacing constant.
- The 10 failed tests all passed when rerun together with `--no-parallel`,
  confirming that the parallel-run failures were resource-contention flakes.
- No AI visual acceptance was performed; visual review is reserved for the
  human owner.

## Outcome

- Step 1 now uses a `24pt` horizontal inset for the shared Search and Shiori
  result shell through the existing `--spacing-6` token.
- Automated verification passed subject to the documented parallel-suite
  resource contention.
- Human visual acceptance remains pending.

## Follow-ups

- Continue to Step 2 only after Step 1 is explicitly accepted.
- Update the human-owned requirement and UI design only through the human-owner workflow after the iterative UI work is complete.
