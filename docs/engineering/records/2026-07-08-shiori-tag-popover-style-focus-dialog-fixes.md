# Shiori Tag Popover Style, Focus, and Dialog Fixes

Date: 2026-07-08

Human-owned coverage:

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Implementation

- Moved Delete Tag confirmation ownership from the tag popover content into the Shiori table overlay layer so it uses the shared centered confirmation dialog pattern.
- Kept tag popover state scoped to the active Shiori row and added a row-level regression test for Shiori tag patching.
- Reworked the popover content so the current tag area is transparent, has a `Current Tags` hint, and no separator line.
- Swapped the inline composer to an AppKit-backed text field so opening the popover and completing tag operations can reliably restore text focus.
- Aligned popover tag chip fill, text color, radius, padding, and font with the Shiori Tags table cell style, with the popover-only `x` button as the expected difference.

## Verification

- `swift test --filter TableSandboxRowModelStoreTests`
- `swift test --filter SubtitleTableVirtualRowTests`
- `swift test --filter SchemaWorkbenchFilterRulesTests`
- `swift build`
- `git diff --check`

Outcome: Passed. The row-level regression test confirms updating tags for one Shiori row leaves other visible rows unchanged.
