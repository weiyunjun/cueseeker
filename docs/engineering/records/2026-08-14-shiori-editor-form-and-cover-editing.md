# Shiori Editor Form and Cover Editing Implementation Record

## Requirement

- `docs/human/requirements/20260814-Bug-Shiori List Editor Form And Cover Editing.md`
- `docs/human/design/UI Design System.md`

## Scope

- Align the shared form validation slot, Text Area caret, and Text Area height.
- Reuse one cover chooser overlay across Shiori and Library editors.
- Open Library Edit Cover before selecting a replacement image.
- Prevent editor sheets from leaving the underlying workbench interactive.

## Steps

- Changed the shared Text Area height token from 96 to 80 points, retained the
  existing custom scrollbar behavior, and used the shared focus color for the
  insertion point.
- Kept one single-line validation slot mounted for every form field and reduced
  the four Shiori validation messages to the accepted copy.
- Added one shared, token-driven cover chooser with a full-cover mask and a
  centered Edit icon and `Choose Image` label. Shiori and Library use the same
  component, while crop mode remains directly interactive.
- Removed the standalone Shiori cover button, changed the Description label,
  and kept the cover and form at the same default 16:9 height.
- Changed Library cover editing to open with the current effective cover or the
  existing fallback. A newly selected source is an optional candidate, and Save
  remains disabled until that candidate exists.
- Disabled underlying workbench hit testing while either editor sheet is open
  and cleared Library and Shiori card hover state through the existing popup
  environment.
- Added focused coverage for the new copy, caret token, Text Area height,
  Library preview-first session state, source selection, and save eligibility.
- Recorded the user-visible outcome under `Unreleased` in the changelog.

## Verification

- `swift test --filter
  'libraryCoverEditing|libraryChangeCover|shioriListEditor|textArea'`: 7 tests
  passed.
- `swift test --no-parallel --skip
  'sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues|showCueGroupInvalidationIsScopedToMountedShiori|shioriTableStartsAtTopAfterPanelRemount'`:
  999 tests passed.
- The persistence migration exception passed when rerun directly. The two
  excluded Shiori table timing tests still fail at their established anchor and
  scroll waits, matching the pre-existing record in
  `docs/engineering/records/2026-08-13-debug-e2e-in-app-mouse-wheel-event-interaction.md`.
- `swift build -c release --product CueSeeker`: passed.
- Debug E2E `inspect` and `capture` passed and produced
  `CueSeeker-Debug-E2E-97120/shiori-editor-layout-precondition.png`. The scene
  was 1429 by 821 rather than the documented 1433 by 821 coordinate contract,
  so coordinate clicks were correctly not attempted.
- `git diff --check`: passed before the final review.

## Outcome

- The requested shared form and cover-editing behavior is implemented without a
  second image pipeline or editor-specific visual constants.
- Human E2E remains required for right-click entry, real pointer hover,
  centered overlay appearance, and final visual acceptance.

## Follow-ups

- Fold accepted visual values into the human-owned UI Design System after human
  E2E acceptance.
