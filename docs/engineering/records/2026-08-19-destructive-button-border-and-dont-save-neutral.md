# Destructive Button Border And Don't Save Neutral

## Requirement

- `docs/human/requirements/20260819-UI-Destructive Button Border And Dont Save Neutral.md`
- `docs/human/design/UI Design System.md`

## Classification

- macOS platform UI/UX only.
- Product semantics, persistence, platform integration, and playback execution
  are unchanged.

## Implementation

- Mapped the Destructive Button border to the Neutral Button border tokens for
  default, Hover, Focused, and Disabled states.
- Changed `Don't Save` in the existing Save Changes confirmation from
  Destructive to Neutral without changing its order or action.
- Added no token, abstraction, state source, dependency, or new execution path.

## Verification

- `swift test --filter ShioriListEditor`: passed 2 tests and compiled the
  affected App target.
- `swift test --filter WorkbenchControlMetrics`: passed 3 tests.
- Existing automation was sufficient; no new end-to-end capability was needed.
- `git diff --check`: run before commit.

## Outcome

- Destructive Button borders now follow the accepted Neutral border treatment
  while retaining their existing Danger label and Hover background.
- `Don't Save` now uses the Neutral Button appearance with unchanged behavior.
