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
- Reused the Neutral Button's surface, Hover background, icon, focus ring, and
  disabled colors.
- Kept the enabled label and border on the existing Danger text token.
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
- The Debug E2E App launched successfully, but its `1433 x 821` scene did not
  match the reusable Shiori procedure's required `1443 x 821` precondition.
  Testing stopped before coordinate input or capture, as required by the E2E
  rules.
- `git diff --check`: passed before documentation updates and is repeated
  before commit.

## Outcome

- Enabled Destructive Buttons now differ from Neutral Buttons only through the
  Danger-colored label and border.
- Disabled appearance remains identical to Neutral, and Light/Dark behavior
  continues to come from the existing dynamic design tokens.

## Follow-ups

- A valid documented E2E scene is still required for final Light/Dark visual
  acceptance of Default, Hover, and Focused states.
