# Shiori Tag Column Display

## Human-Owned Source

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Scope

Render the Shiori `Tags` table column using the tag data prepared by the row
model step. Popover editing is intentionally left for the next step.

## Classification

- Product semantics: unchanged.
- Platform UI/UX: adds the fixed-width Shiori Tags column and table-cell chip
  rendering.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Changes

- Added the `tags` Shiori column to the schema workbench column list.
- Added `tagsHeader` and `showsTagsColumn` through the native table wrapper and
  coordinator.
- Added a `180pt` Tags column to the AppKit table layout.
- Rendered Shiori tags with the existing chip drawing path and no remove
  button in table cells.
- Kept right-click row action menus disabled for Tags cells while preserving
  hover/pointer feedback over tag content.
- Added Tags text support when copying visible table columns.

## Verification

- `swift test --filter SchemaWorkbenchFilterRulesTests`
  - Passed. Verified the Shiori column visibility menu includes Tags in the
    documented order.
- `swift test --filter SubtitleTableClipboardTests`
  - Passed. Verified visible Tags columns copy as comma-separated tag text.
- `swift test --filter SubtitleTableVirtualRowTests`
  - Passed. Verified table text mapping, fixed Tags column width, Tags hover
    cursor region, and no right-click menu for Tags cells.

## Outcome

The Shiori table can now display non-removable neutral tag chips in a fixed
`Tags` column. The next step can attach the documented left-click Tag Popover to
the prepared Tags cell hover region.
