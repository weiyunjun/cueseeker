# Input Controls Visual Interaction Alignment

## Requirement

- `docs/human/requirements/20260811-Feature-Input Controls Visual Interaction Alignment.md`
- `docs/human/design/UI Design System.md`

## Classification

- macOS platform UI/UX only.
- Product validation, persistence, database behavior, and playback execution are
  unchanged.

## Cause

- Form and Search inputs drew a second expanded Focus Ring outside their
  focused border.
- The Text Area placeholder and `TextEditor` used independent SwiftUI padding
  while the underlying `NSTextView` retained its own content inset, so the
  placeholder, insertion point, and typed first line did not share one origin.
- The native Text Area scroller did not provide the documented project-wide
  custom scrollbar appearance and visibility contract.
- Auto Switch Gap used a native rounded Text Field with `ms` outside the
  control instead of the shared Input geometry.

## Implementation

- Removed the expanded Focus Ring from Text Field, Text Area, and Search Field
  focus chrome while retaining the accent border and Danger Border priority.
- Replaced the Text Area's split placeholder and `TextEditor` layout with one
  AppKit-backed text surface. Placeholder, caret, and text now use the same
  `16 × 10` content inset and zero line-fragment padding.
- Disabled native Text Area scrollers and overlaid the existing shared
  `TableScrollbarOverlayView` geometry. Overflow, scroll-area hover, scrolling,
  and dragging drive visibility without reserving a gutter; existing scrollbar
  size, minimum thumb length, radius, and colors remain authoritative.
- Added a focused Number Field presentation for Auto Switch Gap with the
  existing 40-point field height, 8-point radius, 16-point horizontal inset,
  trailing monospaced digits, and `ms` inside the same container. Existing
  numeric filtering, clamping, commit, and persistence logic is unchanged.

## Verification

- `swift test --filter textArea`: 4 focused tests passed for shared content
  origin, first-responder reporting, native-scroller removal, overflow, and
  hover visibility.
- `swift test --no-parallel --skip
  sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`:
  973 tests passed. The skipped test is the established pre-existing
  order-dependent persistence exception from the implementation baseline.
- `swift build -c release --product CueSeeker`: passed.
- `git diff --check`: passed before documentation was added and is repeated
  before commit.
- Real pre-change Debug E2E captures are under
  `CueSeeker-Debug-E2E-85960`, including Search Field and the New List form.
- Real final Debug E2E captures are under `CueSeeker-Debug-E2E-12749`:
  `input-search-field-focused.png`, `input-text-field-focused.png`,
  `input-text-area-focused.png`, and `input-number-field-focused.png`.
- The final focused screenshots show one accent border with no outer ring.
  The Text Area caret and placeholder share the same top-left origin with no
  native scrollbar gutter, and the Number Field keeps `1000` and `ms` inside
  one 40-point control.

## Outcome

- The four Input variants now share the accepted border-only focus direction.
- Text Area content alignment and scrollbar behavior no longer depend on
  unrelated SwiftUI and AppKit defaults.
- The implementation reuses the existing scrollbar primitive and does not
  change non-Input scrolling behavior or other component classes.

## Follow-up

- After human visual acceptance, the human owner can update
  `docs/human/design/UI Design System.md` with the stabilized Input rules.
