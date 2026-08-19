# Library And Shiori Overview Primary Actions

## Requirement

- `docs/human/requirements/20260819-UI-Library And Shiori Overview Primary Actions.md`
- `docs/human/design/UI Design System.md`

## Classification

- macOS platform UI/UX only.
- Product semantics, persistence, platform integration, and playback execution
  are unchanged.

## Implementation

- Replaced the shared Library Overview action's Plain Button with the existing
  Primary Button.
- Preserved the two call sites' labels, plus icons, layout, actions, and states.
- Added no component, token, state source, dependency, or execution path.
- Recorded the user-visible style change in the Unreleased changelog.

## Verification

- `swift test --filter ShioriPresentation`: passed 4 tests and compiled the
  affected App target.
- `swift test --filter WorkbenchControlMetrics`: passed 3 tests.
- `swift build -c release --product CueSeeker`: passed.
- Existing automation was sufficient; no new end-to-end capability was needed.
- `git diff --check`: run before commit.

## Outcome

- Library Overview `Add Content` and Shiori List Overview `New List` now use
  the accepted Primary Button treatment with unchanged behavior.
