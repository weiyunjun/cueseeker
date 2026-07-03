# Search Shiori Compact Toolbar Controls

## Human-Owned Source

- `docs/human/requirements/20260703-Feature-Search Shiori Compact Toolbar Controls.md`
- `docs/human/design/UI.md`

## Scope

Apply the accepted compact control sizing to the Search and Shiori workbench
toolbars without changing table data, filtering behavior, export behavior, or
row actions.

## Classification

- Product semantics: unchanged.
- Platform UI/UX: Search/Shiori toolbar controls, related icons, clear buttons,
  select triggers, neutral buttons, inline add buttons, and utility bars use the
  compact control tokens.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Changes

- Updated redesign control height, search height, table utility bar height,
  icon button size, control icon size, inline clear button size, and inline
  clear icon size to match the compact toolbar requirement.
- Split the previous shared horizontal padding into control padding and field
  padding so 32px toolbar controls can tighten while 40px fields keep their
  existing horizontal rhythm.
- Applied the control font size and weight token to Search/Shiori toolbar
  buttons, neutral buttons, inline add buttons, and the active filter trigger.
- Updated the select-trigger chevrons indicator to use the default icon color
  when enabled and the disabled icon color when disabled.
- Updated the select-trigger chevrons indicator to use the dedicated 11pt
  semibold token and the documented 8px gap from the trigger text.
- Updated neutral button symbols to use the dedicated 13px medium token instead
  of the general 16px control icon token.
- Kept inline add disabled icon color aligned with the accepted human design
  document.

## Verification

- `git diff --check` passed.
- `swift build` passed from `apps/macos-native`.
- `swift test` passed from `apps/macos-native`. XCTest reported 7 passing CASS
  rendering tests, and Swift Testing reported 369 passing tests.

## Outcome

Search and Shiori toolbar controls now follow the accepted compact 32px control
system while ordinary 40px fields remain visually stable. Select trigger
indicators are more legible, and bulk action button symbols are visually
lighter than the general control icons.
