# Destructive Button Neutral Styling

## Requirement

- `docs/human/requirements/20260819-Feature-Destructive Button Neutral Styling.md`
- `docs/human/design/UI Design System.md`

## Classification

- macOS platform UI/UX only.
- Product semantics, persistence, platform integration, and playback execution
  are unchanged.

## Scope

- Align the shared `WorkbenchDestructiveButton` with the accepted Destructive
  variant without changing other button variants or call sites.

## Steps

- Added the same pointer Hover state used by the Neutral Button.
- Reused the Neutral Button's surface, icon, focus ring, and disabled colors.
- Kept the enabled label and border on the existing Danger text token, and used
  the existing Danger Hover background token for the enabled Hover state.
- Added no new token, abstraction, state source, or dependency.

## Verification

- `swift test --filter WorkbenchControlMetrics`: passed 3 tests and compiled
  the affected app and test targets.
- `swift build -c release --product CueSeeker`: passed.
- The full suite command `swift test --no-parallel --skip
  sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
  ran 1,004 tests: 1,002 passed and 2 failed in unrelated Shiori table
  scrolling and anchor waits. An isolated rerun reproduced both failures;
  neither test exercises the Destructive Button.
- The Debug in-app E2E controller launched successfully with one main window.
  Its current actions cannot generate Pointer Hover, so no Hover capture was
  produced and no additional automation capability was added.
- `git diff --check`: passed before documentation updates and is repeated
  before commit.

## Outcome

- Enabled Destructive Buttons use the Neutral surface by default, Danger-colored
  label and border, and the Danger Hover background while hovered.
- Disabled appearance remains identical to Neutral, and Light/Dark behavior
  continues to come from the existing dynamic design tokens.

## Follow-ups

- Final Light/Dark Pointer Hover acceptance remains manual unless a separate
  requirement authorizes adding Pointer Move to the Debug E2E controller.
