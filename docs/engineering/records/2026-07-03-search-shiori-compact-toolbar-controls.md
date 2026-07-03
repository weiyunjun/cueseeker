# Search Shiori Compact Toolbar Controls

## Human-Owned Source

- `docs/human/requirements/20260703-Feature-Search Shiori Compact Toolbar Controls.md`
- `docs/human/design/UI.md`

## Scope

Apply the accepted Search and Shiori toolbar control sizing to the workbench
toolbars without changing table data, filtering behavior, export behavior, or
row actions.

## Classification

- Product semantics: unchanged.
- Platform UI/UX: Search/Shiori toolbar controls, related icons, clear buttons,
  select triggers, neutral buttons, inline add buttons, and utility bars use the
  accepted 40px control tokens while icon-only buttons stay out of scope.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Changes

- Restored redesign control height, search height, and table utility bar height
  from 32px to the accepted 40px toolbar scale.
- Kept the separate control and field padding tokens while increasing control
  horizontal padding to the accepted 14px value.
- Applied the control font size and weight token to Search/Shiori toolbar
  buttons, neutral buttons, inline add buttons, and the active filter trigger.
- Updated select-trigger leading icons and chevrons indicators to use the primary
  text token when enabled and the disabled icon token when disabled.
- Updated the select-trigger chevrons indicator to use the dedicated 12pt
  semibold token and the documented 8px gap from the trigger text.
- Updated neutral button symbols to use the dedicated 14px medium token instead
  of the general 16px control icon token.
- Updated neutral button default symbol color to use the primary text token
  while keeping the disabled symbol color on the disabled icon token.
- Updated inline add button default symbol color to use the primary text token
  while keeping the disabled symbol color aligned with the accepted human design
  document.

## Verification

- `git diff --check` passed.
- `swift build` passed from `apps/macos-native`.
- `swift test` passed from `apps/macos-native`. XCTest reported 7 passing CASS
  rendering tests, and Swift Testing reported 369 passing tests.

## Outcome

Search and Shiori toolbar controls now follow the accepted 40px control system.
Select trigger indicators are larger and use primary text contrast, inline add
icons match the same enabled contrast, and icon-only buttons remain unchanged.
