# Workbench Search And Shiori Table Scroll Restoration

## Requirement

- `docs/human/requirements/20260731-Bug-Workbench Search And Shiori Table Scroll Position Restoration.md`

## Scope

Reset the Workbench Search and Shiori table viewport when their surfaces are
left, and reset the Shiori viewport when the active list changes. Resident
results, filters, and table controls remain unchanged.

## Steps

1. Added a mounted-table regression that scrolls Search away from the first row,
   switches to Shiori, returns to Search, and checks the native vertical offset.
   The regression failed before the fix.
2. Cleared the saved Search and Shiori viewport anchors when their table
   surfaces disappear.
3. Reset the Shiori scroll target when the active Shiori list changes so a
   different secondary list cannot inherit the previous list position.
4. Added the same mounted-table return-to-top coverage for Shiori.

## Verification

- Pre-fix Search mounted-table regression: failed as expected because the
  remounted table restored the old viewport.
- `swift test --filter PanelRemount`: passed, 2 tests.
- `swift test --filter CueGroupRefreshScopeIntegrationTests`: passed, 15 tests.
- `swift test`: ran 919 tests. The new Search and Shiori regressions passed.
  The parallel full run reported 23 issues in existing Library folder-removal,
  native playback timing, Playback Subtitle Focus timing, and one refresh-scope
  invalidation check. The complete refresh-scope suite passed in its isolated
  15-test run.
- `git diff --check`: passed.

## Outcome

Workbench Search and Shiori secondary tables now start at the first row after
leaving and returning. Switching the active Shiori list also resets the table to
the first row.

## Follow-ups

None.
